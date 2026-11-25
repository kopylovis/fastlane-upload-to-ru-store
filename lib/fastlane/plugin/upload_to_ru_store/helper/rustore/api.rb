require 'date'
require 'faraday/multipart'
require_relative 'client'
require_relative 'signer'
require_relative 'errors'
require_relative 'publication'
require_relative 'draft_fields'

module Fastlane
  module Helper
    module Rustore
      class Api
        PAGE_SIZE = 100
        APPS_PAGE_SIZE = 1000
        TOKEN_TTL = 900
        MAX_PAGES = 50

        PUBLISH_TYPES = Publication::PUBLISH_TYPES
        PARTIAL_VALUES = Publication::PARTIAL_VALUES
        AGE_LEGAL = DraftFields::AGE_LEGAL
        APP_TYPES = DraftFields::APP_TYPES
        TESTING_TYPES = %w[ALL RELEASE ALPHA].freeze
        BUILD_TYPES = %w[apk aab].freeze

        STATUS_DRAFT = 'DRAFT'.freeze
        STATUS_ACTIVE = 'ACTIVE'.freeze
        STATUS_PARTIAL_ACTIVE = 'PARTIAL_ACTIVE'.freeze
        STATUS_READY_FOR_PUBLICATION = 'READY_FOR_PUBLICATION'.freeze
        STATUS_REJECTED_BY_MODERATOR = 'REJECTED_BY_MODERATOR'.freeze
        ARCHIVABLE_STATUSES = [STATUS_READY_FOR_PUBLICATION, STATUS_REJECTED_BY_MODERATOR].freeze

        LIMITS = {
          app_name: 50,
          short_description: 80,
          full_description: 4000,
          whats_new: 5000,
          moder_info: 180
        }.freeze

        SERVICES_UNKNOWN = 'Unknown'.freeze
        SERVICES_HMS = 'HMS'.freeze
        SERVICES_TYPES = [SERVICES_UNKNOWN, SERVICES_HMS].freeze
        VERSION_CODE_TAKEN = ['must be larger', 'должен быть выше', 'different version code'].freeze

        MIME_TYPES = {
          'aab' => 'application/octet-stream',
          'apk' => 'application/vnd.android.package-archive'
        }.freeze

        def initialize(client: Client.new)
          @client = client
        end

        attr_reader :client

        def authenticate(signer)
          timestamp = DateTime.now.iso8601(3)
          response = client.post(
            '/public/auth/',
            body: { keyId: signer.key_id, timestamp: timestamp, signature: signer.sign(timestamp) },
            context: 'аутентификация'
          )
          explain_clock_skew!(response)
          response.ensure_success!

          payload = response.payload.is_a?(Hash) ? response.payload : {}
          token = payload['jwe']
          raise ApiError.new('RuStore не вернул токен', context: 'аутентификация') if token.to_s.empty?

          client.assign_token(token, ttl: payload['ttl'] || TOKEN_TTL)
          client.authenticator = -> { authenticate(signer) }
          token
        end

        # The application list pages with a continuation token, not page/size.
        def applications(app_name: nil, app_package: nil, page_size: nil, continuation_token: nil)
          params = { appName: app_name, appPackage: app_package }
          if page_size || continuation_token
            params.merge!(pagination: true, pageSize: page_size || APPS_PAGE_SIZE, continuationToken: continuation_token)
          end
          client.get('/public/v1/application', params: params, context: 'список приложений').ensure_success!.payload
        end

        def each_application(app_name: nil, app_package: nil, &block)
          return to_enum(:each_application, app_name: app_name, app_package: app_package) unless block_given?

          token = nil
          MAX_PAGES.times do
            payload = applications(app_name: app_name, app_package: app_package, page_size: APPS_PAGE_SIZE, continuation_token: token)
            payload = {} unless payload.is_a?(Hash)
            payload['content'].to_a.each(&block)
            token = payload['continuationToken']
            break if token.to_s.empty?
          end
        end

        # RuStore answers either a page (page and size) or the versions listed in
        # ids, never both. Without filterTestingType it returns RELEASE only.
        def versions(package_name, testing_type: 'ALL', statuses: nil, page: 0, size: PAGE_SIZE, ids: nil)
          params = { filterTestingType: testing_type, versionStatuses: Array(statuses).join(',').then { |v| v unless v.empty? } }
          params.merge!(ids ? { ids: Array(ids).join(',') } : { page: page, size: size })
          client.get(
            "/public/v1/application/#{package_name}/version",
            params: params,
            context: 'получение списка версий'
          ).ensure_success!.payload
        end

        def each_version(package_name, testing_type: 'ALL', statuses: nil, &block)
          return to_enum(:each_version, package_name, testing_type: testing_type, statuses: statuses) unless block_given?

          (0...MAX_PAGES).each do |page|
            payload = versions(package_name, testing_type: testing_type, statuses: statuses, page: page)
            payload = {} unless payload.is_a?(Hash)
            content = payload['content'].to_a
            content.each(&block)
            break if last_page?(payload, page, content.size)
          end
        end

        def last_page?(payload, page, count)
          return true if count < PAGE_SIZE

          total = payload['totalPages']
          !total.nil? && page + 1 >= total.to_i
        end

        # The status filter runs on the server, and once more here in case an
        # older API ignores versionStatuses.
        def versions_with_status(package_name, status, testing_type: 'ALL')
          each_version(package_name, testing_type: testing_type, statuses: [status]).select { |v| v['versionStatus'] == status }
        end

        def latest_version(package_name, testing_type: 'ALL')
          each_version(package_name, testing_type: testing_type).max_by { |v| v['versionCode'].to_i }
        end

        # Detailed record of one version from the v2 API: everything the list
        # returns plus statusComment (the moderator's reason), packages and files.
        def version_detail(package_name, version_id)
          client.get(
            "/public/v2/application/#{package_name}/version/#{version_id}",
            context: 'получение версии'
          ).ensure_success!.payload
        end

        # submit_now tells that the draft goes to moderation right away, so the
        # 24 hours to 60 days window of a DELAYED date can be checked up front.
        def create_draft(package_name, submit_now: false, **attributes)
          payload = build_draft_payload(attributes)
          Publication.check_window!(payload[:publishDateTime]) if submit_now && payload[:publishDateTime]
          response = client.post(
            "/public/v1/application/#{package_name}/version",
            body: payload,
            context: 'создание черновика'
          ).ensure_success!

          extract_version_id(response)
        end

        # Changes fields of a draft that has not been sent to moderation yet,
        # through the v2 PATCH. The rules match those of create_draft.
        def edit_draft(package_name, version_id, **attributes)
          payload = build_draft_payload(attributes)
          raise ConfigurationError, 'не передано ни одного поля черновика' if payload.empty?

          client.patch(
            "/public/v2/application/#{package_name}/version/#{version_id}",
            body: payload,
            context: 'редактирование черновика'
          ).ensure_success!
          version_id
        end

        def delete_draft(package_name, version_id)
          client.delete("/public/v1/application/#{package_name}/version/#{version_id}", context: 'удаление черновика')
        end

        # servicesType takes only HMS and Unknown. The main APK for all devices is
        # Unknown, and an HMS APK can never be the main one.
        def upload_build(package_name, version_id, file_path:, build_type:, service_type: nil, main_apk: nil)
          validate_build!(file_path, build_type)
          context = "загрузка #{build_type}"

          response = client.post_file(
            "/public/v1/application/#{package_name}/version/#{version_id}/#{build_type}",
            file_path: file_path,
            content_type: MIME_TYPES.fetch(build_type),
            params: build_type == 'apk' ? apk_params(service_type, main_apk) : {},
            context: context
          )

          if VERSION_CODE_TAKEN.any? { |text| response.message.to_s.include?(text) }
            raise ApiError.new("versionCode этой сборки не больше уже загруженного: #{response.message}", context: context)
          end

          response.ensure_success!
        end

        def commit(package_name, version_id, priority_update: nil)
          client.post(
            "/public/v1/application/#{package_name}/version/#{version_id}/commit",
            params: { priorityUpdate: Publication.priority!(priority_update) },
            context: 'отправка черновика на модерацию'
          ).ensure_success!
        end

        def publish(package_name, version_id)
          client.post(
            "/public/v1/application/#{package_name}/version/#{version_id}/publish",
            context: 'ручная публикация'
          ).ensure_success!
        end

        def archive(package_name, version_id)
          client.post(
            "/public/v1/application/#{package_name}/version/#{version_id}/archive",
            context: 'архивирование версии'
          ).ensure_success!
        end

        def update_publish_settings(package_name, version_id, publish_type: nil, publish_datetime: nil, partial_value: nil)
          payload = Publication.settings_payload(
            publish_type: publish_type, publish_datetime: publish_datetime, partial_value: partial_value
          )

          client.post(
            "/public/v1/application/#{package_name}/version/#{version_id}/publish-settings",
            body: payload,
            context: 'изменение настроек публикации'
          ).ensure_success!
        end

        private

        def explain_clock_skew!(response)
          return if response.success? || !response.message.to_s.match?(/timestamp/i)

          raise ApiError.new(
            "#{response.message}. RuStore принимает подпись, только если часы машины расходятся с его часами " \
            'меньше чем на 60 секунд. Проверьте время на раннере',
            status: response.status, code: response.code, context: 'аутентификация'
          )
        end

        def build_draft_payload(attributes)
          publication_payload(attributes).merge(DraftFields.payload(attributes))
        end

        def publication_payload(attributes)
          Publication.draft_payload(
            publish_type: attributes[:publish_type],
            publish_datetime: attributes[:publish_datetime],
            partial_value: attributes[:partial_value]
          )
        end

        def extract_version_id(response)
          payload = response.payload
          return payload.to_i if payload.is_a?(Numeric) || payload.to_s.match?(/\A\d+\z/)

          found = response.message.to_s[/\d+/]
          return found.to_i if found

          raise ApiError.new("не удалось получить versionId: #{response.preview}", context: 'создание черновика')
        end

        def apk_params(service_type, main_apk)
          services = service_type || SERVICES_UNKNOWN
          validate_inclusion!(services, SERVICES_TYPES, 'service_type')
          is_main = main_apk.nil? ? services == SERVICES_UNKNOWN : main_apk
          raise ConfigurationError, 'HMS APK не может быть основным' if is_main && services == SERVICES_HMS

          { servicesType: services, isMainApk: is_main }
        end

        def validate_build!(file_path, build_type)
          unless BUILD_TYPES.include?(build_type)
            raise ConfigurationError, "неизвестный тип сборки: #{build_type}. Допустимы: #{BUILD_TYPES.join(', ')}"
          end
          raise ConfigurationError, "файл сборки не найден: #{file_path}" unless File.file?(file_path)
        end

        def validate_inclusion!(value, allowed, name)
          raise ConfigurationError, "неизвестный #{name}: #{value}. Допустимы: #{allowed.join(', ')}" unless allowed.include?(value)

          value
        end
      end
    end
  end
end

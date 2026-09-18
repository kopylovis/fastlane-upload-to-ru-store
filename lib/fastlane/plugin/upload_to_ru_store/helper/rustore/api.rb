require 'date'
require 'faraday/multipart'
require_relative 'client'
require_relative 'signer'
require_relative 'errors'

module Fastlane
  module Helper
    module Rustore
      class Api
        PAGE_SIZE = 100
        MAX_PAGES = 50

        PUBLISH_TYPES = %w[MANUAL INSTANTLY DELAYED].freeze
        PARTIAL_VALUES = [5, 10, 25, 50, 75, 100].freeze
        AGE_LEGAL = %w[0+ 6+ 12+ 16+ 18+].freeze
        APP_TYPES = %w[MAIN GAMES].freeze
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

        DRAFT_FIELDS = {
          app_name: { key: :appName, limit: :app_name },
          app_type: { key: :appType, allowed: APP_TYPES },
          age_legal: { key: :ageLegal, allowed: AGE_LEGAL },
          short_description: { key: :shortDescription, limit: :short_description },
          full_description: { key: :fullDescription, limit: :full_description },
          whats_new: { key: :whatsNew, limit: :whats_new },
          moder_info: { key: :moderInfo, limit: :moder_info },
          price_value: { key: :priceValue }
        }.freeze

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
          ).ensure_success!

          token = response.payload.is_a?(Hash) ? response.payload['jwe'] : nil
          raise ApiError.new('RuStore не вернул токен', context: 'аутентификация') if token.to_s.empty?

          client.token = token
        end

        def applications(page: 0, size: PAGE_SIZE)
          client.get('/public/v1/application', params: { page: page, size: size }, context: 'список приложений')
                .ensure_success!.payload
        end

        def versions(package_name, testing_type: 'ALL', page: 0, size: PAGE_SIZE, ids: nil)
          client.get(
            "/public/v1/application/#{package_name}/version",
            params: { filterTestingType: testing_type, page: page, size: size, ids: ids },
            context: 'получение списка версий'
          ).ensure_success!.payload
        end

        def each_version(package_name, testing_type: 'ALL', &block)
          return to_enum(:each_version, package_name, testing_type: testing_type) unless block_given?

          (0...MAX_PAGES).each do |page|
            payload = versions(package_name, testing_type: testing_type, page: page)
            content = payload.is_a?(Hash) ? payload['content'].to_a : []
            content.each(&block)
            break if content.size < PAGE_SIZE
          end
        end

        def versions_with_status(package_name, status, testing_type: 'ALL')
          each_version(package_name, testing_type: testing_type).select { |v| v['versionStatus'] == status }
        end

        def latest_version(package_name, testing_type: 'ALL')
          each_version(package_name, testing_type: testing_type).max_by { |v| v['versionCode'].to_i }
        end

        def create_draft(package_name, attributes = {})
          payload = build_draft_payload(attributes)
          response = client.post(
            "/public/v1/application/#{package_name}/version",
            body: payload,
            context: 'создание черновика'
          ).ensure_success!

          extract_version_id(response)
        end

        def delete_draft(package_name, version_id)
          client.delete("/public/v1/application/#{package_name}/version/#{version_id}", context: 'удаление черновика')
        end

        def upload_build(package_name, version_id, file_path:, build_type:, service_type: nil, main_apk: nil)
          validate_build!(file_path, build_type)

          part = Faraday::Multipart::FilePart.new(file_path, MIME_TYPES.fetch(build_type))
          is_main = main_apk.nil? ? (service_type == 'GMS') : main_apk

          response = client.post_file(
            "/public/v1/application/#{package_name}/version/#{version_id}/#{build_type}",
            file_part: part,
            params: { servicesType: service_type, isMainApk: (is_main if service_type) },
            context: "загрузка #{build_type}"
          )

          if response.message.to_s.include?('must be larger')
            raise ApiError.new('сборка с таким versionCode уже была загружена ранее', context: "загрузка #{build_type}")
          end

          response.ensure_success!
        end

        def commit(package_name, version_id, priority_update: nil)
          client.post(
            "/public/v1/application/#{package_name}/version/#{version_id}/commit",
            params: { priorityUpdate: priority_update },
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
          payload = {}
          payload[:publishType] = validate_publish_type!(publish_type) if publish_type
          payload[:publishDateTime] = publish_datetime if publish_datetime
          payload[:partialValue] = validate_partial_value!(partial_value) if partial_value
          raise ConfigurationError, 'не переданы настройки публикации' if payload.empty?

          client.post(
            "/public/v1/application/#{package_name}/version/#{version_id}/publish-settings",
            body: payload,
            context: 'изменение настроек публикации'
          ).ensure_success!
        end

        private

        def build_draft_payload(attributes)
          payload = publication_payload(attributes)

          DRAFT_FIELDS.each do |name, spec|
            value = attributes[name]
            next if value.nil?

            payload[spec[:key]] = cast_field(value, spec, name)
          end

          payload
        end

        def publication_payload(attributes)
          payload = {}
          publish_type = attributes[:publish_type]
          payload[:publishType] = validate_publish_type!(publish_type) if publish_type

          if publish_type == 'DELAYED'
            datetime = attributes[:publish_datetime]
            raise ConfigurationError, 'для publish_type = DELAYED обязателен publish_datetime' if datetime.to_s.empty?

            payload[:publishDateTime] = datetime
          end

          payload[:partialValue] = validate_partial_value!(attributes[:partial_value]) if attributes[:partial_value]
          payload
        end

        def cast_field(value, spec, name)
          return validate_inclusion!(value, spec[:allowed], name.to_s) if spec[:allowed]
          return truncate!(value, spec[:limit]) if spec[:limit]

          value
        end

        def extract_version_id(response)
          payload = response.payload
          return payload.to_i if payload.is_a?(Numeric) || payload.to_s.match?(/\A\d+\z/)

          found = response.message.to_s[/\d+/]
          return found.to_i if found

          raise ApiError.new("не удалось получить versionId: #{response.preview}", context: 'создание черновика')
        end

        def validate_build!(file_path, build_type)
          unless BUILD_TYPES.include?(build_type)
            raise ConfigurationError, "неизвестный тип сборки: #{build_type}. Допустимы: #{BUILD_TYPES.join(', ')}"
          end
          raise ConfigurationError, "файл сборки не найден: #{file_path}" unless File.file?(file_path)
        end

        def validate_publish_type!(value)
          validate_inclusion!(value, PUBLISH_TYPES, 'publish_type')
        end

        def validate_partial_value!(value)
          number = value.to_i
          unless PARTIAL_VALUES.include?(number)
            raise ConfigurationError, "partial_value должен быть одним из #{PARTIAL_VALUES.join(', ')}, получено #{value}"
          end

          number
        end

        def validate_inclusion!(value, allowed, name)
          raise ConfigurationError, "неизвестный #{name}: #{value}. Допустимы: #{allowed.join(', ')}" unless allowed.include?(value)

          value
        end

        def truncate!(value, limit_key)
          limit = LIMITS.fetch(limit_key)
          text = value.to_s
          raise ConfigurationError, "#{limit_key} длиннее #{limit} символов (сейчас #{text.length})" if text.length > limit

          text
        end
      end
    end
  end
end

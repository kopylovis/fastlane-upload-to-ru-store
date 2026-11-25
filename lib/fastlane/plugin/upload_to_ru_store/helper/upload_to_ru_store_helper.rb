require 'fastlane_core/ui/ui'
require 'logger'
require_relative 'rustore/api'
require_relative 'rustore/client'
require_relative 'rustore/errors'
require_relative 'rustore/signer'

module Fastlane
  module Helper
    class UploadToRuStoreHelper
      BASE_URL = Rustore::Client::BASE_URL
      PUBLISH_TYPES = Rustore::Api::PUBLISH_TYPES
      PARTIAL_VALUES = Rustore::Api::PARTIAL_VALUES
      AGE_LEGAL = Rustore::Api::AGE_LEGAL
      APP_TYPES = Rustore::Api::APP_TYPES
      TESTING_TYPES = Rustore::Api::TESTING_TYPES
      BUILD_TYPES = Rustore::Api::BUILD_TYPES
      CHANGELOG_LIMIT = Rustore::Api::LIMITS[:whats_new]

      class << self
        # Authenticates once and returns an Api bound to its own client, so the
        # timeout and base_url of the calling action apply to every request it makes.
        def session(params)
          api = Rustore::Api.new(client: build_client(timeout: params[:timeout], base_url: params[:base_url]))
          wrap { api.authenticate(Rustore::Signer.new(key_id: params[:key_id], private_key: params[:private_key])) }
          api
        end

        def remove_drafts(api:, package_name:)
          wrap do
            drafts = api.versions_with_status(package_name, Rustore::Api::STATUS_DRAFT)
            UI.message("Черновиков к удалению: #{drafts.size}") unless drafts.empty?
            drafts.each do |draft|
              id = draft['versionId']
              response = api.delete_draft(package_name, id)
              if response.success?
                UI.message("Удален черновик ##{id}")
              else
                UI.important("Не удалось удалить черновик ##{id}: #{response.message || response.preview}")
              end
            end
          end
        end

        def create_draft(api:, package_name:, publish_type: nil, publish_datetime: nil, changelog_path: nil, submit_now: false,
                         **attributes)
          wrap do
            if publish_datetime && publish_type != Rustore::Publication::DELAYED
              UI.important('publish_datetime учитывается только с publish_type: DELAYED, сейчас он не будет отправлен')
            end
            payload = attributes.merge(publish_type: publish_type, publish_datetime: publish_datetime)
            if changelog_path
              UI.important('Указаны и changelog_path, и whats_new. Будет использован файл') if attributes[:whats_new]
              payload[:whats_new] = read_changelog(changelog_path)
            end
            api.create_draft(package_name, submit_now: submit_now, **payload)
          end
        end

        def upload_build(api:, draft_id:, file_path:, package_name:, build_type:, service_type: nil)
          wrap do
            api.upload_build(
              package_name, draft_id,
              file_path: file_path, build_type: build_type, service_type: service_type
            )
            UI.success("Загружено: #{File.basename(file_path)}")
          end
        end

        def commit_draft(api:, draft_id:, package_name:, priority_update: nil)
          wrap do
            api.commit(package_name, draft_id, priority_update: priority_update)
            UI.success("Черновик ##{draft_id} отправлен на модерацию")
          end
        end

        def publish_version(api:, package_name:, version_id:)
          wrap do
            api.publish(package_name, version_id)
            UI.success("Версия ##{version_id} опубликована")
          end
        end

        def archive_version(api:, package_name:, version_id:)
          wrap do
            api.archive(package_name, version_id)
            UI.success("Версия ##{version_id} архивирована")
          end
        end

        def update_publish_settings(api:, package_name:, version_id:, **settings)
          wrap do
            api.update_publish_settings(package_name, version_id, **settings)
            UI.success("Настройки публикации версии ##{version_id} обновлены")
          end
        end

        def latest_version(api:, package_name:, testing_type: 'ALL')
          wrap { api.latest_version(package_name, testing_type: testing_type) }
        end

        def read_changelog(path)
          raise Rustore::ConfigurationError, "файл changelog не найден: #{path}" unless File.file?(path)

          # Read as UTF-8 whatever the locale is: with LANG=C, as on many CI images,
          # Ruby would read Cyrillic as US-ASCII and JSON encoding would fail.
          text = File.read(path, encoding: 'bom|utf-8')
          raise Rustore::ConfigurationError, "changelog не в кодировке UTF-8: #{path}" unless text.valid_encoding?

          if text.length > CHANGELOG_LIMIT
            raise Rustore::ConfigurationError,
                  "changelog длиннее #{CHANGELOG_LIMIT} символов (сейчас #{text.length})"
          end
          text
        end

        def debug?
          !ENV['RUSTORE_DEBUG'].to_s.empty? || !ENV['DEBUG'].to_s.empty?
        end

        def build_client(timeout: nil, base_url: nil)
          options = { logger: (Logger.new($stderr, level: Logger::DEBUG) if debug?) }
          options[:timeout] = timeout if timeout
          options[:base_url] = base_url unless base_url.to_s.empty?
          Rustore::Client.new(**options)
        end

        private

        def wrap
          yield
        rescue Rustore::Error => e
          UI.user_error!("RuStore: #{e}")
        end
      end
    end
  end
end

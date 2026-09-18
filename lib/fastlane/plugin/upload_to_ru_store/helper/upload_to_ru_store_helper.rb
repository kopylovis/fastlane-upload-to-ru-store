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
        def api(key_id: nil, private_key: nil, token: nil, timeout: nil)
          instance = Rustore::Api.new(client: build_client(timeout))
          if token
            instance.client.token = token
          elsif key_id && private_key
            wrap { instance.authenticate(Rustore::Signer.new(key_id: key_id, private_key: private_key)) }
          end
          instance
        end

        def fetch_token(key_id:, private_key:)
          wrap do
            signer = Rustore::Signer.new(key_id: key_id, private_key: private_key)
            Rustore::Api.new(client: shared_client).authenticate(signer)
          end
        end

        def remove_drafts(token:, package_name:)
          instance = with_token(token)
          wrap do
            drafts = instance.versions_with_status(package_name, Rustore::Api::STATUS_DRAFT)
            UI.message("Черновиков к удалению: #{drafts.size}") unless drafts.empty?
            drafts.each do |draft|
              id = draft['versionId']
              response = instance.delete_draft(package_name, id)
              if response.success? || response.status == 204
                UI.message("Удалён черновик ##{id}")
              else
                UI.important("Не удалось удалить черновик ##{id}: #{response.message || response.preview}")
              end
            end
          end
        end

        def create_draft(token:, package_name:, publish_type: nil, publish_datetime: nil, changelog_path: nil, **attributes)
          instance = with_token(token)
          wrap do
            payload = attributes.merge(publish_type: publish_type, publish_datetime: publish_datetime)
            payload[:whats_new] = read_changelog(changelog_path) if changelog_path
            instance.create_draft(package_name, payload)
          end
        end

        def upload_build(token:, draft_id:, file_path:, package_name:, build_type:, service_type: nil)
          instance = with_token(token)
          wrap do
            instance.upload_build(
              package_name, draft_id,
              file_path: file_path, build_type: build_type, service_type: service_type
            )
            UI.success("Загружено: #{File.basename(file_path)}")
          end
        end

        def commit_draft(token:, draft_id:, package_name:, priority_update: nil)
          instance = with_token(token)
          wrap do
            instance.commit(package_name, draft_id, priority_update: priority_update)
            UI.success("Черновик ##{draft_id} отправлен на модерацию")
          end
        end

        def publish_version(token:, package_name:, version_id:)
          instance = with_token(token)
          wrap do
            instance.publish(package_name, version_id)
            UI.success("Версия ##{version_id} опубликована")
          end
        end

        def archive_version(token:, package_name:, version_id:)
          instance = with_token(token)
          wrap do
            instance.archive(package_name, version_id)
            UI.success("Версия ##{version_id} архивирована")
          end
        end

        def update_publish_settings(token:, package_name:, version_id:, **settings)
          instance = with_token(token)
          wrap do
            instance.update_publish_settings(package_name, version_id, **settings)
            UI.success("Настройки публикации версии ##{version_id} обновлены")
          end
        end

        def latest_version(token:, package_name:, testing_type: 'ALL')
          instance = with_token(token)
          wrap { instance.latest_version(package_name, testing_type: testing_type) }
        end

        def read_changelog(path)
          raise Rustore::ConfigurationError, "файл changelog не найден: #{path}" unless File.file?(path)

          text = File.read(path)
          if text.length > CHANGELOG_LIMIT
            raise Rustore::ConfigurationError,
                  "changelog длиннее #{CHANGELOG_LIMIT} символов (сейчас #{text.length})"
          end
          text
        end

        def reset!
          @shared_client = nil
        end

        def debug?
          !ENV['RUSTORE_DEBUG'].to_s.empty? || !ENV['DEBUG'].to_s.empty?
        end

        private

        def with_token(token)
          shared_client.token = token
          Rustore::Api.new(client: shared_client)
        end

        def shared_client
          @shared_client ||= build_client(nil)
        end

        def build_client(timeout)
          options = { logger: (Logger.new($stderr, level: Logger::DEBUG) if debug?) }
          options[:timeout] = timeout if timeout
          Rustore::Client.new(**options)
        end

        def wrap
          yield
        rescue Rustore::Error => e
          UI.user_error!("RuStore: #{e}")
        end
      end
    end
  end
end

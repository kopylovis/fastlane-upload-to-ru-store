require 'fastlane_core/configuration/config_item'
require_relative 'api'
require_relative 'client'
require_relative 'publication'

module Fastlane
  module Helper
    module Rustore
      module Options
        module_function

        def package_name
          FastlaneCore::ConfigItem.new(
            key: :package_name,
            env_name: 'RUSTORE_PACKAGE_NAME',
            description: 'Application package, e.g. com.example.app',
            optional: false,
            type: String
          )
        end

        def key_id
          FastlaneCore::ConfigItem.new(
            key: :key_id,
            env_name: 'RUSTORE_KEY_ID',
            description: 'RuStore API key ID',
            optional: false,
            sensitive: true,
            type: String
          )
        end

        def private_key
          FastlaneCore::ConfigItem.new(
            key: :private_key,
            env_name: 'RUSTORE_PRIVATE_KEY',
            description: 'RuStore RSA private key: PEM or bare Base64, PKCS#1 or PKCS#8',
            optional: false,
            sensitive: true,
            type: String
          )
        end

        def version_id(optional: false)
          FastlaneCore::ConfigItem.new(
            key: :version_id,
            env_name: 'RUSTORE_VERSION_ID',
            description: 'Version identifier. Defaults to the latest version when omitted',
            optional: optional,
            type: Integer
          )
        end

        def publish_type(optional: true)
          FastlaneCore::ConfigItem.new(
            key: :publish_type,
            env_name: 'RUSTORE_PUBLISH_TYPE',
            description: "Publication type: #{Api::PUBLISH_TYPES.join('/')}",
            optional: optional,
            type: String,
            verify_block: proc do |value|
              unless Api::PUBLISH_TYPES.include?(value)
                UI.user_error!("Неизвестный publish_type: #{value}. Допустимы: #{Api::PUBLISH_TYPES.join(', ')}")
              end
            end
          )
        end

        def publish_datetime
          FastlaneCore::ConfigItem.new(
            key: :publish_datetime,
            env_name: 'RUSTORE_PUBLISH_DATETIME',
            description: "ISO8601 moment for DELAYED publishing, from 24 hours to 60 days ahead",
            optional: true,
            type: String,
            verify_block: proc do |value|
              Publication.parse_datetime!(value)
            rescue ConfigurationError => e
              UI.user_error!("Неверный формат publish_datetime (ISO8601): #{e.message}")
            end
          )
        end

        def partial_value
          FastlaneCore::ConfigItem.new(
            key: :partial_value,
            env_name: 'RUSTORE_PARTIAL_VALUE',
            description: "Staged rollout percentage: #{Api::PARTIAL_VALUES.join('/')}",
            optional: true,
            type: Integer,
            verify_block: proc do |value|
              unless Api::PARTIAL_VALUES.include?(value.to_i)
                UI.user_error!("partial_value должен быть одним из #{Api::PARTIAL_VALUES.join(', ')}")
              end
            end
          )
        end

        def priority_update
          FastlaneCore::ConfigItem.new(
            key: :priority_update,
            env_name: 'RUSTORE_PRIORITY_UPDATE',
            description: 'Update priority sent with the moderation request, 0 to 5',
            optional: true,
            type: Integer,
            verify_block: proc do |value|
              Publication.priority!(value)
            rescue ConfigurationError => e
              UI.user_error!(e.message)
            end
          )
        end

        def testing_type
          FastlaneCore::ConfigItem.new(
            key: :testing_type,
            env_name: 'RUSTORE_TESTING_TYPE',
            description: "Which track to query: #{Api::TESTING_TYPES.join('/')}",
            optional: true,
            default_value: 'ALL',
            type: String,
            verify_block: proc do |value|
              unless Api::TESTING_TYPES.include?(value)
                UI.user_error!("Неизвестный testing_type: #{value}. Допустимы: #{Api::TESTING_TYPES.join(', ')}")
              end
            end
          )
        end

        def timeout
          FastlaneCore::ConfigItem.new(
            key: :timeout,
            env_name: 'RUSTORE_TIMEOUT',
            description: 'Read timeout for RuStore requests, seconds',
            optional: true,
            default_value: Client::READ_TIMEOUT,
            type: Integer
          )
        end

        def base_url
          FastlaneCore::ConfigItem.new(
            key: :base_url,
            env_name: 'RUSTORE_BASE_URL',
            description: "RuStore API host. The docs now name https://public-api-m.rustore.ru; #{Client::BASE_URL} still answers",
            optional: true,
            default_value: Client::BASE_URL,
            type: String,
            verify_block: proc do |value|
              UI.user_error!("base_url должен начинаться с https://, получено #{value}") unless value.start_with?('https://')
            end
          )
        end

        def connection
          [timeout, base_url]
        end

        def existing_file(key, env_name, description)
          FastlaneCore::ConfigItem.new(
            key: key,
            env_name: env_name,
            description: description,
            optional: true,
            type: String,
            verify_block: proc do |value|
              UI.user_error!("Файл не найден (#{key}): #{value}") unless File.file?(value)
            end
          )
        end

        def auth
          [package_name, key_id, private_key]
        end
      end
    end
  end
end

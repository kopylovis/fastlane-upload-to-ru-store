require 'fastlane_core/ui/ui'
require 'faraday'
require 'faraday_middleware'
require 'openssl'
require 'base64'
require 'date'
require 'json'

module Fastlane
  UI = FastlaneCore::UI

  module Helper
    # Helper for Fastlane plugin "upload_to_ru_store"
    # Encapsulates authentication, draft management, upload and commit operations
    class UploadToRuStoreHelper
      BASE_URL = 'https://public-api.rustore.ru'.freeze
      DEFAULT_PAGE_SIZE = 100

      class << self
        # Obtain JWE token using RSA-SHA512 signature
        # @param key_id [String] API key identifier
        # @param private_key [String] PEM-formatted RSA private key
        # @return [String] JWE token
        def fetch_token(key_id:, private_key:)
          timestamp = DateTime.now.iso8601(3)
          signature = rsa_sign(
            key_id: key_id,
            timestamp: timestamp,
            private_key: private_key
          )
          response = client.post('/public/auth/') do |req|
            req.body = { keyId: key_id, timestamp: timestamp, signature: signature }
          end
          debug(response)
          data = response.body
          jwe = data.dig('body', 'jwe')
          UI.user_error!('Не удалось получить токен из RuStore') unless jwe
          jwe
        end

        # Remove all existing drafts for package
        # @param token [String]
        # @param package_name [String]
        def remove_drafts(token:, package_name:)
          draft_ids(token: token, package_name: package_name).each do |id|
            delete_draft(token: token, package_name: package_name, draft_id: id)
          end
        end

        # Create new draft version, optionally with changelog and publish type
        # @param token [String]
        # @param package_name [String]
        # @param publish_type [String, nil]
        # @param changelog_path [String, nil]
        # @return [Integer] draft_id
        def create_draft(token:, package_name:, publish_type: nil, publish_datetime: nil, changelog_path: nil)
          payload = {}
          payload[:publishType] = publish_type if publish_type
          if publish_type == 'DELAYED'
            UI.user_error!('Для publish_type = DELAYED обязательно указывать publish_datetime') unless publish_datetime
            payload[:publishDateTime] = publish_datetime
          end
          payload[:whatsNew] = read_changelog(changelog_path) if changelog_path

          response = client.post("/public/v1/application/#{package_name}/version") do |req|
            req.headers['Public-Token'] = token
            req.body = payload
          end
          debug(response)
          extract_draft_id(response)
        end

        # Upload application build (APK or AAB)
        # @param token [String]
        # @param draft_id [Integer]
        # @param file_path [String]
        # @param package_name [String]
        # @param build_type ['apk','aab']
        # @param service_type ['GMS','HMS',nil]
        def upload_build(token:, draft_id:, file_path:, package_name:, build_type:, service_type: nil)
          endpoint = "/public/v1/application/#{package_name}/version/#{draft_id}/#{build_type}"
          part = Faraday::Multipart::FilePart.new(file_path, mime_type(build_type))

          response = client.post(endpoint) do |req|
            req.headers['Public-Token'] = token
            req.params['servicesType'] = service_type if service_type
            req.params['isMainApk'] = true if service_type == 'GMS'
            req.body = { file: part }
          end
          debug(response)

          if response.body.dig('message')&.include?('must be larger')
            UI.user_error!('Сборка с таким versionCode уже была загружена ранее')
          end
        end

        # Commit the draft to publish
        # @param token [String]
        # @param draft_id [Integer]
        # @param package_name [String]
        def commit_draft(token:, draft_id:, package_name:)
          response = client.post("/public/v1/application/#{package_name}/version/#{draft_id}/commit") do |req|
            req.headers['Public-Token'] = token
          end
          debug(response)
        end

        private

        # Initialize Faraday client
        def client
          @client ||= Faraday.new(url: BASE_URL) do |f|
            f.request :multipart
            f.request :json
            f.request :url_encoded
            f.response :json, content_type: /\bjson$/
            f.response :logger, Logger.new($stderr, level: Logger::DEBUG)
            f.use FaradayMiddleware::FollowRedirects
            f.adapter :net_http
            f.options.timeout = 600
            f.options.open_timeout = 30
          end
        end

        # Sign payload with RSA-SHA512
        def rsa_sign(key_id:, timestamp:, private_key:)
          raw = private_key.strip
          pem = if raw.include?('-----BEGIN')
                  raw
                else
                  b64 = raw.gsub(/\s+/, '')
                  body = b64.scan(/.{1,64}/).join("\n")
                  <<~PEM
                    -----BEGIN RSA PRIVATE KEY-----
                    #{body}
                    -----END RSA PRIVATE KEY-----
                  PEM
                end

          key = OpenSSL::PKey::RSA.new(pem)
          digest = OpenSSL::Digest::SHA512.new
          signature = key.sign(digest, key_id + timestamp)

          Base64.strict_encode64(signature)
        end

        # List draft IDs
        def draft_ids(token:, package_name:)
          resp = client.get("/public/v1/application/#{package_name}/version") do |req|
            req.headers['Public-Token'] = token
            req.params['filterTestingType'] = 'ALL'
            req.params['page'] = 0
            req.params['size'] = DEFAULT_PAGE_SIZE
          end
          resp.body.dig('body', 'content').to_a
              .select { |v| v['versionStatus'] == 'DRAFT' }
              .map { |v| v['versionId'] }
        end

        # Delete a single draft
        def delete_draft(token:, package_name:, draft_id:)
          resp = client.delete("/public/v1/application/#{package_name}/version/#{draft_id}") do |req|
            req.headers['Public-Token'] = token
          end
          if resp.status == 204
            UI.message("Deleted draft ##{draft_id}")
          else
            UI.important("Failed to delete draft ##{draft_id}: #{resp.body['message']}")
          end
        end

        # Read changelog and validate length
        def read_changelog(path)
          text = File.read(path)
          UI.user_error!('Файл Что нового? более 500 символов') if text.size > 500
          text
        end

        # Parse draft ID from create response
        def extract_draft_id(response)
          body = response.body
          return body['body'] if body['body']
          return body['message'][/\d+/].to_i if body['message']
          UI.user_error!('Не удалось получить draftId из RuStore')
        end

        # Determine MIME type
        def mime_type(type)
          case type
          when 'aab' then 'application/x-authorware-bin'
          when 'apk' then 'application/vnd.android.package-archive'
          else UI.user_error!("Неизвестный тип сборки: #{type}")
          end
        end

        # Log response body when DEBUG
        def debug(response)
          UI.message("Debug: #{response.body}") if ENV['DEBUG']
        end
      end
    end
  end
end
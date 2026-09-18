require 'openssl'
require 'base64'
require_relative 'errors'

module Fastlane
  module Helper
    module Rustore
      class Signer
        DIGEST = 'SHA512'.freeze

        def initialize(key_id:, private_key:)
          raise ConfigurationError, 'key_id пустой' if key_id.to_s.strip.empty?

          @key_id = key_id.to_s.strip
          @key = load_key(private_key)
        end

        attr_reader :key_id

        def sign(timestamp)
          signature = @key.sign(OpenSSL::Digest.new(DIGEST), "#{key_id}#{timestamp}")
          Base64.strict_encode64(signature)
        end

        private

        def load_key(private_key)
          raw = private_key.to_s.strip
          raise ConfigurationError, 'private_key пустой' if raw.empty?

          return build_key(raw, 'PEM') if raw.include?('-----BEGIN')

          build_key(decode_base64(raw), 'DER')
        end

        def decode_base64(raw)
          Base64.strict_decode64(raw.gsub(/\s+/, ''))
        rescue ArgumentError
          raise ConfigurationError, 'private_key не PEM и не корректный Base64'
        end

        def build_key(material, kind)
          OpenSSL::PKey::RSA.new(material)
        rescue OpenSSL::PKey::RSAError => e
          raise ConfigurationError, "Не удалось прочитать private_key (#{kind}): #{e.message}"
        end
      end
    end
  end
end

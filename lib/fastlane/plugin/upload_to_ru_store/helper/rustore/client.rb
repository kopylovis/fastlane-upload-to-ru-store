require 'faraday'
require 'faraday/multipart'
require 'faraday/follow_redirects'
require 'json'
require 'logger'
require 'net/http'
require 'socket'
require_relative 'errors'

module Fastlane
  module Helper
    module Rustore
      class Client
        BASE_URL = 'https://public-api.rustore.ru'.freeze
        READ_TIMEOUT = 600
        OPEN_TIMEOUT = 30
        RETRIABLE_STATUSES = [429, 500, 502, 503, 504].freeze
        IDEMPOTENT_METHODS = %i[get delete].freeze
        MAX_RETRIES = 3
        RETRY_BACKOFF = 2

        # Failures that happen before the request reaches RuStore. Repeating them
        # is safe even for POST, because the server has not seen the request yet.
        NOT_SENT_ERRORS = [Net::OpenTimeout, Errno::ECONNREFUSED, Errno::EHOSTUNREACH,
                           Errno::ENETUNREACH, SocketError].freeze

        def initialize(base_url: BASE_URL, timeout: READ_TIMEOUT, open_timeout: OPEN_TIMEOUT, logger: nil)
          @base_url = base_url
          @timeout = timeout
          @open_timeout = open_timeout
          @logger = logger
          @token = nil
        end

        attr_accessor :token
        attr_reader :base_url, :timeout

        def get(path, params: {}, context: nil)
          request(:get, path, params: params, context: context)
        end

        def post(path, body: nil, params: {}, context: nil)
          request(:post, path, body: body, params: params, context: context)
        end

        def delete(path, params: {}, context: nil)
          request(:delete, path, params: params, context: context)
        end

        # The multipart body is rebuilt for every attempt: a file part that was
        # already sent is read to the end, and resending it would upload nothing.
        def post_file(path, file_path:, content_type:, params: {}, context: nil)
          request(:post, path, params: params, context: context, file: [file_path, content_type])
        end

        private

        def request(method, path, body: nil, params: {}, context: nil, file: nil)
          attempt = 0
          loop do
            attempt += 1
            response = attempt_request(method, path, body, params, file, context, attempt)
            return response if response
          end
        end

        def attempt_request(method, path, body, params, file, context, attempt)
          response = Response.new(perform(method, path, body, params, file), context)
          return response unless retry_status?(method, response.status) && retriable?(attempt)

          sleep_backoff(attempt)
          nil
        rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
          raise ApiError.new("сеть недоступна: #{e.message}", context: context) unless retry_error?(method, e) && retriable?(attempt)

          sleep_backoff(attempt)
          nil
        end

        def perform(method, path, body, params, file)
          part = Faraday::Multipart::FilePart.new(*file) if file
          payload = part ? { file: part } : body
          connection.public_send(method, path) { |req| fill(req, payload, params) }
        ensure
          part&.close
        end

        def fill(req, payload, params)
          req.headers['Public-Token'] = token if token
          params.each { |k, v| req.params[k.to_s] = v unless v.nil? }
          req.body = payload unless payload.nil?
        end

        def retry_status?(method, status)
          return true if status == 429

          IDEMPOTENT_METHODS.include?(method) && RETRIABLE_STATUSES.include?(status)
        end

        def retry_error?(method, error)
          return true if IDEMPOTENT_METHODS.include?(method)

          NOT_SENT_ERRORS.any? { |klass| error.wrapped_exception.is_a?(klass) }
        end

        def retriable?(attempt)
          attempt < MAX_RETRIES
        end

        def sleep_backoff(attempt)
          sleep(RETRY_BACKOFF**attempt)
        end

        def connection
          @connection ||= Faraday.new(url: @base_url) do |f|
            f.request(:multipart)
            f.request(:json)
            f.response(:follow_redirects)
            f.response(:json, content_type: /\bjson/)
            configure_logger(f)
            f.adapter(:net_http)
            f.options.timeout = @timeout
            f.options.open_timeout = @open_timeout
          end
        end

        def configure_logger(faraday)
          return unless @logger

          faraday.response(:logger, @logger, headers: true, bodies: false) do |l|
            l.filter(/(Public-Token:\s*)([^\s]+)/, '\1[FILTERED]')
            l.filter(/("signature"\s*:\s*")([^"]+)/, '\1[FILTERED]')
            l.filter(/("jwe"\s*:\s*")([^"]+)/, '\1[FILTERED]')
          end
        end

        class Response
          def initialize(raw, context)
            @raw = raw
            @context = context
          end

          attr_reader :context

          def status
            @raw.status
          end

          def success?
            status.between?(200, 299)
          end

          def body
            @body ||= parse_body
          end

          def payload
            body['body']
          end

          def message
            body['message']
          end

          def code
            body['code']
          end

          def raw_body
            @raw.body
          end

          def ensure_success!
            return self if success?

            raise ApiError.new(
              message || code || preview,
              status: status, code: code, body: body, context: context
            )
          end

          def preview
            raw_body.to_s[0, 300]
          end

          private

          def parse_body
            value = @raw.body
            return value if value.is_a?(Hash)
            return {} unless value.is_a?(String) && !value.strip.empty?

            parsed = JSON.parse(value)
            parsed.is_a?(Hash) ? parsed : {}
          rescue JSON::ParserError
            {}
          end
        end
      end
    end
  end
end

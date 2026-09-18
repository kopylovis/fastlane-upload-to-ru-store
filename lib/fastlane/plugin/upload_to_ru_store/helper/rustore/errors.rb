module Fastlane
  module Helper
    module Rustore
      class Error < StandardError; end

      class ConfigurationError < Error; end

      class ApiError < Error
        attr_reader :status, :code, :body, :context

        def initialize(message, status: nil, code: nil, body: nil, context: nil)
          @status = status
          @code = code
          @body = body
          @context = context
          super(message)
        end

        def to_s
          parts = []
          parts << context if context
          parts << "HTTP #{status}" if status
          parts << "code=#{code}" if code
          prefix = parts.empty? ? '' : "#{parts.join(', ')}: "
          "#{prefix}#{super}"
        end
      end
    end
  end
end

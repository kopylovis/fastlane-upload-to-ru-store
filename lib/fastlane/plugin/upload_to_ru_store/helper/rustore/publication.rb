require 'date'
require_relative 'errors'

module Fastlane
  module Helper
    module Rustore
      # Publication rules from the RuStore docs for creating a draft and for
      # changing publish settings, checked before anything is sent.
      module Publication
        module_function

        PUBLISH_TYPES = %w[MANUAL INSTANTLY DELAYED].freeze
        PARTIAL_VALUES = [5, 10, 25, 50, 75, 100].freeze
        PRIORITY_RANGE = (0..5)
        DELAYED = 'DELAYED'.freeze
        MIN_DELAY = 24 * 3600
        MAX_DELAY = 60 * 24 * 3600
        DATETIME_FORMAT = '%Y-%m-%dT%H:%M:%S%:z'.freeze
        DATETIME_PATTERN = /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:?\d{2})\z/

        # Payload for a new draft. publish_datetime matters only for DELAYED, and
        # the API ignores it otherwise, so it is left out.
        def draft_payload(publish_type: nil, publish_datetime: nil, partial_value: nil)
          payload = {}
          payload[:publishType] = publish_type!(publish_type) if publish_type
          payload[:publishDateTime] = delayed_datetime!(publish_datetime) if publish_type == DELAYED
          payload[:partialValue] = partial_value!(partial_value, publish_type) if partial_value
          payload
        end

        # Payload for publish-settings. RuStore changes either the rollout
        # percentage or the publication type with its date, never both at once.
        def settings_payload(publish_type: nil, publish_datetime: nil, partial_value: nil)
          if partial_value && (publish_type || publish_datetime)
            raise ConfigurationError, 'RuStore меняет за один запрос либо partial_value, либо publish_type с publish_datetime'
          end
          if publish_datetime && publish_type != DELAYED
            raise ConfigurationError, 'publish_datetime передается только вместе с publish_type: DELAYED'
          end

          payload = draft_payload(publish_type: publish_type, publish_datetime: publish_datetime, partial_value: partial_value)
          raise ConfigurationError, 'не переданы настройки публикации' if payload.empty?

          payload
        end

        def publish_type!(value)
          return value if PUBLISH_TYPES.include?(value)

          raise ConfigurationError, "неизвестный publish_type: #{value}. Допустимы: #{PUBLISH_TYPES.join(', ')}"
        end

        def partial_value!(value, publish_type = nil)
          number = Integer(value, exception: false)
          unless PARTIAL_VALUES.include?(number)
            raise ConfigurationError, "partial_value должен быть одним из #{PARTIAL_VALUES.join(', ')}, получено #{value}"
          end
          if publish_type == DELAYED
            raise ConfigurationError, 'поэтапная раскатка (partial_value) работает только с publish_type MANUAL и INSTANTLY'
          end

          number
        end

        def priority!(value)
          return nil if value.nil?

          number = Integer(value, exception: false)
          return number if number && PRIORITY_RANGE.cover?(number)

          raise ConfigurationError, "priority_update должен быть от #{PRIORITY_RANGE.min} до #{PRIORITY_RANGE.max}, получено #{value}"
        end

        def delayed_datetime!(value)
          raise ConfigurationError, 'для publish_type = DELAYED обязателен publish_datetime' if value.to_s.empty?

          moment = parse_datetime!(value)
          raise ConfigurationError, "publish_datetime уже в прошлом: #{value}" if moment.to_time <= Time.now

          moment.strftime(DATETIME_FORMAT)
        end

        def parse_datetime!(value)
          text = value.respond_to?(:iso8601) ? value.iso8601 : value.to_s
          unless text.match?(DATETIME_PATTERN)
            raise ConfigurationError,
                  "publish_datetime должен содержать дату, время и часовой пояс, например 2026-06-01T12:00:00+03:00, получено #{value}"
          end

          DateTime.iso8601(text)
        rescue Date::Error
          raise ConfigurationError, "неверная дата publish_datetime: #{value}"
        end

        # The date must fall 24 hours to 60 days after the draft is sent to
        # moderation. Checked only when the submission happens right now.
        def check_window!(value, submitted_at: Time.now)
          delay = parse_datetime!(value).to_time - submitted_at
          return if delay.between?(MIN_DELAY, MAX_DELAY)

          raise ConfigurationError,
                "publish_datetime должен быть через 24 часа или позже и не дальше 60 дней от отправки на модерацию, получено #{value}"
        end
      end
    end
  end
end

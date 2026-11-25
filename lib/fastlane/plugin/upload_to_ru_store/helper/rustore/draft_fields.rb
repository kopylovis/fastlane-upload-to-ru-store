require_relative 'errors'

module Fastlane
  module Helper
    module Rustore
      # Store metadata of a draft, as documented for creating and editing a draft
      # version. Each field is checked locally and mapped onto its API name.
      module DraftFields
        module_function

        APP_TYPES = %w[MAIN GAMES].freeze
        AGE_LEGAL = %w[0+ 6+ 12+ 16+ 18+].freeze
        ORIENTATIONS = %w[LANDSCAPE PORTRAIT].freeze
        IN_APP_PURCHASE_TYPES = %w[PRODUCTS SUBSCRIPTIONS].freeze
        CONTACT_KEYS = %w[email website vkCommunity maxMessenger].freeze
        SDK_KEYS = %w[adsSdks paymentSdks].freeze
        FAQ_LIMITS = { items: 10, question: 120, answer: 500 }.freeze

        FIELDS = {
          app_name: { key: :appName, text: 50 },
          app_type: { key: :appType, one_of: APP_TYPES },
          categories: { key: :categories, list: 2, unique: true },
          age_legal: { key: :ageLegal, one_of: AGE_LEGAL },
          short_description: { key: :shortDescription, text: 80 },
          full_description: { key: :fullDescription, text: 4000 },
          whats_new: { key: :whatsNew, text: 5000 },
          short_description_tv: { key: :shortDescriptionTv, text: 80, not_empty: true },
          full_description_tv: { key: :fullDescriptionTv, text: 4000, not_empty: true },
          whats_new_tv: { key: :whatsNewTv, text: 5000, not_empty: true },
          moder_info: { key: :moderInfo, text: 180 },
          price_value: { key: :priceValue, positive: true },
          seo_tag_ids: { key: :seoTagIds, list: 5, integers: true },
          faq: { key: :faq, faq: true },
          developer_contacts: { key: :developerContacts, object: CONTACT_KEYS },
          video: { key: :video, video: true },
          background_video: { key: :backgroundVideo, video: true },
          privacy_explanation: { key: :privacyExplanation, text: 4000 },
          privacy_data_types: { key: :privacyDataTypes, list: 50 },
          package_sdk: { key: :packageSdkDto, object: SDK_KEYS, lists: 50 },
          in_app_purchase_types: { key: :inAppPurchaseTypes, list: 2, each_one_of: IN_APP_PURCHASE_TYPES }
        }.freeze

        def payload(attributes)
          FIELDS.each_with_object({}) do |(name, spec), payload|
            value = attributes[name]
            next if value.nil?

            payload[spec[:key]] = cast(value, spec, name.to_s)
          end
        end

        def cast(value, spec, name)
          return text!(value, spec, name) if spec[:text]
          return one_of!(value, spec[:one_of], name) if spec[:one_of]
          return positive!(value, name) if spec[:positive]
          return list!(value, spec, name) if spec[:list]
          return faq!(value) if spec[:faq]
          return video!(value, name) if spec[:video]

          object!(value, spec, name)
        end

        def text!(value, spec, name)
          text = value.to_s
          raise ConfigurationError, "#{name} длиннее #{spec[:text]} символов (сейчас #{text.length})" if text.length > spec[:text]
          raise ConfigurationError, "#{name} не может быть пустым" if spec[:not_empty] && text.strip.empty?

          text
        end

        def one_of!(value, allowed, name)
          return value if allowed.include?(value)

          raise ConfigurationError, "неизвестный #{name}: #{value}. Допустимы: #{allowed.join(', ')}"
        end

        def positive!(value, name)
          number = Integer(value, exception: false)
          raise ConfigurationError, "#{name} должен быть целым числом больше 0, получено #{value}" unless number&.positive?

          number
        end

        def list!(value, spec, name)
          items = Array(value)
          raise ConfigurationError, "в #{name} не больше #{spec[:list]} значений (сейчас #{items.size})" if items.size > spec[:list]
          raise ConfigurationError, "значения #{name} должны быть уникальными" if spec[:unique] && items.uniq.size != items.size

          items.map { |item| list_item!(item, spec, name) }
        end

        def list_item!(item, spec, name)
          return integer_item!(item, name) if spec[:integers]
          return one_of!(item, spec[:each_one_of], name) if spec[:each_one_of]

          item
        end

        def integer_item!(item, name)
          Integer(item, exception: false) || raise(ConfigurationError, "#{name} принимает только числа, получено #{item}")
        end

        def faq!(value)
          items = Array(value)
          if items.size > FAQ_LIMITS[:items]
            raise ConfigurationError, "в faq не больше #{FAQ_LIMITS[:items]} вопросов (сейчас #{items.size})"
          end

          items.map do |item|
            entry = stringify(item)
            question = text!(entry['question'], { text: FAQ_LIMITS[:question], not_empty: true }, 'faq question')
            answer = text!(entry['answer'], { text: FAQ_LIMITS[:answer], not_empty: true }, 'faq answer')
            { question: question, answer: answer }
          end
        end

        def video!(value, name)
          entry = stringify(value)
          orientation = one_of!(entry['orientation'].to_s.upcase, ORIENTATIONS, "#{name} orientation")
          url = entry['url'].to_s
          raise ConfigurationError, "#{name} url должен начинаться с http" unless url.start_with?('http')

          { orientation: orientation, url: url }
        end

        def object!(value, spec, name)
          entry = stringify(value)
          unknown = entry.keys - spec[:object]
          if unknown.any?
            raise ConfigurationError, "неизвестные ключи #{name}: #{unknown.join(', ')}. Допустимы: #{spec[:object].join(', ')}"
          end

          entry.to_h do |key, item|
            item = list!(item, { list: spec[:lists] }, "#{name}.#{key}") if spec[:lists]
            [key.to_sym, item]
          end
        end

        # Accepts symbol or string keys, snake_case or camelCase.
        def stringify(value)
          raise ConfigurationError, "ожидается Hash, получено #{value.class}" unless value.respond_to?(:to_h)

          value.to_h.transform_keys { |key| camelize(key.to_s) }
        end

        def camelize(key)
          key.gsub(/_([a-z])/) { Regexp.last_match(1).upcase }
        end
      end
    end
  end
end

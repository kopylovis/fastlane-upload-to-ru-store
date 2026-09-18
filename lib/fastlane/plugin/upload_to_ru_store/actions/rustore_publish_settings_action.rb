require 'fastlane/action'
require 'fastlane_core/ui/ui'
require_relative '../helper/upload_to_ru_store_helper'
require_relative '../helper/rustore/options'

module Fastlane
  module Actions
    class RustorePublishSettingsAction < Action
      Options = Helper::Rustore::Options
      Api = Helper::Rustore::Api

      def self.authors
        ['Kopylov Ivan']
      end

      def self.description
        'Changes publication settings of an existing RuStore version'
      end

      def self.details
        <<~DETAILS
          Updates the publication type, the delayed publication moment or the staged
          rollout percentage of a version that already exists. RuStore only allows the
          rollout percentage to grow, and 100 means a full release.
        DETAILS
      end

      def self.category
        :production
      end

      def self.available_options
        Options.auth + [
          Options.version_id(optional: false),
          Options.publish_type,
          Options.publish_datetime,
          Options.partial_value,
          Options.timeout
        ]
      end

      def self.example_code
        [
          <<~EXAMPLE
            rustore_publish_settings(
              package_name: "com.example.app",
              key_id: ENV["RUSTORE_KEY_ID"],
              private_key: ENV["RUSTORE_PRIVATE_KEY"],
              version_id: 12345,
              partial_value: 50
            )
          EXAMPLE
        ]
      end

      def self.is_supported?(platform)
        platform == :android
      end

      def self.run(params)
        helper = Helper::UploadToRuStoreHelper
        token = helper.fetch_token(key_id: params[:key_id], private_key: params[:private_key])

        settings = {
          publish_type: params[:publish_type],
          publish_datetime: params[:publish_datetime],
          partial_value: params[:partial_value]
        }.compact
        UI.user_error!('Не передано ни одной настройки публикации') if settings.empty?

        helper.update_publish_settings(
          token: token,
          package_name: params[:package_name],
          version_id: params[:version_id],
          **settings
        )
        params[:version_id]
      end
    end
  end
end

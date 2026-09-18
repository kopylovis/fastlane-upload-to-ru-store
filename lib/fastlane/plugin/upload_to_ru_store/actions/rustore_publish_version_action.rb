require 'fastlane/action'
require 'fastlane_core/ui/ui'
require_relative '../helper/upload_to_ru_store_helper'
require_relative '../helper/rustore/options'

module Fastlane
  module Actions
    class RustorePublishVersionAction < Action
      Options = Helper::Rustore::Options

      def self.authors
        ['Kopylov Ivan']
      end

      def self.description
        'Publishes a moderated RuStore version whose publish type is MANUAL'
      end

      def self.details
        <<~DETAILS
          Only a version that has passed moderation and was created with
          publish_type: "MANUAL" can be published this way. When version_id is omitted
          the latest version of the application is used.
        DETAILS
      end

      def self.category
        :production
      end

      def self.available_options
        Options.auth + [Options.version_id(optional: true), Options.timeout]
      end

      def self.example_code
        [
          <<~EXAMPLE
            rustore_publish_version(
              package_name: "com.example.app",
              key_id: ENV["RUSTORE_KEY_ID"],
              private_key: ENV["RUSTORE_PRIVATE_KEY"]
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
        version_id = params[:version_id] || resolve_latest(helper, token, params[:package_name])

        helper.publish_version(token: token, package_name: params[:package_name], version_id: version_id)
        version_id
      end

      def self.resolve_latest(helper, token, package_name)
        version = helper.latest_version(token: token, package_name: package_name)
        UI.user_error!("У #{package_name} нет ни одной версии") if version.nil?
        version['versionId']
      end
    end
  end
end

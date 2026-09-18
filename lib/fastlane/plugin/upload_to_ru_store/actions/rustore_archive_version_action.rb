require 'fastlane/action'
require 'fastlane_core/ui/ui'
require_relative '../helper/upload_to_ru_store_helper'
require_relative '../helper/rustore/options'

module Fastlane
  module Actions
    class RustoreArchiveVersionAction < Action
      Options = Helper::Rustore::Options
      Api = Helper::Rustore::Api

      def self.authors
        ['Kopylov Ivan']
      end

      def self.description
        'Archives a RuStore application version'
      end

      def self.details
        <<~DETAILS
          RuStore only accepts archiving for versions in #{Api::ARCHIVABLE_STATUSES.join(' or ')}.
          The action checks the current status first and fails early with a clear message
          instead of letting the API return an opaque error.
        DETAILS
      end

      def self.category
        :production
      end

      def self.available_options
        Options.auth + [Options.version_id(optional: false), Options.timeout]
      end

      def self.example_code
        [
          <<~EXAMPLE
            rustore_archive_version(
              package_name: "com.example.app",
              key_id: ENV["RUSTORE_KEY_ID"],
              private_key: ENV["RUSTORE_PRIVATE_KEY"],
              version_id: 12345
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

        helper.archive_version(
          token: token,
          package_name: params[:package_name],
          version_id: params[:version_id]
        )
        params[:version_id]
      end
    end
  end
end

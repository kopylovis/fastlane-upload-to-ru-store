require 'fastlane/action'
require 'fastlane_core/ui/ui'
require_relative '../helper/upload_to_ru_store_helper'
require_relative '../helper/rustore/options'

module Fastlane
  module Actions
    class RustoreApplicationsAction < Action
      Options = Helper::Rustore::Options

      def self.authors
        ['Kopylov Ivan']
      end

      def self.description
        'Lists the RuStore applications available to the API key'
      end

      def self.details
        <<~DETAILS
          Returns every application of the account that owns the key, as an Array of
          Hashes with packageName, appName, appStatus, versionName, versionCode and the
          rest of the fields RuStore exposes. app_name and package_name narrow the search.
        DETAILS
      end

      def self.return_value
        'An Array of Hashes, one per application.'
      end

      def self.category
        :production
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :package_name,
            env_name: 'RUSTORE_PACKAGE_NAME',
            description: 'Search by package name',
            optional: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :app_name,
            env_name: 'RUSTORE_APP_NAME',
            description: 'Search by application name',
            optional: true,
            type: String
          ),
          Options.key_id,
          Options.private_key,
          *Options.connection
        ]
      end

      def self.example_code
        [
          <<~EXAMPLE
            apps = rustore_applications(
              key_id: ENV["RUSTORE_KEY_ID"],
              private_key: ENV["RUSTORE_PRIVATE_KEY"]
            )
            apps.each { |app| UI.message("\#{app['packageName']}: \#{app['appStatus']}") }
          EXAMPLE
        ]
      end

      def self.is_supported?(platform)
        platform == :android
      end

      def self.run(params)
        helper = Helper::UploadToRuStoreHelper
        api = helper.session(params)
        apps = helper.applications(api: api, app_name: params[:app_name], app_package: params[:package_name])
        UI.message("Приложений: #{apps.size}")
        apps.each { |app| UI.message("#{app['packageName']} #{app['versionName']} (#{app['versionCode']}): #{app['appStatus']}") }
        apps
      end
    end
  end
end

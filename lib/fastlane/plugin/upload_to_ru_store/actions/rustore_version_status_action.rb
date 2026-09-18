require 'fastlane/action'
require 'fastlane_core/ui/ui'
require_relative '../helper/upload_to_ru_store_helper'
require_relative '../helper/rustore/options'

module Fastlane
  module Actions
    module SharedValues
      RUSTORE_VERSION_ID = :RUSTORE_VERSION_ID
      RUSTORE_VERSION_STATUS = :RUSTORE_VERSION_STATUS
    end

    class RustoreVersionStatusAction < Action
      Options = Helper::Rustore::Options

      def self.authors
        ['Kopylov Ivan']
      end

      def self.description
        'Reads the status of the latest RuStore version of an application'
      end

      def self.details
        <<~DETAILS
          Returns the version record as a Hash: versionId, versionCode, versionName,
          versionStatus, publishType, partialValue and the rest of the fields RuStore
          exposes. Useful to gate a lane on moderation having finished.
        DETAILS
      end

      def self.return_value
        'A Hash describing the latest version, or nil when the application has none.'
      end

      def self.category
        :production
      end

      def self.available_options
        Options.auth + [Options.testing_type, Options.timeout]
      end

      def self.example_code
        [
          <<~EXAMPLE
            version = rustore_version_status(
              package_name: "com.example.app",
              key_id: ENV["RUSTORE_KEY_ID"],
              private_key: ENV["RUSTORE_PRIVATE_KEY"]
            )
            UI.message("Статус: \#{version['versionStatus']}")
          EXAMPLE
        ]
      end

      def self.is_supported?(platform)
        platform == :android
      end

      def self.run(params)
        helper = Helper::UploadToRuStoreHelper
        token = helper.fetch_token(key_id: params[:key_id], private_key: params[:private_key])

        version = helper.latest_version(
          token: token,
          package_name: params[:package_name],
          testing_type: params[:testing_type] || 'ALL'
        )

        if version.nil?
          UI.important("У #{params[:package_name]} нет ни одной версии")
          return nil
        end

        UI.success("Версия #{version['versionName']} (#{version['versionCode']}): #{version['versionStatus']}")
        Actions.lane_context[SharedValues::RUSTORE_VERSION_ID] = version['versionId']
        Actions.lane_context[SharedValues::RUSTORE_VERSION_STATUS] = version['versionStatus']
        version
      end

      def self.output
        [
          ['RUSTORE_VERSION_ID', 'Identifier of the latest version'],
          ['RUSTORE_VERSION_STATUS', 'Status of the latest version']
        ]
      end
    end
  end
end

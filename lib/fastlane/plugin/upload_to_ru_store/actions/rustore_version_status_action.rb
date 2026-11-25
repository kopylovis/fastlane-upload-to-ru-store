require 'fastlane/action'
require 'fastlane_core/ui/ui'
require_relative '../helper/upload_to_ru_store_helper'
require_relative '../helper/rustore/options'

module Fastlane
  module Actions
    module SharedValues
      RUSTORE_VERSION_ID = :RUSTORE_VERSION_ID
      RUSTORE_VERSION_STATUS = :RUSTORE_VERSION_STATUS
      RUSTORE_VERSION_STATUS_COMMENT = :RUSTORE_VERSION_STATUS_COMMENT
    end

    class RustoreVersionStatusAction < Action
      Options = Helper::Rustore::Options

      def self.authors
        ['Kopylov Ivan']
      end

      def self.description
        'Reads the status of a RuStore version, the latest one by default'
      end

      def self.details
        <<~DETAILS
          Returns the version record as a Hash: versionId, versionCode, versionName,
          versionStatus, publishType, partialValue, statusComment and the rest of the
          fields RuStore exposes. statusComment holds the moderator's note, for example
          the reason a version was rejected. Pass version_id to read a specific version.
        DETAILS
      end

      def self.return_value
        'A Hash describing the version, or nil when the application has none.'
      end

      def self.category
        :production
      end

      def self.available_options
        Options.auth + [Options.version_id(optional: true), Options.testing_type, *Options.connection]
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
        api = helper.session(params)

        version = helper.describe_version(
          api: api,
          package_name: params[:package_name],
          version_id: params[:version_id],
          testing_type: params[:testing_type] || 'ALL'
        )

        if version.nil?
          UI.important("У #{params[:package_name]} нет ни одной версии")
          return nil
        end

        report(version)
        Actions.lane_context[SharedValues::RUSTORE_VERSION_ID] = version['versionId']
        Actions.lane_context[SharedValues::RUSTORE_VERSION_STATUS] = version['versionStatus']
        Actions.lane_context[SharedValues::RUSTORE_VERSION_STATUS_COMMENT] = version['statusComment']
        version
      end

      def self.report(version)
        code = version['versionCode'] || version.dig('packages', 0, 'verCode')
        UI.success("Версия #{version['versionName']} (#{code}): #{version['versionStatus']}")
        comment = version['statusComment'].to_s.strip
        UI.important("Комментарий RuStore: #{comment}") unless comment.empty?
      end

      def self.output
        [
          ['RUSTORE_VERSION_ID', 'Identifier of the version'],
          ['RUSTORE_VERSION_STATUS', 'Status of the version'],
          ['RUSTORE_VERSION_STATUS_COMMENT', 'Moderator comment on the status, if any']
        ]
      end
    end
  end
end

require 'fastlane/action'
require 'fastlane_core/ui/ui'
require_relative '../helper/upload_to_ru_store_helper'
require_relative '../helper/rustore/options'

module Fastlane
  module Actions
    class RustoreDeleteDraftAction < Action
      Options = Helper::Rustore::Options

      def self.authors
        ['Kopylov Ivan']
      end

      def self.description
        'Deletes a RuStore draft, or every draft of the package'
      end

      def self.details
        <<~DETAILS
          With version_id deletes that draft. Without it deletes every draft of the
          package, the same cleanup upload_to_ru_store does before a release. RuStore
          deletes only versions that were never published.
        DETAILS
      end

      def self.category
        :production
      end

      def self.available_options
        Options.auth + [Options.version_id(optional: true), *Options.connection]
      end

      def self.example_code
        [
          <<~EXAMPLE
            rustore_delete_draft(
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
        api = helper.session(params)

        if params[:version_id]
          helper.delete_draft(api: api, package_name: params[:package_name], version_id: params[:version_id])
        else
          helper.remove_drafts(api: api, package_name: params[:package_name])
        end
        nil
      end
    end
  end
end

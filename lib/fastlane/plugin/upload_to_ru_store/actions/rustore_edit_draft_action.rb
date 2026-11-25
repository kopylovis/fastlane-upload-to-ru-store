require 'fastlane/action'
require 'fastlane_core/ui/ui'
require_relative '../helper/upload_to_ru_store_helper'
require_relative '../helper/rustore/options'

module Fastlane
  module Actions
    class RustoreEditDraftAction < Action
      Options = Helper::Rustore::Options
      Api = Helper::Rustore::Api

      def self.authors
        ['Kopylov Ivan']
      end

      def self.description
        'Changes the store fields of a RuStore draft that is not in moderation yet'
      end

      def self.details
        <<~DETAILS
          Sends only the fields you pass, through the v2 draft edit endpoint. The field
          rules match upload_to_ru_store. Without version_id the current draft of the
          package is edited. Useful after upload_to_ru_store with
          submit_for_moderation: false, to fill in metadata before the submit.
        DETAILS
      end

      def self.return_value
        'The identifier of the edited draft, as an Integer.'
      end

      def self.category
        :production
      end

      def self.available_options
        Options.auth + [
          Options.version_id(optional: true),
          Options.publish_type,
          Options.publish_datetime,
          Options.partial_value,
          Options.existing_file(:changelog_path, 'RUSTORE_CHANGELOG_PATH',
                                "Path to a changelog file, up to #{Api::LIMITS[:whats_new]} characters"),
          *Options.metadata,
          *Options.connection
        ]
      end

      def self.example_code
        [
          <<~EXAMPLE
            rustore_edit_draft(
              package_name: "com.example.app",
              key_id: ENV["RUSTORE_KEY_ID"],
              private_key: ENV["RUSTORE_PRIVATE_KEY"],
              short_description: "Новое краткое описание",
              categories: ["news"]
            )
          EXAMPLE
        ]
      end

      def self.is_supported?(platform)
        platform == :android
      end

      def self.run(params)
        helper = Helper::UploadToRuStoreHelper
        attributes = (Options::METADATA_KEYS + %i[publish_type publish_datetime partial_value]).to_h { |key| [key, params[key]] }.compact
        UI.user_error!('Не передано ни одного поля черновика') if attributes.empty? && params[:changelog_path].nil?

        api = helper.session(params)
        helper.edit_draft(
          api: api,
          package_name: params[:package_name],
          version_id: params[:version_id],
          changelog_path: params[:changelog_path],
          **attributes
        )
      end
    end
  end
end

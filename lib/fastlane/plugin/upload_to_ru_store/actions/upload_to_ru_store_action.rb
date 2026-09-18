require 'fastlane/action'
require 'fastlane_core/ui/ui'
require_relative '../helper/upload_to_ru_store_helper'
require_relative '../helper/rustore/options'

module Fastlane
  module Actions
    class UploadToRuStoreAction < Action
      Options = Helper::Rustore::Options
      Api = Helper::Rustore::Api

      def self.authors
        ['Kopylov Ivan']
      end

      def self.description
        'Uploads an AAB/APK release to RuStore and sends it to moderation'
      end

      def self.details
        <<~DETAILS
          Creates a draft version in RuStore, fills in the metadata you pass, uploads the
          build (AAB, or GMS and HMS APKs) and submits the draft for moderation.

          Existing drafts of the package are removed first, so a rerun after a failed
          attempt does not pile them up. Set remove_existing_drafts to false to keep them.

          Staged rollout is supported through partial_value, and delayed publishing through
          publish_type: "DELAYED" together with publish_datetime.
        DETAILS
      end

      def self.return_value
        'The identifier of the created draft version, as an Integer.'
      end

      def self.category
        :production
      end

      def self.available_options
        Options.auth + [
          Options.publish_type,
          Options.publish_datetime,
          Options.partial_value,
          Options.timeout,
          Options.existing_file(:aab, 'RUSTORE_AAB', 'Path to the AAB'),
          Options.existing_file(:gms_apk, 'RUSTORE_GMS_APK', 'Path to the GMS APK'),
          Options.existing_file(:hms_apk, 'RUSTORE_HMS_APK', 'Path to the HMS APK'),
          Options.existing_file(:changelog_path, 'RUSTORE_CHANGELOG_PATH',
                                "Path to a changelog file, up to #{Api::LIMITS[:whats_new]} characters"),
          FastlaneCore::ConfigItem.new(
            key: :whats_new,
            env_name: 'RUSTORE_WHATS_NEW',
            description: 'Release notes given inline, an alternative to changelog_path',
            optional: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :app_name,
            env_name: 'RUSTORE_APP_NAME',
            description: "Application name, up to #{Api::LIMITS[:app_name]} characters",
            optional: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :app_type,
            env_name: 'RUSTORE_APP_TYPE',
            description: "Application type: #{Api::APP_TYPES.join('/')}",
            optional: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :age_legal,
            env_name: 'RUSTORE_AGE_LEGAL',
            description: "Age rating: #{Api::AGE_LEGAL.join('/')}",
            optional: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :short_description,
            env_name: 'RUSTORE_SHORT_DESCRIPTION',
            description: "Short description, up to #{Api::LIMITS[:short_description]} characters",
            optional: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :full_description,
            env_name: 'RUSTORE_FULL_DESCRIPTION',
            description: "Full description, up to #{Api::LIMITS[:full_description]} characters",
            optional: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :moder_info,
            env_name: 'RUSTORE_MODER_INFO',
            description: "Note for the moderator, up to #{Api::LIMITS[:moder_info]} characters",
            optional: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :price_value,
            env_name: 'RUSTORE_PRICE_VALUE',
            description: 'Price in kopecks for paid applications',
            optional: true,
            type: Integer
          ),
          FastlaneCore::ConfigItem.new(
            key: :remove_existing_drafts,
            env_name: 'RUSTORE_REMOVE_EXISTING_DRAFTS',
            description: 'Delete existing drafts of the package before creating a new one',
            optional: true,
            default_value: true,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :submit_for_moderation,
            env_name: 'RUSTORE_SUBMIT_FOR_MODERATION',
            description: 'Submit the draft for moderation once the build is uploaded',
            optional: true,
            default_value: true,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :priority_update,
            env_name: 'RUSTORE_PRIORITY_UPDATE',
            description: 'Priority update value passed to the moderation request',
            optional: true,
            type: Integer
          )
        ]
      end

      def self.example_code
        [
          <<~BASIC,
            upload_to_ru_store(
              package_name: "com.example.app",
              key_id: ENV["RUSTORE_KEY_ID"],
              private_key: ENV["RUSTORE_PRIVATE_KEY"],
              aab: "app/build/outputs/bundle/release/app-release.aab",
              changelog_path: "fastlane/changelog.txt"
            )
          BASIC
          <<~STAGED,
            upload_to_ru_store(
              package_name: "com.example.app",
              key_id: ENV["RUSTORE_KEY_ID"],
              private_key: ENV["RUSTORE_PRIVATE_KEY"],
              aab: "app-release.aab",
              publish_type: "INSTANTLY",
              partial_value: 10
            )
          STAGED
          <<~DELAYED
            upload_to_ru_store(
              package_name: "com.example.app",
              key_id: ENV["RUSTORE_KEY_ID"],
              private_key: ENV["RUSTORE_PRIVATE_KEY"],
              gms_apk: "app-gms.apk",
              hms_apk: "app-hms.apk",
              publish_type: "DELAYED",
              publish_datetime: "2026-06-01T12:00:00+03:00"
            )
          DELAYED
        ]
      end

      def self.is_supported?(platform)
        platform == :android
      end

      def self.run(params)
        helper = Helper::UploadToRuStoreHelper
        package_name = params[:package_name]
        validate_sources!(params)

        token = helper.fetch_token(key_id: params[:key_id], private_key: params[:private_key])
        helper.remove_drafts(token: token, package_name: package_name) if params[:remove_existing_drafts]

        draft_id = helper.create_draft(
          token: token,
          package_name: package_name,
          publish_type: params[:publish_type],
          publish_datetime: params[:publish_datetime],
          changelog_path: params[:changelog_path],
          **draft_attributes(params)
        )
        UI.message("Создан черновик ##{draft_id}")

        upload_builds(helper, token, draft_id, params)
        finish(helper, token, draft_id, params)

        Actions.lane_context[SharedValues::RUSTORE_VERSION_ID] = draft_id
        draft_id
      end

      def self.validate_sources!(params)
        UI.user_error!('Необходимо указать aab или gms_apk') if params[:aab].nil? && params[:gms_apk].nil?
        UI.important('Указаны и aab, и gms_apk — будет загружен только aab') if params[:aab] && params[:gms_apk]
      end

      def self.upload_builds(helper, token, draft_id, params)
        common = { token: token, draft_id: draft_id, package_name: params[:package_name] }

        if params[:aab]
          helper.upload_build(**common, file_path: params[:aab], build_type: 'aab')
        else
          helper.upload_build(**common, file_path: params[:gms_apk], build_type: 'apk', service_type: 'GMS')
        end

        return unless params[:hms_apk]

        helper.upload_build(**common, file_path: params[:hms_apk], build_type: 'apk', service_type: 'HMS')
      end

      def self.finish(helper, token, draft_id, params)
        unless params[:submit_for_moderation]
          UI.important("Черновик ##{draft_id} создан, но не отправлен на модерацию")
          return
        end

        helper.commit_draft(
          token: token, draft_id: draft_id, package_name: params[:package_name],
          priority_update: params[:priority_update]
        )
      end

      def self.draft_attributes(params)
        {
          whats_new: params[:whats_new],
          partial_value: params[:partial_value],
          app_name: params[:app_name],
          app_type: params[:app_type],
          age_legal: params[:age_legal],
          short_description: params[:short_description],
          full_description: params[:full_description],
          moder_info: params[:moder_info],
          price_value: params[:price_value]
        }.compact
      end

      def self.output
        [['RUSTORE_VERSION_ID', 'Identifier of the draft version created by this action']]
      end
    end
  end
end

require 'fastlane/action'
require 'fastlane_core/ui/ui'
require_relative 'upload_to_ru_store_helper'

module Fastlane
  module Actions
    # Uploads Android builds (AAB/APK) to RuStore
    class UploadToRuStoreAction < Action
      def self.authors
        ['Kopylov Ivan']
      end

      def self.description
        'Uploads AAB and optional APK bundles to RuStore, cleans up drafts before publishing.'
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :package_name, env_name: 'RUSTORE_PACKAGE_NAME', description: 'App package (e.g. com.example.app)', optional: false, type: String),
          FastlaneCore::ConfigItem.new(key: :key_id, env_name: 'RUSTORE_KEY_ID', description: 'RuStore API key ID', optional: false, type: String),
          FastlaneCore::ConfigItem.new(key: :private_key, env_name: 'RUSTORE_PRIVATE_KEY', description: 'RUStore RSA private key (PEM)', optional: false, type: String),
          FastlaneCore::ConfigItem.new(key: :publish_type, env_name: 'RUSTORE_PUBLISH_TYPE', description: 'Publication type: MANUAL/DELAYED/INSTANTLY', optional: true, type: String),
          FastlaneCore::ConfigItem.new(key: :aab, env_name: 'RUSTORE_AAB', description: 'Path to AAB', optional: true, type: String),
          FastlaneCore::ConfigItem.new(key: :gms_apk, env_name: 'RUSTORE_GMS_APK', description: 'Path to GMS APK', optional: true, type: String),
          FastlaneCore::ConfigItem.new(key: :hms_apk, env_name: 'RUSTORE_HMS_APK', description: 'Path to HMS APK (optional)', optional: true, type: String),
          FastlaneCore::ConfigItem.new(key: :changelog_path, env_name: 'RUSTORE_CHANGELOG_PATH', description: 'Path to changelog .txt', optional: true, type: String)
        ]
      end

      def self.is_supported?(platform)
        platform == :android
      end

      def self.run(params)
        token = Helper::UploadToRuStoreHelper.fetch_token(
          key_id: params[:key_id],
          private_key: params[:private_key]
        )

        Helper::UploadToRuStoreHelper.remove_drafts(
          token: token,
          package_name: params[:package_name]
        )

        draft_id = Helper::UploadToRuStoreHelper.create_draft(
          token: token,
          package_name: params[:package_name],
          publish_type: params[:publish_type],
          changelog_path: params[:changelog_path]
        )

        if params[:aab]
          Helper::UploadToRuStoreHelper.upload_build(
            token: token,
            draft_id: draft_id,
            file_path: params[:aab],
            package_name: params[:package_name],
            build_type: 'aab'
          )
        elsif params[:gms_apk]
          Helper::UploadToRuStoreHelper.upload_build(
            token: token,
            draft_id: draft_id,
            file_path: params[:gms_apk],
            package_name: params[:package_name],
            build_type: 'apk',
            service_type: 'GMS'
          )
        else
          UI.user_error!('Необходимо указать AAB или GMS_APK')
        end

        if params[:hms_apk]
          Helper::UploadToRuStoreHelper.upload_build(
            token: token,
            draft_id: draft_id,
            file_path: params[:hms_apk],
            package_name: params[:package_name],
            build_type: 'apk',
            service_type: 'HMS'
          )
        end

        Helper::UploadToRuStoreHelper.commit_draft(
          token: token,
          draft_id: draft_id,
          package_name: params[:package_name]
        )
      end
    end
  end
end

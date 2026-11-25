require 'fastlane/action'
require 'fastlane_core/ui/ui'
require_relative '../helper/upload_to_ru_store_helper'
require_relative '../helper/rustore/options'

module Fastlane
  module Actions
    class RustoreUploadImagesAction < Action
      Options = Helper::Rustore::Options

      def self.authors
        ['Kopylov Ivan']
      end

      def self.description
        'Uploads the icon and screenshots of a RuStore draft'
      end

      def self.details
        <<~DETAILS
          Uploads the icon (PNG or JPEG, 512x512, up to 3 MB) and screenshots for phone,
          tablet and TV (PNG or JPEG, sides 320 to 3840 px, up to 5 MB, 10 per device
          type). Screenshots go into slots in the order given. Their orientation is read
          from the image size unless screenshots_orientation is set; RuStore refuses
          mixed orientations. By default screenshots of the same device type already on
          the draft are deleted first. Without version_id the current draft is used.
        DETAILS
      end

      def self.category
        :production
      end

      def self.available_options
        Options.auth + [Options.version_id(optional: true), *Options.images, *Options.connection]
      end

      def self.example_code
        [
          <<~EXAMPLE
            rustore_upload_images(
              package_name: "com.example.app",
              key_id: ENV["RUSTORE_KEY_ID"],
              private_key: ENV["RUSTORE_PRIVATE_KEY"],
              icon: "metadata/rustore/icon.png",
              screenshots: Dir["metadata/rustore/phone/*.png"].sort
            )
          EXAMPLE
        ]
      end

      def self.is_supported?(platform)
        platform == :android
      end

      def self.run(params)
        UI.user_error!('Укажите icon или хотя бы один список скриншотов') unless Options.images?(params)

        helper = Helper::UploadToRuStoreHelper
        api = helper.session(params)
        version_id = params[:version_id] || helper.current_draft(api: api, package_name: params[:package_name])

        helper.upload_images(
          api: api, package_name: params[:package_name], version_id: version_id,
          icon: params[:icon], screenshots: Options.screenshot_sets(params),
          orientation: params[:screenshots_orientation], replace: params[:replace_screenshots] != false
        )
        version_id
      end
    end
  end
end

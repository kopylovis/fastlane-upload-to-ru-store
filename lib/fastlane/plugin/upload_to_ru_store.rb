require 'fastlane/plugin/upload_to_ru_store/version'

module Fastlane
  module UploadToRuStore
    def self.all_classes
      Dir.glob(
        File.expand_path('upload_to_ru_store/{actions,helper}/*.rb', __dir__)
      )
    end
  end
end

Fastlane::UploadToRuStore
  .all_classes
  .each { |file| require file }
require 'fastlane/plugin/upload_to_ru_store/version'

module Fastlane
  module UploadToRuStore
    def self.all_classes
      Dir[
        File.expand_path(
          '../{actions,helper}/*.rb',
          File.dirname(__FILE__)
        )
      ]
    end
  end
end

# Подключаем все Action и Helper автоматически
Fastlane::UploadToRuStore
  .all_classes
  .each { |file| require file }
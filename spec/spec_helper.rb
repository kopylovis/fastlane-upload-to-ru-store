# spec/spec_helper.rb
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'simplecov'
SimpleCov.start

module SpecHelper
end

require 'fastlane'
require 'fastlane/plugin/upload_to_ru_store'

Fastlane.load_actions
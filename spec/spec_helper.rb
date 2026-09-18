$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
end

require 'fastlane'
require 'webmock/rspec'
require 'fastlane/plugin/upload_to_ru_store'

Fastlane.load_actions

WebMock.disable_net_connect!(allow_localhost: false)

module SpecHelper
  BASE_URL = Fastlane::Helper::UploadToRuStoreHelper::BASE_URL

  def self.rsa_key
    @rsa_key ||= OpenSSL::PKey::RSA.new(2048)
  end

  def self.json(body)
    { status: 200, body: body.to_json, headers: { 'Content-Type' => 'application/json' } }
  end

  def self.error(status, body)
    { status: status, body: body.to_json, headers: { 'Content-Type' => 'application/json' } }
  end
end

RSpec.configure do |config|
  config.before do
    Fastlane::Helper::UploadToRuStoreHelper.reset!
  end
end

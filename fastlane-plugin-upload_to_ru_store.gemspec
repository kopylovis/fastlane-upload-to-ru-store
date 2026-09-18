lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/upload_to_ru_store/version'

Gem::Specification.new do |spec|
  spec.name = 'fastlane-plugin-upload_to_ru_store'
  spec.version = Fastlane::UploadToRuStore::VERSION
  spec.author = 'Kopylov Ivan'
  spec.email = 'mnrhwow@gmail.com'

  spec.summary = 'Fastlane plugin to upload Android builds to RuStore'
  spec.homepage = 'https://github.com/kopylovis/fastlane-upload-to-ru-store'
  spec.license = 'MIT'

  spec.metadata = {
    'source_code_uri' => spec.homepage,
    'bug_tracker_uri' => "#{spec.homepage}/issues",
    'changelog_uri' => "#{spec.homepage}/blob/master/CHANGELOG.md",
    'rubygems_mfa_required' => 'true'
  }

  spec.files = Dir['lib/**/*'] + %w[README.md LICENSE CHANGELOG.md]
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 3.1'

  spec.add_dependency 'faraday', '~> 2.0'
  spec.add_dependency 'faraday-follow_redirects', '~> 0.3'
  spec.add_dependency 'faraday-multipart', '~> 1.0'
end

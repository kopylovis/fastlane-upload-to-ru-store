# fastlane-plugin-upload_to_ru_store.gemspec
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

  spec.files = Dir['lib/**/*'] + %w(README.md LICENSE)
  spec.test_files = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.6'

  # Не добавляем зависимость на fastlane, чтобы избежать циклической ссылки
  # spec.add_dependency 'your-dependency', '~> 1.0.0'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'fastlane', '>= 2.214.0'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rspec_junit_formatter'
  spec.add_development_dependency 'rubocop', '>= 1.12.1'
  spec.add_development_dependency 'rubocop-performance'
  spec.add_development_dependency 'rubocop-require_tools'
  spec.add_development_dependency 'simplecov'
end
source('https://rubygems.org')

gemspec

group :development, :test do
  gem 'fastlane', '>= 2.240.0'
  gem 'rake', '~> 13.0'
  gem 'rspec', '~> 3.13'
  gem 'rspec_junit_formatter', '~> 0.6'
  gem 'rubocop', '~> 1.79'
  gem 'rubocop-performance', '~> 1.25'
  gem 'simplecov', '~> 0.22'
  gem 'webmock', '~> 3.25'
end

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)

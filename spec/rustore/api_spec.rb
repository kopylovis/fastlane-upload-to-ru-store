require 'spec_helper'

describe Fastlane::Helper::Rustore::Api do
  let(:base) { SpecHelper::BASE_URL }
  let(:pkg) { 'com.example.app' }
  let(:api) { described_class.new(client: Fastlane::Helper::Rustore::Client.new) }
  let(:api_error) { Fastlane::Helper::Rustore::ApiError }
  let(:config_error) { Fastlane::Helper::Rustore::ConfigurationError }

  before { api.client.token = 'jwe' }

  describe '#authenticate' do
    it 'stores the token on the client' do
      stub_request(:post, "#{base}/public/auth/").to_return(SpecHelper.json(body: { jwe: 'fresh' }))
      signer = Fastlane::Helper::Rustore::Signer.new(key_id: 'kid', private_key: SpecHelper.rsa_key.to_pem)

      api.authenticate(signer)

      expect(api.client.token).to eq('fresh')
    end
  end

  describe '#create_draft' do
    it 'maps snake_case attributes onto the RuStore payload' do
      stub = stub_request(:post, "#{base}/public/v1/application/#{pkg}/version")
             .with(body: {
                     publishType: 'INSTANTLY', partialValue: 25, appName: 'Example',
                     ageLegal: '12+', shortDescription: 'short', whatsNew: 'notes'
                   })
             .to_return(SpecHelper.json(body: 7))

      id = api.create_draft(pkg, publish_type: 'INSTANTLY', partial_value: 25, app_name: 'Example',
                                 age_legal: '12+', short_description: 'short', whats_new: 'notes')

      expect(id).to eq(7)
      expect(stub).to have_been_requested
    end

    it 'rejects a rollout percentage RuStore does not accept' do
      expect { api.create_draft(pkg, partial_value: 33) }.to raise_error(config_error, /partial_value/)
    end

    it 'rejects an age rating outside the allowed set' do
      expect { api.create_draft(pkg, age_legal: '7+') }.to raise_error(config_error, /age_legal/)
    end

    it 'enforces the documented field limits' do
      expect { api.create_draft(pkg, short_description: 'x' * 81) }
        .to raise_error(config_error, /short_description длиннее 80/)
    end

    it 'allows a changelog up to 5000 characters' do
      stub_request(:post, "#{base}/public/v1/application/#{pkg}/version").to_return(SpecHelper.json(body: 1))
      expect { api.create_draft(pkg, whats_new: 'x' * 5000) }.not_to raise_error
    end
  end

  describe '#each_version' do
    it 'stops once a short page arrives' do
      full = { body: { content: Array.new(100) { |i| { 'versionId' => i, 'versionStatus' => 'DRAFT' } } } }
      tail = { body: { content: [{ 'versionId' => 999, 'versionStatus' => 'ACTIVE' }] } }

      stub_request(:get, "#{base}/public/v1/application/#{pkg}/version")
        .with(query: hash_including('page' => '0')).to_return(SpecHelper.json(full))
      stub_request(:get, "#{base}/public/v1/application/#{pkg}/version")
        .with(query: hash_including('page' => '1')).to_return(SpecHelper.json(tail))

      expect(api.each_version(pkg).count).to eq(101)
    end
  end

  describe '#latest_version' do
    it 'picks the highest versionCode' do
      payload = { body: { content: [
        { 'versionId' => 1, 'versionCode' => 10 },
        { 'versionId' => 2, 'versionCode' => 42 }
      ] } }
      stub_request(:get, "#{base}/public/v1/application/#{pkg}/version")
        .with(query: hash_including('page' => '0')).to_return(SpecHelper.json(payload))

      expect(api.latest_version(pkg)['versionId']).to eq(2)
    end
  end

  describe '#publish' do
    it 'calls the manual publication endpoint' do
      stub = stub_request(:post, "#{base}/public/v1/application/#{pkg}/version/5/publish")
             .to_return(SpecHelper.json(code: 'OK'))

      api.publish(pkg, 5)

      expect(stub).to have_been_requested
    end
  end

  describe '#archive' do
    it 'calls the archive endpoint' do
      stub = stub_request(:post, "#{base}/public/v1/application/#{pkg}/version/5/archive")
             .to_return(SpecHelper.json(code: 'OK'))

      api.archive(pkg, 5)

      expect(stub).to have_been_requested
    end

    it 'surfaces the RuStore error when the status forbids archiving' do
      stub_request(:post, "#{base}/public/v1/application/#{pkg}/version/5/archive")
        .to_return(SpecHelper.error(400, message: 'wrong status'))

      expect { api.archive(pkg, 5) }.to raise_error(api_error, /wrong status/)
    end
  end

  describe '#update_publish_settings' do
    it 'sends only the settings given' do
      stub = stub_request(:post, "#{base}/public/v1/application/#{pkg}/version/5/publish-settings")
             .with(body: { partialValue: 50 })
             .to_return(SpecHelper.json(code: 'OK'))

      api.update_publish_settings(pkg, 5, partial_value: 50)

      expect(stub).to have_been_requested
    end

    it 'refuses an empty update' do
      expect { api.update_publish_settings(pkg, 5) }.to raise_error(config_error, /не переданы/)
    end
  end

  describe '#commit' do
    it 'reports a failing moderation submit' do
      stub_request(:post, "#{base}/public/v1/application/#{pkg}/version/5/commit")
        .to_return(SpecHelper.error(409, message: 'no build uploaded'))

      expect { api.commit(pkg, 5) }.to raise_error(api_error, /no build uploaded/)
    end
  end
end

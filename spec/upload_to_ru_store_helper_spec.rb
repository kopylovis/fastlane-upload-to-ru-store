require 'spec_helper'

describe Fastlane::Helper::UploadToRuStoreHelper do
  let(:base) { SpecHelper::BASE_URL }
  let(:pkg) { 'com.example.app' }
  let(:token) { 'jwe-token' }
  let(:key) { SpecHelper.rsa_key }
  let(:fastlane_error) { FastlaneCore::Interface::FastlaneError }

  describe '.fetch_token' do
    it 'returns the jwe from the response' do
      stub_request(:post, "#{base}/public/auth/")
        .to_return(SpecHelper.json(body: { jwe: token }))

      result = described_class.fetch_token(key_id: 'kid', private_key: key.to_pem)
      expect(result).to eq(token)
    end

    it 'accepts a bare Base64 PKCS#8 key' do
      der = Base64.strict_encode64(key.private_to_der)
      stub_request(:post, "#{base}/public/auth/")
        .to_return(SpecHelper.json(body: { jwe: token }))

      expect(described_class.fetch_token(key_id: 'kid', private_key: der)).to eq(token)
    end

    it 'fails with a clear message when the key cannot be parsed' do
      expect { described_class.fetch_token(key_id: 'kid', private_key: 'not-a-key') }
        .to raise_error(fastlane_error, /private_key/)
    end

    it 'fails when the API answers with an error status' do
      stub_request(:post, "#{base}/public/auth/")
        .to_return(SpecHelper.error(401, message: 'bad signature'))

      expect { described_class.fetch_token(key_id: 'kid', private_key: key.to_pem) }
        .to raise_error(fastlane_error, /HTTP 401.*bad signature/)
    end

    it 'does not crash when the error body is not JSON' do
      stub_request(:post, "#{base}/public/auth/")
        .to_return(status: 502, body: '<html>Bad Gateway</html>', headers: { 'Content-Type' => 'text/html' })

      expect { described_class.fetch_token(key_id: 'kid', private_key: key.to_pem) }
        .to raise_error(fastlane_error, /HTTP 502/)
    end
  end

  describe '.create_draft' do
    it 'sends publishDateTime for DELAYED publishing' do
      stub = stub_request(:post, "#{base}/public/v1/application/#{pkg}/version")
             .with(body: { publishType: 'DELAYED', publishDateTime: '2026-06-01T12:00:00+03:00' })
             .to_return(SpecHelper.json(body: 42))

      id = described_class.create_draft(
        token: token, package_name: pkg,
        publish_type: 'DELAYED', publish_datetime: '2026-06-01T12:00:00+03:00'
      )

      expect(id).to eq(42)
      expect(stub).to have_been_requested
    end

    it 'refuses DELAYED without a datetime' do
      expect { described_class.create_draft(token: token, package_name: pkg, publish_type: 'DELAYED') }
        .to raise_error(fastlane_error, /publish_datetime/)
    end

    it 'rejects an unknown publish_type' do
      expect { described_class.create_draft(token: token, package_name: pkg, publish_type: 'WHENEVER') }
        .to raise_error(fastlane_error, /publish_type/)
    end

    it 'extracts the draft id out of a message when body is absent' do
      stub_request(:post, "#{base}/public/v1/application/#{pkg}/version")
        .to_return(SpecHelper.json(message: 'Draft 777 already exists'))

      expect(described_class.create_draft(token: token, package_name: pkg)).to eq(777)
    end
  end

  describe '.remove_drafts' do
    it 'walks every page and deletes only drafts' do
      first = { body: { content: Array.new(100) { |i| { 'versionId' => i, 'versionStatus' => i.zero? ? 'DRAFT' : 'PUBLISHED' } } } }
      second = { body: { content: [{ 'versionId' => 500, 'versionStatus' => 'DRAFT' }] } }

      stub_request(:get, "#{base}/public/v1/application/#{pkg}/version")
        .with(query: hash_including('page' => '0')).to_return(SpecHelper.json(first))
      stub_request(:get, "#{base}/public/v1/application/#{pkg}/version")
        .with(query: hash_including('page' => '1')).to_return(SpecHelper.json(second))

      del0 = stub_request(:delete, "#{base}/public/v1/application/#{pkg}/version/0").to_return(status: 204)
      del500 = stub_request(:delete, "#{base}/public/v1/application/#{pkg}/version/500").to_return(status: 204)

      described_class.remove_drafts(token: token, package_name: pkg)

      expect(del0).to have_been_requested
      expect(del500).to have_been_requested
    end
  end

  describe '.upload_build' do
    let(:aab) { File.join(Dir.tmpdir, 'sample.aab') }

    before { File.write(aab, 'binary') }
    after { FileUtils.rm_f(aab) }

    it 'fails when the file is missing' do
      expect do
        described_class.upload_build(
          token: token, draft_id: 1, file_path: '/nope/missing.aab',
          package_name: pkg, build_type: 'aab'
        )
      end.to raise_error(fastlane_error, /не найден/)
    end

    it 'reports an already uploaded versionCode' do
      stub_request(:post, "#{base}/public/v1/application/#{pkg}/version/1/aab")
        .to_return(SpecHelper.json(message: 'versionCode must be larger'))

      expect do
        described_class.upload_build(
          token: token, draft_id: 1, file_path: aab, package_name: pkg, build_type: 'aab'
        )
      end.to raise_error(fastlane_error, /versionCode/)
    end

    it 'rejects an unknown build type' do
      expect do
        described_class.upload_build(
          token: token, draft_id: 1, file_path: aab, package_name: pkg, build_type: 'ipa'
        )
      end.to raise_error(fastlane_error, /тип сборки/)
    end
  end

  describe '.commit_draft' do
    it 'raises when the API rejects the commit' do
      stub_request(:post, "#{base}/public/v1/application/#{pkg}/version/5/commit")
        .to_return(SpecHelper.error(409, message: 'nothing to publish'))

      expect { described_class.commit_draft(token: token, draft_id: 5, package_name: pkg) }
        .to raise_error(fastlane_error, /nothing to publish/)
    end
  end
end

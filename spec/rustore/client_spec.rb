require 'spec_helper'

describe Fastlane::Helper::Rustore::Client do
  let(:base) { SpecHelper::BASE_URL }
  let(:client) { described_class.new }
  let(:api_error) { Fastlane::Helper::Rustore::ApiError }
  let(:path) { '/public/v1/application/com.example.app/version' }

  before { allow(client).to receive(:sleep) }

  describe 'retries' do
    it 'repeats a GET after a 503' do
      stub_request(:get, "#{base}#{path}")
        .to_return(SpecHelper.error(503, message: 'busy'))
        .then.to_return(SpecHelper.json(body: { content: [] }))

      expect(client.get(path).status).to eq(200)
    end

    it 'does not repeat a POST after a 500, the server may have applied it' do
      stub = stub_request(:post, "#{base}#{path}").to_return(SpecHelper.error(500, message: 'oops'))

      expect(client.post(path, body: {}).status).to eq(500)
      expect(stub).to have_been_requested.once
    end

    it 'repeats a POST after a 429' do
      stub_request(:post, "#{base}#{path}")
        .to_return(SpecHelper.error(429, message: 'slow down'))
        .then.to_return(SpecHelper.json(body: 1))

      expect(client.post(path, body: {}).status).to eq(200)
    end

    it 'does not repeat a POST after a read timeout' do
      stub = stub_request(:post, "#{base}#{path}").to_raise(Net::ReadTimeout)

      expect { client.post(path, body: {}) }.to raise_error(api_error, /сеть недоступна/)
      expect(stub).to have_been_requested.once
    end

    it 'repeats a POST that never reached the server' do
      stub_request(:post, "#{base}#{path}")
        .to_raise(Errno::ECONNREFUSED)
        .then.to_return(SpecHelper.json(body: 1))

      expect(client.post(path, body: {}).status).to eq(200)
    end

    it 'repeats a POST after a connect timeout' do
      stub_request(:post, "#{base}#{path}").to_timeout.then.to_return(SpecHelper.json(body: 1))

      expect(client.post(path, body: {}).status).to eq(200)
    end

    it 'gives up after three attempts' do
      stub = stub_request(:get, "#{base}#{path}").to_raise(Net::ReadTimeout)

      expect { client.get(path) }.to raise_error(api_error)
      expect(stub).to have_been_requested.times(3)
    end
  end

  describe '#post_file' do
    let(:file) { File.join(Dir.tmpdir, 'client-spec.aab') }

    before { File.write(file, 'x' * 1000) }
    after { FileUtils.rm_f(file) }

    it 'sends the whole file again when the upload is repeated' do
      sizes = []
      stub_request(:post, "#{base}#{path}/1/aab").to_return do |request|
        sizes << request.body.bytesize
        sizes.size == 1 ? SpecHelper.error(429, message: 'later') : SpecHelper.json(body: nil)
      end

      client.post_file("#{path}/1/aab", file_path: file, content_type: 'application/octet-stream')

      expect(sizes.size).to eq(2)
      expect(sizes.uniq.size).to eq(1)
      expect(sizes.first).to be > 1000
    end
  end

  it 'parses JSON served with a charset' do
    stub_request(:get, "#{base}#{path}")
      .to_return(status: 200, body: { body: 5 }.to_json, headers: { 'Content-Type' => 'application/json;charset=UTF-8' })

    expect(client.get(path).payload).to eq(5)
  end
end

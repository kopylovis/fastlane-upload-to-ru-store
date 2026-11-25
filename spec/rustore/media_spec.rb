require 'spec_helper'
require 'zlib'

module ImageFixtures
  module_function

  def png(path, width, height)
    chunk = ->(type, data) { [data.bytesize].pack('N') + type + data + [Zlib.crc32(type + data)].pack('N') }
    ihdr = [width, height, 8, 2, 0, 0, 0].pack('NNCCCCC')
    File.binwrite(path, "\x89PNG\r\n\x1A\n".b + chunk.call('IHDR', ihdr) + chunk.call('IEND', ''))
    path
  end

  def jpeg(path, width, height)
    app0 = "\xFF\xE0".b + [16].pack('n') + "JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00".b
    sof = "\xFF\xC0".b + [17, 8, height, width, 3].pack('nCnnC') + ("\x01\x11\x00" * 3).b
    File.binwrite(path, "\xFF\xD8".b + app0 + sof + "\xFF\xD9".b)
    path
  end
end

describe Fastlane::Helper::Rustore::Media do
  let(:dir) { Dir.mktmpdir }
  let(:config_error) { Fastlane::Helper::Rustore::ConfigurationError }

  after { FileUtils.rm_rf(dir) }

  it 'reads PNG and JPEG sizes' do
    expect(Fastlane::Helper::Rustore::ImageInfo.dimensions(ImageFixtures.png("#{dir}/a.png", 512, 512))).to eq([512, 512])
    expect(Fastlane::Helper::Rustore::ImageInfo.dimensions(ImageFixtures.jpeg("#{dir}/b.jpg", 1080, 1920))).to eq([1080, 1920])
  end

  it 'accepts a 512x512 icon and refuses another size' do
    expect(described_class.icon!(ImageFixtures.png("#{dir}/icon.png", 512, 512))).to eq('image/png')
    expect { described_class.icon!(ImageFixtures.png("#{dir}/big.png", 1024, 1024)) }.to raise_error(config_error, /512×512/)
  end

  it 'refuses a file that is not an image' do
    File.write("#{dir}/icon.png", 'text')
    expect { described_class.icon!("#{dir}/icon.png") }.to raise_error(config_error, /PNG или JPEG/)
  end

  it 'refuses a screenshot side outside 320..3840' do
    expect { described_class.screenshot!(ImageFixtures.png("#{dir}/s.png", 200, 400)) }.to raise_error(config_error, /320 до 3840/)
  end

  it 'detects the orientation and refuses a mix' do
    portrait = ImageFixtures.png("#{dir}/p.png", 1080, 1920)
    landscape = ImageFixtures.png("#{dir}/l.png", 1920, 1080)

    expect(described_class.orientation!([portrait])).to eq('PORTRAIT')
    expect(described_class.orientation!([landscape])).to eq('LANDSCAPE')
    expect { described_class.orientation!([portrait, landscape]) }.to raise_error(config_error, /разной ориентации/)
  end
end

describe Fastlane::Helper::UploadToRuStoreHelper do
  let(:base) { SpecHelper::BASE_URL }
  let(:pkg) { 'com.example.app' }
  let(:dir) { Dir.mktmpdir }
  let(:api) do
    Fastlane::Helper::Rustore::Api.new(client: Fastlane::Helper::Rustore::Client.new).tap { |a| a.client.token = 'jwe' }
  end
  let(:shots_url) { "#{base}/public/v2/application/#{pkg}/version/7/image/screenshot" }

  after { FileUtils.rm_rf(dir) }

  it 'uploads the icon and replaces phone screenshots in order' do
    icon = ImageFixtures.png("#{dir}/icon.png", 512, 512)
    shots = (1..3).map { |i| ImageFixtures.png("#{dir}/#{i}.png", 1080, 1920) }
    icon_stub = stub_request(:post, "#{base}/public/v1/application/#{pkg}/version/7/image/icon").to_return(SpecHelper.json(code: 'OK'))
    stub_request(:get, shots_url).with(query: hash_including({}))
                                 .to_return(SpecHelper.json(body: { content: [{ id: 50, type: 'SCREENSHOT' },
                                                                              { id: 51, type: 'TV_SCREENSHOT' }] }))
    old = stub_request(:delete, "#{shots_url}/50").to_return(SpecHelper.json(code: 'OK'))
    kept = stub_request(:delete, "#{shots_url}/51")
    uploads = (0..2).map { |i| stub_request(:post, "#{shots_url}/PORTRAIT/#{i}/SCREENSHOT").to_return(SpecHelper.json(body: { id: i })) }

    described_class.upload_images(api: api, package_name: pkg, version_id: 7, icon: icon, screenshots: { 'SCREENSHOT' => shots })

    expect(icon_stub).to have_been_requested
    expect(old).to have_been_requested
    expect(kept).not_to have_been_requested
    uploads.each { |stub| expect(stub).to have_been_requested }
  end

  it 'refuses more than 10 screenshots of one type' do
    shots = (1..11).map { |i| ImageFixtures.png("#{dir}/#{i}.png", 1080, 1920) }

    expect { described_class.upload_images(api: api, package_name: pkg, version_id: 7, screenshots: { 'SCREENSHOT' => shots }) }
      .to raise_error(FastlaneCore::Interface::FastlaneError, /не больше 10/)
  end
end

require 'spec_helper'

describe Fastlane::Helper::Rustore::Signer do
  let(:key) { SpecHelper.rsa_key }
  let(:config_error) { Fastlane::Helper::Rustore::ConfigurationError }

  it 'accepts a PEM key and produces a verifiable signature' do
    signer = described_class.new(key_id: 'kid', private_key: key.to_pem)
    timestamp = '2026-01-01T00:00:00.000+03:00'

    signature = Base64.strict_decode64(signer.sign(timestamp))

    expect(key.public_key.verify(OpenSSL::Digest.new('SHA512'), signature, "kid#{timestamp}")).to be(true)
  end

  it 'accepts bare Base64 of a PKCS#8 key' do
    signer = described_class.new(key_id: 'kid', private_key: Base64.strict_encode64(key.private_to_der))
    expect(signer.sign('ts')).to be_a(String)
  end

  it 'accepts bare Base64 of a PKCS#1 key' do
    signer = described_class.new(key_id: 'kid', private_key: Base64.strict_encode64(key.to_der))
    expect(signer.sign('ts')).to be_a(String)
  end

  it 'rejects an empty key id' do
    expect { described_class.new(key_id: '  ', private_key: key.to_pem) }
      .to raise_error(config_error, /key_id/)
  end

  it 'rejects an empty key' do
    expect { described_class.new(key_id: 'kid', private_key: '') }
      .to raise_error(config_error, /private_key пустой/)
  end

  it 'rejects garbage that is not Base64' do
    expect { described_class.new(key_id: 'kid', private_key: 'не ключ') }
      .to raise_error(config_error, /Base64/)
  end
end

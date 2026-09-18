require 'spec_helper'

describe Fastlane::Actions::UploadToRuStoreAction do
  let(:helper) { Fastlane::Helper::UploadToRuStoreHelper }
  let(:fastlane_error) { FastlaneCore::Interface::FastlaneError }
  let(:aab) { File.join(Dir.tmpdir, 'spec-release.aab') }
  let(:base_params) do
    {
      package_name: 'com.example.app',
      key_id: 'kid',
      private_key: 'pem',
      aab: aab,
      remove_existing_drafts: true,
      submit_for_moderation: true
    }
  end

  before do
    File.write(aab, 'binary')
    allow(helper).to receive(:fetch_token).and_return('jwe')
    allow(helper).to receive(:remove_drafts)
    allow(helper).to receive(:create_draft).and_return(11)
    allow(helper).to receive(:upload_build)
    allow(helper).to receive(:commit_draft)
    allow(helper).to receive(:latest_version).and_return({ 'versionId' => 11 })
  end

  after { FileUtils.rm_f(aab) }

  def configured(overrides = {})
    FastlaneCore::Configuration.create(
      described_class.available_options,
      base_params.except(:remove_existing_drafts, :submit_for_moderation).merge(overrides)
    )
  end

  it 'forwards publish_datetime to create_draft' do
    described_class.run(base_params.merge(publish_type: 'DELAYED', publish_datetime: '2026-06-01T12:00:00+03:00'))

    expect(helper).to have_received(:create_draft).with(
      hash_including(publish_type: 'DELAYED', publish_datetime: '2026-06-01T12:00:00+03:00')
    )
  end

  it 'forwards staged rollout and store metadata' do
    described_class.run(base_params.merge(partial_value: 25, app_name: 'Example', short_description: 'Short'))

    expect(helper).to have_received(:create_draft).with(
      hash_including(partial_value: 25, app_name: 'Example', short_description: 'Short')
    )
  end

  it 'uploads the aab and submits the draft' do
    described_class.run(base_params)

    expect(helper).to have_received(:upload_build).with(hash_including(build_type: 'aab', file_path: aab))
    expect(helper).to have_received(:commit_draft).with(hash_including(draft_id: 11))
  end

  it 'uploads GMS and HMS apks when no aab is given' do
    described_class.run(base_params.merge(aab: nil, gms_apk: 'gms.apk', hms_apk: 'hms.apk'))

    expect(helper).to have_received(:upload_build).with(hash_including(service_type: 'GMS'))
    expect(helper).to have_received(:upload_build).with(hash_including(service_type: 'HMS'))
  end

  it 'keeps existing drafts when asked to' do
    described_class.run(base_params.merge(remove_existing_drafts: false))

    expect(helper).not_to have_received(:remove_drafts)
  end

  it 'can stop before moderation' do
    described_class.run(base_params.merge(submit_for_moderation: false))

    expect(helper).not_to have_received(:commit_draft)
  end

  it 'exposes the draft id through the lane context' do
    described_class.run(base_params)

    expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RUSTORE_VERSION_ID]).to eq(11)
  end

  it 'requires either aab or gms_apk' do
    expect { described_class.run(base_params.merge(aab: nil)) }
      .to raise_error(fastlane_error, /aab или gms_apk/)
  end

  it 'is android only' do
    expect(described_class.is_supported?(:android)).to be(true)
    expect(described_class.is_supported?(:ios)).to be(false)
  end

  describe 'configuration' do
    it 'defaults to removing drafts and submitting for moderation' do
      config = configured
      expect(config[:remove_existing_drafts]).to be(true)
      expect(config[:submit_for_moderation]).to be(true)
    end

    it 'marks credentials as sensitive' do
      sensitive = described_class.available_options.select(&:sensitive).map(&:key)
      expect(sensitive).to include(:key_id, :private_key)
    end

    it 'rejects an unknown publish_type' do
      expect { configured(publish_type: 'WHENEVER') }.to raise_error(fastlane_error, /publish_type/)
    end

    it 'rejects a rollout percentage outside the allowed set' do
      expect { configured(partial_value: 33) }.to raise_error(fastlane_error, /partial_value/)
    end

    it 'rejects a malformed publish_datetime' do
      expect { configured(publish_datetime: 'tomorrow') }.to raise_error(fastlane_error, /ISO8601/)
    end

    it 'rejects a missing build file' do
      expect { configured(aab: '/nope/missing.aab') }.to raise_error(fastlane_error, /не найден/)
    end
  end
end

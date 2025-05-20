require 'spec_helper'

describe Fastlane::Actions::UploadToRuStoreAction do
  describe '#run' do
    it 'prints a success message after upload' do
      expect(Fastlane::UI).to receive(:message).at_least(:once)

      Fastlane::Actions::UploadToRuStoreAction.run(
        package_name: 'com.example.app',
        key_id: 'KEY_ID',
        private_key: 'PRIVATE_KEY',
        aab: 'dummy.aab'
      )
    end
  end
end

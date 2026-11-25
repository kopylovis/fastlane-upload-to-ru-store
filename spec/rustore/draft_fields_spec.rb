require 'spec_helper'

describe Fastlane::Helper::Rustore::DraftFields do
  let(:config_error) { Fastlane::Helper::Rustore::ConfigurationError }

  it 'maps the newer documented fields onto their API names' do
    payload = described_class.payload(
      categories: %w[health news],
      seo_tag_ids: %w[100 102],
      faq: [{ question: 'Сколько идет модерация?', answer: 'До трех дней' }],
      developer_contacts: { email: 'dev@example.com', vk_community: 'https://vk.com/example' },
      video: { orientation: 'landscape', url: 'https://vkvideo.ru/video-1_2' },
      package_sdk: { ads_sdks: ['com.example.ads'], payment_sdks: [] },
      in_app_purchase_types: %w[PRODUCTS],
      whats_new_tv: 'Для ТВ'
    )

    expect(payload).to eq(
      categories: %w[health news],
      seoTagIds: [100, 102],
      faq: [{ question: 'Сколько идет модерация?', answer: 'До трех дней' }],
      developerContacts: { email: 'dev@example.com', vkCommunity: 'https://vk.com/example' },
      video: { orientation: 'LANDSCAPE', url: 'https://vkvideo.ru/video-1_2' },
      packageSdkDto: { adsSdks: ['com.example.ads'], paymentSdks: [] },
      inAppPurchaseTypes: %w[PRODUCTS],
      whatsNewTv: 'Для ТВ'
    )
  end

  it 'allows at most two unique categories' do
    expect { described_class.payload(categories: %w[a b c]) }.to raise_error(config_error, /не больше 2/)
    expect { described_class.payload(categories: %w[a a]) }.to raise_error(config_error, /уникальными/)
  end

  it 'limits faq answers to 500 characters' do
    expect { described_class.payload(faq: [{ question: 'q', answer: 'x' * 501 }]) }
      .to raise_error(config_error, /faq answer длиннее 500/)
  end

  it 'refuses unknown contact keys' do
    expect { described_class.payload(developer_contacts: { telegram: '@me' }) }.to raise_error(config_error, /telegram/)
  end

  it 'refuses an unknown purchase type' do
    expect { described_class.payload(in_app_purchase_types: %w[ADS]) }.to raise_error(config_error, /in_app_purchase_types/)
  end

  it 'refuses an empty TV description' do
    expect { described_class.payload(short_description_tv: ' ') }.to raise_error(config_error, /пустым/)
  end
end

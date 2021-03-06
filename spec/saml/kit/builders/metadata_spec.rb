# frozen_string_literal: true

RSpec.describe Saml::Kit::Builders::Metadata do
  describe '.build' do
    subject { Saml::Kit::Metadata }

    let(:url) { FFaker::Internet.uri('https') }

    it 'builds metadata for a service provider' do
      result = subject.build do |builder|
        builder.build_service_provider do |x|
          x.add_assertion_consumer_service(url, binding: :http_post)
        end
      end

      hash_result = Hash.from_xml(result.to_xml)
      expect(hash_result['EntityDescriptor']).to be_present
      expect(hash_result['EntityDescriptor']['SPSSODescriptor']).to be_present
      expect(hash_result['EntityDescriptor']['SPSSODescriptor']['AssertionConsumerService']).to be_present
      expect(hash_result['EntityDescriptor']['SPSSODescriptor']['AssertionConsumerService']['Location']).to eql(url)
    end

    it 'builds metadata for an identity provider' do
      result = subject.build do |builder|
        builder.build_identity_provider do |x|
          x.add_single_sign_on_service(url, binding: :http_post)
        end
      end

      hash_result = Hash.from_xml(result.to_xml)
      expect(hash_result['EntityDescriptor']).to be_present
      expect(hash_result['EntityDescriptor']['IDPSSODescriptor']).to be_present
      expect(hash_result['EntityDescriptor']['IDPSSODescriptor']['SingleSignOnService']).to be_present
      expect(hash_result['EntityDescriptor']['IDPSSODescriptor']['SingleSignOnService']['Location']).to eql(url)
    end

    it 'builds metadata for both IDP and SP' do
      result = subject.build do |builder|
        builder.build_service_provider do |x|
          x.add_assertion_consumer_service(url, binding: :http_post)
        end
        builder.build_identity_provider do |x|
          x.add_single_sign_on_service(url, binding: :http_post)
        end
      end

      hash_result = Hash.from_xml(result.to_xml)
      expect(hash_result['EntityDescriptor']).to be_present
      expect(hash_result['EntityDescriptor']['IDPSSODescriptor']).to be_present
      expect(hash_result['EntityDescriptor']['SPSSODescriptor']).to be_present

      expect(hash_result['EntityDescriptor']['IDPSSODescriptor']['SingleSignOnService']).to be_present
      expect(hash_result['EntityDescriptor']['IDPSSODescriptor']['SingleSignOnService']['Location']).to eql(url)
      expect(hash_result['EntityDescriptor']['SPSSODescriptor']['AssertionConsumerService']).to be_present
      expect(hash_result['EntityDescriptor']['SPSSODescriptor']['AssertionConsumerService']['Location']).to eql(url)
    end

    it 'generates signed idp and sp metadata' do
      configuration = Saml::Kit::Configuration.new do |config|
        3.times { config.generate_key_pair_for(use: :signing) }
      end
      metadata = Saml::Kit::Metadata.build(configuration: configuration) do |builder|
        builder.entity_id = FFaker::Internet.uri('https')
        builder.build_identity_provider do |x|
          x.embed_signature = true
          x.add_single_sign_on_service(url, binding: :http_post)
        end
        builder.build_service_provider do |x|
          x.embed_signature = true
          x.add_assertion_consumer_service(url, binding: :http_post)
        end
      end
      expect(metadata).to be_present
      expect(metadata).to be_valid
    end
  end

  specify do
    configuration = Saml::Kit::Configuration.new do |config|
      config.entity_id = 'https://www.example.org/metadata'
      config.generate_key_pair_for(use: :signing)
      config.generate_key_pair_for(use: :encryption)
    end
    metadata = Saml::Kit::Metadata.build(configuration: configuration) do |x|
      x.organization_name = 'Acme'
      x.contact_email = 'acme@example.org'
      x.organization_url = 'https://www.example.org'
      x.build_service_provider do |xxx|
        xxx.add_assertion_consumer_service('https://www.example.org/assertions', binding: :http_post)
      end
    end
    expect(metadata.to_xml(pretty: true)).to be_present
  end
end

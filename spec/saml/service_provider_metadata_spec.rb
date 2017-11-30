require 'spec_helper'

RSpec.describe Saml::Kit::ServiceProviderMetadata do
  let(:entity_id) { FFaker::Internet.uri("https") }
  let(:acs_post_url) { FFaker::Internet.uri("https") }
  let(:acs_redirect_url) { FFaker::Internet.uri("https") }
  let(:logout_post_url) { FFaker::Internet.uri("https") }
  let(:logout_redirect_url) { FFaker::Internet.uri("https") }

  describe described_class do
    let(:builder) { Saml::Kit::Builders::ServiceProviderMetadata.new }
    subject do
      builder.entity_id = entity_id
      builder.add_assertion_consumer_service(acs_post_url, binding: :http_post)
      builder.add_assertion_consumer_service(acs_redirect_url, binding: :http_redirect)
      builder.add_single_logout_service(logout_post_url, binding: :http_post)
      builder.add_single_logout_service(logout_redirect_url, binding: :http_redirect)
      builder.build
    end

    it 'returns each of the certificates' do
      expect(subject.certificates).to match_array([
        Saml::Kit::Certificate.new(Saml::Kit.configuration.stripped_signing_certificate, use: :signing),
        Saml::Kit::Certificate.new(Saml::Kit.configuration.stripped_encryption_certificate, use: :encryption),
      ])
    end

    it 'returns each acs url and binding' do
      expect(subject.assertion_consumer_services.map(&:to_h)).to match_array([
        { location: acs_post_url, binding: Saml::Kit::Bindings::HTTP_POST },
        { location: acs_redirect_url, binding: Saml::Kit::Bindings::HTTP_REDIRECT },
      ])
    end

    it 'returns each logout url and binding' do
      expect(subject.single_logout_services.map(&:to_h)).to match_array([
        { location: logout_post_url, binding: Saml::Kit::Bindings::HTTP_POST },
        { location: logout_redirect_url, binding: Saml::Kit::Bindings::HTTP_REDIRECT },
      ])
    end

    it 'returns each of the nameid formats' do
      expect(subject.name_id_formats).to match_array([
        Saml::Kit::Namespaces::PERSISTENT
      ])
    end

    it 'returns the entity id' do
      expect(subject.entity_id).to eql(entity_id)
    end
  end

  describe "#validate" do
    let(:service_provider_metadata) do
      builder = Saml::Kit::Builders::ServiceProviderMetadata.new
      builder.entity_id = entity_id
      builder.add_assertion_consumer_service(acs_post_url, binding: :http_post)
      builder.add_assertion_consumer_service(acs_redirect_url, binding: :http_redirect)
      builder.add_single_logout_service(logout_post_url, binding: :http_post)
      builder.add_single_logout_service(logout_redirect_url, binding: :http_redirect)
      builder.to_xml
    end

    it 'valid when given valid service provider metadata' do
      expect(described_class.new(service_provider_metadata)).to be_valid
    end

    it 'is invalid, when given identity provider metadata' do
      subject = described_class.new(IO.read("spec/fixtures/metadata/okta.xml"))
      expect(subject).to be_invalid
      expect(subject.errors[:base]).to include(I18n.translate("saml/kit.errors.SPSSODescriptor.invalid"))
    end

    it 'is invalid, when the metadata is nil' do
      subject = described_class.new(nil)
      expect(subject).to be_invalid
      expect(subject.errors[:metadata]).to include("can't be blank")
    end

    it 'is invalid, when the metadata does not validate against the xsd schema' do
      xml = ::Builder::XmlMarkup.new
      xml.instruct!
      xml.EntityDescriptor 'xmlns': Saml::Kit::Namespaces::METADATA do
        xml.SPSSODescriptor do
          xml.Fake foo: :bar
        end
      end
      subject = described_class.new(xml.target!)
      expect(subject).to_not be_valid
      expect(subject.errors[:base][0]).to include("1:0: ERROR: Element '{urn:oasis:names:tc:SAML:2.0:metadata}EntityDescriptor'")
    end

    it 'is invalid, when the signature is invalid' do
      new_url = 'https://myserver.com/hacked'
      metadata_xml = service_provider_metadata.gsub(acs_post_url, new_url)
      subject = described_class.new(metadata_xml)
      expect(subject).to be_invalid
      expect(subject.errors[:base]).to include("invalid signature.")
    end

    it 'is invalid when 0 ACS endpoints are specified' do
      xml = <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<EntityDescriptor xmlns="#{Saml::Kit::Namespaces::METADATA}" ID="_#{SecureRandom.uuid}" entityID="#{entity_id}">
  <SPSSODescriptor AuthnRequestsSigned="false" WantAssertionsSigned="true" protocolSupportEnumeration="#{Saml::Kit::Namespaces::PROTOCOL}">
    <SingleLogoutService Binding="#{Saml::Kit::Bindings::HTTP_POST}" Location="#{FFaker::Internet.uri("https")}"/>
    <NameIDFormat>#{Saml::Kit::Namespaces::PERSISTENT}</NameIDFormat>
  </SPSSODescriptor>
</EntityDescriptor>
      XML
      expect(described_class.new(xml)).to be_invalid
    end
  end

  describe "#matches?" do
    subject { Saml::Kit::Builders::ServiceProviderMetadata.new.build }

    it 'returns true when the fingerprint matches one of the signing certificates' do
      certificate = Hash.from_xml(subject.to_xml)['EntityDescriptor']['Signature']['KeyInfo']['X509Data']['X509Certificate']
      fingerprint = Saml::Kit::Fingerprint.new(certificate)
      expect(subject.matches?(fingerprint)).to be_truthy
    end

    it 'returns false when the fingerprint does not match one of the signing certificates' do
      certificate, _ = Saml::Kit::SelfSignedCertificate.new('password').create
      fingerprint = Saml::Kit::Fingerprint.new(certificate)
      expect(subject.matches?(fingerprint)).to be_falsey
    end
  end

  describe ".build" do
    let(:acs_url) { FFaker::Internet.uri("https") }

    it 'provides a nice API for building metadata' do
      result = described_class.build do |builder|
        builder.entity_id = entity_id
        builder.add_assertion_consumer_service(acs_url, binding: :http_post)
      end

      expect(result).to be_instance_of(Saml::Kit::ServiceProviderMetadata)
      expect(result.entity_id).to eql(entity_id)
      expect(result.assertion_consumer_service_for(binding: :http_post).location).to eql(acs_url)
    end
  end
end

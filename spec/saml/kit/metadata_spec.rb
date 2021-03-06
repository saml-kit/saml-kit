# frozen_string_literal: true

RSpec.describe Saml::Kit::Metadata do
  describe '.from' do
    subject { described_class }

    it 'returns an identity provider metadata' do
      xml = described_class.build_xml(&:build_identity_provider)
      expect(subject.from(xml)).to be_instance_of(Saml::Kit::IdentityProviderMetadata)
    end

    it 'returns a service provider metadata' do
      xml = described_class.build_xml(&:build_service_provider)
      expect(subject.from(xml)).to be_instance_of(Saml::Kit::ServiceProviderMetadata)
    end

    it 'generates a full metadata in a reasonable amount of time' do
      expect do
        described_class.build_xml do |x|
          x.build_identity_provider
          x.build_service_provider
        end
      end.to perform_under(50).ms
    end

    it 'returns a composite' do
      xml = <<-XML.strip_heredoc
        <EntityDescriptor xmlns="#{Saml::Kit::Namespaces::METADATA}" ID="#{Xml::Kit::Id.generate}" entityID="#{FFaker::Internet.uri('https')}">
          <SPSSODescriptor AuthnRequestsSigned="false" WantAssertionsSigned="true" protocolSupportEnumeration="#{Saml::Kit::Namespaces::PROTOCOL}">
            <SingleLogoutService Binding="#{Saml::Kit::Bindings::HTTP_POST}" Location="#{FFaker::Internet.uri('https')}"/>
            <NameIDFormat>#{Saml::Kit::Namespaces::PERSISTENT}</NameIDFormat>
            <AssertionConsumerService Binding="#{Saml::Kit::Bindings::HTTP_POST}" Location="#{FFaker::Internet.uri('https')}" index="0" isDefault="true"/>
          </SPSSODescriptor>
          <IDPSSODescriptor WantAuthnRequestsSigned="true" protocolSupportEnumeration="#{Saml::Kit::Namespaces::PROTOCOL}">
            <SingleLogoutService Binding="#{Saml::Kit::Bindings::HTTP_POST}" Location="#{FFaker::Internet.uri('https')}"/>
            <NameIDFormat>#{Saml::Kit::Namespaces::PERSISTENT}</NameIDFormat>
            <SingleSignOnService Binding="#{Saml::Kit::Bindings::HTTP_POST}" Location="#{FFaker::Internet.uri('https')}"/>
            <SingleSignOnService Binding="#{Saml::Kit::Bindings::HTTP_REDIRECT}" Location="#{FFaker::Internet.uri('https')}"/>
          </IDPSSODescriptor>
          <Organization>
            <OrganizationName xml:lang="en">Acme, Inc</OrganizationName>
            <OrganizationDisplayName xml:lang="en">Acme, Inc</OrganizationDisplayName>
            <OrganizationURL xml:lang="en">http://localhost:5000/</OrganizationURL>
          </Organization>
          <ContactPerson contactType="technical">
            <Company>mailto:hi@example.com</Company>
          </ContactPerson>
        </EntityDescriptor>
      XML
      result = subject.from(xml)
      expect(result).to be_present
      expect(result.single_sign_on_services.count).to eq(2)
      expect(result.assertion_consumer_services.count).to eq(1)
      expect(result.single_logout_services.count).to eq(2)
      expect(result.organization_name).to eql('Acme, Inc')
      expect(result.organization_url).to eql('http://localhost:5000/')
      expect(result.contact_person_company).to eql('mailto:hi@example.com')
    end
  end

  describe '#certificates' do
    it 'returns each certificate when missing a "use"' do
      configuration = Saml::Kit::Configuration.new do |config|
        config.generate_key_pair_for(use: :signing)
      end
      xml = described_class.build_xml(configuration: configuration) do |x|
        x.embed_signature = false
        x.build_identity_provider
      end
      modified_xml = xml.gsub(/use/, 'misuse')
      subject = described_class.from(modified_xml)
      expect(subject.certificates.count).to be(1)
    end
  end

  describe '#signature' do
    it 'returns the signature' do
      subject = described_class.build do |x|
        x.sign_with(::Xml::Kit::KeyPair.generate(use: :signing))
        x.build_identity_provider
      end

      expect(subject.signature).to be_present
    end
  end

  describe 'validations' do
    it 'is invalid, when the digest value is invalid' do
      xml = described_class.build_xml do |x|
        x.entity_id = 'original'
        x.sign_with(::Xml::Kit::KeyPair.generate(use: :signing))
        x.build_identity_provider do |y|
          y.add_single_sign_on_service(FFaker::Internet.uri('https'), binding: :http_post)
        end
      end

      subject = described_class.from(xml.gsub('original', 'altered'))
      expect(subject).not_to be_valid
      expect(subject.errors[:digest_value]).to include('is invalid.')
    end

    it 'is invalid when the signature is invalid' do
      xml = described_class.build_xml do |x|
        x.sign_with(::Xml::Kit::KeyPair.generate(use: :signing))
        x.build_identity_provider do |y|
          y.add_single_sign_on_service(FFaker::Internet.uri('https'), binding: :http_post)
        end
      end
      document = Nokogiri::XML(xml)
      node = document.at_xpath('/*/ds:Signature/ds:SignatureValue', ds: Xml::Kit::Namespaces::XMLDSIG)
      node.content = Base64.encode64('invalid')

      subject = described_class.from(document.to_s)
      expect(subject).not_to be_valid
      expect(subject.errors[:signature]).to include('is invalid.')
    end
  end
end

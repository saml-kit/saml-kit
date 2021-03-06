# frozen_string_literal: true

RSpec.describe Saml::Kit::Assertion do
  subject do
    described_class.build(user, request) do |x|
      x.issuer = entity_id
    end
  end

  let(:request) { instance_double(Saml::Kit::AuthenticationRequest, id: ::Xml::Kit::Id.generate, issuer: FFaker::Internet.uri('https'), assertion_consumer_service_url: FFaker::Internet.uri('https'), name_id_format: Saml::Kit::Namespaces::PERSISTENT, provider: nil, signed?: true, trusted?: true) }
  let(:user) { User.new(name_id: SecureRandom.uuid, attributes: { id: SecureRandom.uuid }) }
  let(:entity_id) { FFaker::Internet.uri('https') }

  specify { expect(subject.issuer).to eql(entity_id) }
  specify { expect(subject.name_id).to eql(user.name_id) }
  specify { expect(subject.name_id_format).to eql(Saml::Kit::Namespaces::PERSISTENT) }
  specify { expect(subject.started_at.to_i).to eql(Time.now.utc.to_i) }
  specify { expect(subject.expired_at.to_i).to eql(Saml::Kit.configuration.session_timeout.since(Time.now).utc.to_i) }
  specify { expect(subject.attributes).to eql('id' => user.attributes[:id]) }
  specify { expect(subject.audiences).to match_array([request.issuer]) }

  describe '#active?' do
    let(:configuration) do
      Saml::Kit::Configuration.new do |config|
        config.session_timeout = 30.minutes
        config.clock_drift = 30.seconds
      end
    end

    it 'is valid after a valid session window + drift' do
      now = Time.current
      travel_to now
      not_on_or_after = configuration.session_timeout.since(now).iso8601
      xml = <<-XML.strip_heredoc
      <Response xmlns="#{Saml::Kit::Namespaces::PROTOCOL}">
        <Assertion xmlns="#{Saml::Kit::Namespaces::ASSERTION}" ID="#{Xml::Kit::Id.generate}" IssueInstant="#{now.iso8601}" Version="2.0">
         <Issuer>#{FFaker::Internet.uri('https')}</Issuer>
         <Subject>
           <NameID Format="#{Saml::Kit::Namespaces::PERSISTENT}">#{SecureRandom.uuid}</NameID>
           <SubjectConfirmation Method="#{Saml::Kit::Namespaces::BEARER}">
             <SubjectConfirmationData InResponseTo="#{SecureRandom.uuid}" NotOnOrAfter="#{not_on_or_after}" Recipient="#{FFaker::Internet.uri('https')}"/>
           </SubjectConfirmation>
         </Subject>
         <Conditions NotBefore="#{now.utc.iso8601}" NotOnOrAfter="#{not_on_or_after}">
           <AudienceRestriction>
             <Audience>#{FFaker::Internet.uri('https')}</Audience>
           </AudienceRestriction>
         </Conditions>
         <AuthnStatement AuthnInstant="#{now.utc.iso8601}" SessionIndex="#{Xml::Kit::Id.generate}" SessionNotOnOrAfter="#{not_on_or_after}">
           <AuthnContext>
             <AuthnContextClassRef>#{Saml::Kit::Namespaces::PASSWORD}</AuthnContextClassRef>
           </AuthnContext>
         </AuthnStatement>
        </Assertion>
      </Response>
      XML
      document = Nokogiri::XML(xml)
      node = document.at_xpath('//saml:Assertion', 'saml' => Saml::Kit::Namespaces::ASSERTION)
      subject = described_class.new(node, configuration: configuration)
      travel_to((configuration.clock_drift - 1.second).before(now))
      expect(subject).to be_active
      expect(subject).not_to be_expired
    end

    it 'interprets integers correctly' do
      configuration.clock_drift = 30
      now = Time.current
      travel_to now
      not_before = now.utc.iso8601
      not_after = configuration.session_timeout.since(now).iso8601
      xml = <<-XML.strip_heredoc
      <Response xmlns="#{Saml::Kit::Namespaces::PROTOCOL}">
        <Assertion xmlns="#{Saml::Kit::Namespaces::ASSERTION}" ID="#{Xml::Kit::Id.generate}" IssueInstant="#{now.iso8601}" Version="2.0">
         <Issuer>#{FFaker::Internet.uri('https')}</Issuer>
         <Subject>
           <NameID Format="#{Saml::Kit::Namespaces::PERSISTENT}">#{SecureRandom.uuid}</NameID>
           <SubjectConfirmation Method="#{Saml::Kit::Namespaces::BEARER}">
             <SubjectConfirmationData InResponseTo="#{SecureRandom.uuid}" NotOnOrAfter="#{not_after}" Recipient="#{FFaker::Internet.uri('https')}"/>
           </SubjectConfirmation>
         </Subject>
         <Conditions NotBefore="#{not_before}" NotOnOrAfter="#{not_after}">
           <AudienceRestriction>
             <Audience>#{FFaker::Internet.uri('https')}</Audience>
           </AudienceRestriction>
         </Conditions>
         <AuthnStatement AuthnInstant="#{now.utc.iso8601}" SessionIndex="#{Xml::Kit::Id.generate}" SessionNotOnOrAfter="#{not_after}">
           <AuthnContext>
             <AuthnContextClassRef>#{Saml::Kit::Namespaces::PASSWORD}</AuthnContextClassRef>
           </AuthnContext>
         </AuthnStatement>
        </Assertion>
      </Response>
      XML
      document = Nokogiri::XML(xml)
      node = document.at_xpath('//saml:Assertion', 'saml' => Saml::Kit::Namespaces::ASSERTION)
      subject = described_class.new(node, configuration: configuration)
      expect(subject).to be_active
      expect(subject).not_to be_expired
    end
  end

  describe '#present?' do
    it 'returns false when the assertion is empty' do
      subject = described_class.new(nil)
      expect(subject).not_to be_present
    end

    it 'returns true when the assertion is present' do
      not_before = Time.now.utc.iso8601
      not_after = 10.minutes.from_now.iso8601
      xml = <<-XML.strip_heredoc
        <Response>
        <Assertion xmlns="#{Saml::Kit::Namespaces::ASSERTION}" ID="#{Xml::Kit::Id.generate}" IssueInstant="#{Time.now.iso8601}" Version="2.0">
         <Issuer>#{FFaker::Internet.uri('https')}</Issuer>
         <Subject>
           <NameID Format="#{Saml::Kit::Namespaces::PERSISTENT}">#{SecureRandom.uuid}</NameID>
           <SubjectConfirmation Method="#{Saml::Kit::Namespaces::BEARER}">
             <SubjectConfirmationData InResponseTo="#{SecureRandom.uuid}" NotOnOrAfter="#{not_after}" Recipient="#{FFaker::Internet.uri('https')}"/>
           </SubjectConfirmation>
         </Subject>
         <Conditions NotBefore="#{not_before}" NotOnOrAfter="#{not_after}">
           <AudienceRestriction>
             <Audience>#{FFaker::Internet.uri('https')}</Audience>
           </AudienceRestriction>
         </Conditions>
         <AuthnStatement AuthnInstant="#{Time.now.utc.iso8601}" SessionIndex="#{Xml::Kit::Id.generate}" SessionNotOnOrAfter="#{not_after}">
           <AuthnContext>
             <AuthnContextClassRef>#{Saml::Kit::Namespaces::PASSWORD}</AuthnContextClassRef>
           </AuthnContext>
         </AuthnStatement>
        </Assertion>
        </Response>
      XML
      subject = described_class.new(Nokogiri::XML(xml))
      expect(subject).to be_present
    end
  end

  describe '#signed?' do
    let(:request) { instance_double(Saml::Kit::AuthenticationRequest, id: ::Xml::Kit::Id.generate, issuer: FFaker::Internet.http_url, assertion_consumer_service_url: FFaker::Internet.http_url, name_id_format: Saml::Kit::Namespaces::PERSISTENT, provider: nil, signed?: true, trusted?: true) }
    let(:user) { User.new(attributes: { id: SecureRandom.uuid }) }

    it 'detects a signature in an encrypted assertion' do
      encryption_key_pair = Xml::Kit::KeyPair.generate(use: :encryption)
      response = Saml::Kit::Response.build(user, request) do |x|
        x.sign_with(Xml::Kit::KeyPair.generate(use: :signing))
        x.encrypt_with(encryption_key_pair)
      end
      assertion = response.assertion([encryption_key_pair.private_key])
      expect(response).to be_signed
      expect(assertion).to be_signed
    end
  end

  describe '#encrypted?' do
    it 'returns true when encrypted' do
      key_pair = Xml::Kit::KeyPair.generate(use: :encryption)
      response = Saml::Kit::Response.build(user, request) do |x|
        x.encrypt_with(key_pair)
      end
      subject = response.assertion([key_pair.private_key])
      expect(subject).to be_encrypted
    end

    it 'returns false when not encrypted' do
      expect(subject).not_to be_encrypted
    end
  end

  describe '#to_xml' do
    let(:request) { instance_double(Saml::Kit::AuthenticationRequest, id: ::Xml::Kit::Id.generate, issuer: FFaker::Internet.http_url, assertion_consumer_service_url: FFaker::Internet.http_url, name_id_format: Saml::Kit::Namespaces::PERSISTENT, provider: nil, signed?: true, trusted?: true) }
    let(:user) { User.new(attributes: { id: SecureRandom.uuid }) }

    it 'returns the decrypted xml' do
      encryption_key_pair = Xml::Kit::KeyPair.generate(use: :encryption)
      response = Saml::Kit::Response.build(user, request) do |x|
        x.sign_with(Xml::Kit::KeyPair.generate(use: :signing))
        x.encrypt_with(encryption_key_pair)
      end
      assertion = response.assertion([encryption_key_pair.private_key])
      expect(assertion.to_xml).not_to include('EncryptedAssertion')
      expect(assertion.to_xml).to include('Assertion')
    end
  end

  describe '#valid?' do
    let(:entity_id) { FFaker::Internet.uri('https') }
    let(:request) { instance_double(Saml::Kit::AuthenticationRequest, id: ::Xml::Kit::Id.generate, issuer: entity_id, assertion_consumer_service_url: FFaker::Internet.http_url, name_id_format: Saml::Kit::Namespaces::PERSISTENT, provider: nil, signed?: true, trusted?: true) }
    let(:name_id) { SecureRandom.uuid }
    let(:user) { User.new(name_id: name_id, attributes: { id: SecureRandom.uuid }) }
    let(:registry) { instance_double(Saml::Kit::DefaultRegistry, metadata_for: idp) }
    let(:idp) { Saml::Kit::IdentityProviderMetadata.build(configuration: configuration) }
    let(:configuration) do
      Saml::Kit::Configuration.new do |x|
        x.entity_id = entity_id
        x.generate_key_pair_for(use: :signing)
      end
    end

    before do
      allow(configuration.registry).to receive(:metadata_for).with(entity_id).and_return(idp)
    end

    it 'is invalid when the encrypted signature is invalid' do
      xml = Saml::Kit::Response.build_xml(user, request, configuration: configuration)
      altered = xml.gsub(name_id, 'altered')
      document = Nokogiri::XML(altered)
      assertion = document.at_xpath('/samlp:Response/saml:Assertion', Saml::Kit::Document::NAMESPACES)
      key_pair = Xml::Kit::KeyPair.generate(use: :encryption)
      encrypted = Xml::Kit::EncryptedData.new(assertion.to_xml, asymmetric_cipher: Xml::Kit::Crypto::RsaCipher.new('', key_pair.private_key)).to_xml
      response = Saml::Kit::Response.new(encrypted, configuration: configuration)
      expect(response.assertion([key_pair.private_key])).to be_invalid
    end

    it 'is valid when the encrypted signature is valid' do
      key_pair = Xml::Kit::KeyPair.generate(use: :encryption)
      response = Saml::Kit::Response.build(user, request, configuration: configuration) do |x|
        x.encrypt_with(key_pair)
      end
      expect(response.assertion([key_pair.private_key])).to be_valid
    end

    it 'is invalid when the assertion signature is invalid' do
      xml = Saml::Kit::Response.build_xml(user, request, configuration: configuration)
      altered = xml.gsub(name_id, 'altered')
      response = Saml::Kit::Response.new(altered, configuration: configuration)
      expect(response.assertion).to be_invalid
      expect(response.assertion.errors[:digest_value]).to match_array(['is invalid.'])
    end

    it 'is invalid when the response signature is invalid' do
      xml = Saml::Kit::Response.build_xml(user, request, configuration: configuration)
      altered = xml.gsub('StatusCode', 'ALTERED')
      response = Saml::Kit::Response.new(altered, configuration: configuration)
      expect(response).to be_invalid
    end

    it 'is valid' do
      response = Saml::Kit::Response.build(user, request, configuration: configuration)
      expect(response.assertion).to be_valid
    end
  end

  describe '.new' do
    let(:user) { instance_double(User, name_id_for: SecureRandom.uuid, assertion_attributes_for: {}) }
    let(:saml_request) { instance_double(Saml::Kit::AuthenticationRequest, id: Xml::Kit::Id.generate, issuer: configuration.entity_id) }
    let(:registry) { instance_double(Saml::Kit::DefaultRegistry) }
    let(:configuration) do
      Saml::Kit::Configuration.new do |x|
        x.entity_id = FFaker::Internet.uri('https')
        x.registry = registry
        x.generate_key_pair_for(use: :signing)
      end
    end
    let(:metadata) do
      Saml::Kit::Metadata.build(configuration: configuration, &:build_identity_provider)
    end

    before { allow(registry).to receive(:metadata_for).with(configuration.entity_id).and_return(metadata) }

    it 'parses a raw xml assertion' do
      saml = described_class.build_xml(user, saml_request, configuration: configuration)
      expect(described_class.new(saml, configuration: configuration)).to be_valid
    end
  end
end

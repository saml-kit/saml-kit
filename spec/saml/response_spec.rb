require 'spec_helper'

RSpec.describe Saml::Kit::Response do
  describe "#destination" do
    let(:acs_url) { "https://#{FFaker::Internet.domain_name}/acs" }
    let(:user) { double(:user, name_id_for: SecureRandom.uuid, assertion_attributes_for: { }) }
    let(:request) { instance_double(Saml::Kit::AuthenticationRequest, id: SecureRandom.uuid, acs_url: acs_url, issuer: FFaker::Movie.title, name_id_format: Saml::Kit::Namespaces::EMAIL_ADDRESS, provider: nil) }
    subject { described_class::Builder.new(user, request).build }

    it 'returns the acs_url' do
      expect(subject.destination).to eql(acs_url)
    end
  end

  describe "#to_xml" do
    subject { described_class::Builder.new(user, request) }
    let(:user) { double(:user, name_id_for: SecureRandom.uuid, assertion_attributes_for: { email: email, created_at: Time.now.utc.iso8601 }) }
    let(:request) { double(id: SecureRandom.uuid, acs_url: acs_url, issuer: FFaker::Movie.title, name_id_format: Saml::Kit::Namespaces::EMAIL_ADDRESS, provider: nil) }
    let(:acs_url) { "https://#{FFaker::Internet.domain_name}/acs" }
    let(:issuer) { FFaker::Movie.title }
    let(:email) { FFaker::Internet.email }

    it 'returns a proper response for the user' do
      travel_to 1.second.from_now
      allow(Saml::Kit.configuration).to receive(:issuer).and_return(issuer)
      hash = Hash.from_xml(subject.to_xml)

      expect(hash['Response']['ID']).to be_present
      expect(hash['Response']['Version']).to eql('2.0')
      expect(hash['Response']['IssueInstant']).to eql(Time.now.utc.iso8601)
      expect(hash['Response']['Destination']).to eql(acs_url)
      expect(hash['Response']['InResponseTo']).to eql(request.id)
      expect(hash['Response']['Issuer']).to eql(issuer)
      expect(hash['Response']['Status']['StatusCode']['Value']).to eql("urn:oasis:names:tc:SAML:2.0:status:Success")

      expect(hash['Response']['Assertion']['ID']).to be_present
      expect(hash['Response']['Assertion']['IssueInstant']).to eql(Time.now.utc.iso8601)
      expect(hash['Response']['Assertion']['Version']).to eql("2.0")
      expect(hash['Response']['Assertion']['Issuer']).to eql(issuer)

      expect(hash['Response']['Assertion']['Subject']['NameID']).to eql(user.name_id_for)
      expect(hash['Response']['Assertion']['Subject']['SubjectConfirmation']['Method']).to eql("urn:oasis:names:tc:SAML:2.0:cm:bearer")
      expect(hash['Response']['Assertion']['Subject']['SubjectConfirmation']['SubjectConfirmationData']['NotOnOrAfter']).to eql(3.hours.from_now.utc.iso8601)
      expect(hash['Response']['Assertion']['Subject']['SubjectConfirmation']['SubjectConfirmationData']['Recipient']).to eql(acs_url)
      expect(hash['Response']['Assertion']['Subject']['SubjectConfirmation']['SubjectConfirmationData']['InResponseTo']).to eql(request.id)

      expect(hash['Response']['Assertion']['Conditions']['NotBefore']).to eql(0.seconds.ago.utc.iso8601)
      expect(hash['Response']['Assertion']['Conditions']['NotOnOrAfter']).to eql(3.hours.from_now.utc.iso8601)
      expect(hash['Response']['Assertion']['Conditions']['AudienceRestriction']['Audience']).to eql(request.issuer)

      expect(hash['Response']['Assertion']['AuthnStatement']['AuthnInstant']).to eql(Time.now.utc.iso8601)
      expect(hash['Response']['Assertion']['AuthnStatement']['SessionNotOnOrAfter']).to eql(3.hours.from_now.utc.iso8601)
      expect(hash['Response']['Assertion']['AuthnStatement']['SessionIndex']).to eql(hash['Response']['Assertion']['ID'])
      expect(hash['Response']['Assertion']['AuthnStatement']['AuthnContext']['AuthnContextClassRef']).to eql('urn:oasis:names:tc:SAML:2.0:ac:classes:Password')

      expect(hash['Response']['Assertion']['AttributeStatement']['Attribute'][0]['Name']).to eql('email')
      expect(hash['Response']['Assertion']['AttributeStatement']['Attribute'][0]['FriendlyName']).to eql('email')
      expect(hash['Response']['Assertion']['AttributeStatement']['Attribute'][0]['NameFormat']).to eql('urn:oasis:names:tc:SAML:2.0:attrname-format:uri')
      expect(hash['Response']['Assertion']['AttributeStatement']['Attribute'][0]['AttributeValue']).to eql(email)

      expect(hash['Response']['Assertion']['AttributeStatement']['Attribute'][1]['Name']).to eql('created_at')
      expect(hash['Response']['Assertion']['AttributeStatement']['Attribute'][1]['FriendlyName']).to eql('created_at')
      expect(hash['Response']['Assertion']['AttributeStatement']['Attribute'][1]['NameFormat']).to eql('urn:oasis:names:tc:SAML:2.0:attrname-format:uri')
      expect(hash['Response']['Assertion']['AttributeStatement']['Attribute'][1]['AttributeValue']).to be_present
    end

    it 'does not add a signature when the SP does not want assertions signed' do
      builder = Saml::Kit::ServiceProviderMetadata::Builder.new
      builder.want_assertions_signed = false
      metadata = builder.build
      allow(request).to receive(:provider).and_return(metadata)

      hash = Hash.from_xml(subject.to_xml)
      expect(hash['Response']['Signature']).to be_nil
    end
  end

  describe ".deserialize" do
    subject { described_class }
    let(:raw_response) { IO.read('spec/fixtures/encoded_response.txt') }

    it 'decodes the response to the raw xml' do
      result = Hash.from_xml(subject.deserialize(raw_response).to_xml)
      expect(result['Response']['ID']).to eql('_75358cd9-f357-4b2d-999f-f53382ba8263')
      expect(result['Response']['Version']).to eql('2.0')
      expect(result['Response']['IssueInstant']).to eql("2017-10-22T23:36:44Z")
      expect(result['Response']['Destination']).to eql('http://localhost:4000/session')
      expect(result['Response']['Issuer']).to eql('proof.dev')
      expect(result['Response']['Status']['StatusCode']['Value']).to eql('urn:oasis:names:tc:SAML:2.0:status:Success')
      expect(result['Response']['Assertion']['ID']).to eql("_78cacf76-243e-4509-9ace-d1985353b3fe")
      expect(result['Response']['Assertion']['IssueInstant']).to eql("2017-10-22T23:36:44Z")
      expect(result['Response']['Assertion']['Issuer']).to eql("proof.dev")
      expect(result['Response']['Assertion']['Subject']['NameID']).to eql("ea64c235-e18d-4b9a-8672-06ef84dabdec")
      expect(result['Response']['Assertion']['Conditions']['NotBefore']).to eql("2017-10-22T23:36:39Z")
      expect(result['Response']['Assertion']['Conditions']['NotOnOrAfter']).to eql("2017-10-23T02:36:44Z")
      expect(result['Response']['Assertion']['Conditions']['AudienceRestriction']['Audience']).to eql('airport.dev')
      expect(result['Response']['Assertion']['AttributeStatement']['Attribute'][0]['Name']).to eql('id')
      expect(result['Response']['Assertion']['AttributeStatement']['Attribute'][0]['AttributeValue']).to eql("ea64c235-e18d-4b9a-8672-06ef84dabdec")
    end
  end

  describe "#valid?" do
    let(:request) { instance_double(Saml::Kit::AuthenticationRequest, id: "_#{SecureRandom.uuid}", issuer: FFaker::Internet.http_url, acs_url: FFaker::Internet.http_url, name_id_format: Saml::Kit::Namespaces::PERSISTENT, provider: nil) }
    let(:user) { double(:user, name_id_for: SecureRandom.uuid, assertion_attributes_for: { id: SecureRandom.uuid }) }
    let(:builder) { described_class::Builder.new(user, request) }
    let(:registry) { instance_double(Saml::Kit::DefaultRegistry) }
    let(:metadata) { instance_double(Saml::Kit::IdentityProviderMetadata) }

    before :each do
      allow(Saml::Kit.configuration).to receive(:registry).and_return(registry)
      allow(Saml::Kit.configuration).to receive(:issuer).and_return(request.issuer)
    end

    it 'is valid' do
      allow(registry).to receive(:metadata_for).and_return(metadata)
      allow(metadata).to receive(:matches?).and_return(true)
      expect(builder.build).to be_valid
    end

    it 'is invalid when blank' do
      subject = described_class.new("")
      expect(subject).to be_invalid
      expect(subject.errors[:content]).to be_present
    end

    it 'is invalid if the document has been tampered with' do
      allow(registry).to receive(:metadata_for).and_return(metadata)
      allow(metadata).to receive(:matches?).and_return(true)
      status_code = FFaker::Movie.title
      builder.status_code = status_code
      subject = described_class.new(builder.to_xml.gsub(status_code, "TAMPERED"))
      expect(subject).to be_invalid
    end

    it 'is invalid when not a Response' do
      xml = Saml::Kit::IdentityProviderMetadata::Builder.new.to_xml
      subject = described_class.new(xml)
      expect(subject).to be_invalid
      expect(subject.errors[:base]).to be_present
    end

    it 'is invalid when the fingerprint of the certificate does not match the registered fingerprint' do
      allow(registry).to receive(:metadata_for).and_return(metadata)
      allow(metadata).to receive(:matches?).and_return(false)
      subject = described_class.new(builder.to_xml)
      expect(subject).to be_invalid
      expect(subject.errors[:base]).to be_present
    end

    it 'validates the schema of the response' do
      allow(registry).to receive(:metadata_for).and_return(metadata)
      allow(metadata).to receive(:matches?).and_return(true)
      xml = ::Builder::XmlMarkup.new
      id = SecureRandom.uuid
      options = { "xmlns:samlp" => Saml::Kit::Namespaces::PROTOCOL, ID: "_#{id}", }
      signature = Saml::Kit::Signature.new(id)
      xml.tag!("samlp:Response", options) do
        signature.template(xml)
        xml.Fake do
          xml.NotAllowed "Huh?"
        end
      end
      subject = described_class.new(signature.finalize(xml))
      expect(subject).to be_invalid
      expect(subject.errors[:base]).to be_present
    end

    it 'validates the version' do
      allow(registry).to receive(:metadata_for).and_return(metadata)
      allow(metadata).to receive(:matches?).and_return(true)
      builder.version = "1.1"
      subject = described_class.new(builder.to_xml)
      expect(subject).to be_invalid
      expect(subject.errors[:version]).to be_present
    end

    it 'validates the id' do
      allow(registry).to receive(:metadata_for).and_return(metadata)
      allow(metadata).to receive(:matches?).and_return(true)
      builder.id = nil
      subject = described_class.new(builder.to_xml)
      expect(subject).to be_invalid
      expect(subject.errors[:id]).to be_present
    end

    it 'validates the status code' do
      allow(registry).to receive(:metadata_for).and_return(metadata)
      allow(metadata).to receive(:matches?).and_return(true)
      builder.status_code = Saml::Kit::Namespaces::REQUESTER_ERROR
      subject = described_class.new(builder.to_xml)
      expect(subject).to be_invalid
      expect(subject.errors[:status_code]).to be_present
    end

    it 'validates the InResponseTo' do
      allow(registry).to receive(:metadata_for).and_return(metadata)
      allow(metadata).to receive(:matches?).and_return(true)
      subject = described_class.new(builder.to_xml, request_id: SecureRandom.uuid)
      expect(subject).to be_invalid
      expect(subject.errors[:in_response_to]).to be_present
    end

    it 'is invalid after a valid session window' do
      allow(registry).to receive(:metadata_for).and_return(metadata)
      allow(metadata).to receive(:matches?).and_return(true)

      subject = described_class.new(builder.to_xml)
      travel_to Saml::Kit.configuration.session_timeout.from_now + 5.seconds
      expect(subject).to_not be_valid
      expect(subject.errors[:base]).to be_present
    end

    it 'is invalid before the valid session window' do
      allow(registry).to receive(:metadata_for).and_return(metadata)
      allow(metadata).to receive(:matches?).and_return(true)

      subject = described_class.new(builder.to_xml)
      travel_to 5.seconds.ago
      expect(subject).to be_invalid
      expect(subject.errors[:base]).to be_present
    end

    it 'is invalid when the audience does not match the expected issuer' do
      allow(registry).to receive(:metadata_for).and_return(metadata)
      allow(metadata).to receive(:matches?).and_return(true)

      allow(Saml::Kit.configuration).to receive(:issuer).and_return(FFaker::Internet.http_url)
      allow(request).to receive(:issuer).and_return(FFaker::Internet.http_url)
      subject = described_class.new(builder.to_xml)

      expect(subject).to be_invalid
      expect(subject.errors[:audience]).to be_present
    end
  end

  describe "#serialize" do
    let(:user) { double(:user, name_id_for: SecureRandom.uuid, assertion_attributes_for: { }) }
    let(:request) { double(id: SecureRandom.uuid, acs_url: acs_url, issuer: issuer, name_id_format: Saml::Kit::Namespaces::PERSISTENT, provider: nil) }
    let(:acs_url) { FFaker::Internet.http_url }
    let(:issuer) { FFaker::Internet.http_url }

    it 'returns a compressed and base64 encoded document' do
      builder = described_class::Builder.new(user, request)
      xml = builder.to_xml
      subject = described_class.new(xml)

      expected_value = Base64.strict_encode64(Zlib::Deflate.deflate(xml, 9)[2..-5])
      expect(subject.serialize).to eql(expected_value)
    end
  end
end
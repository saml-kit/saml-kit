RSpec.describe Saml::Kit::Builders::Metadata do
  describe ".build" do
    subject { Saml::Kit::Metadata }
    let(:acs_url) { FFaker::Internet.uri("https") }

    it 'builds metadata for a service provider' do
      result = subject.build do |builder|
        builder.build_service_provider do |x|
          x.add_assertion_consumer_service(acs_url, binding: :http_post)
        end
      end

      hash_result = Hash.from_xml(result.to_xml)
      expect(hash_result['EntityDescriptor']).to be_present
      expect(hash_result['EntityDescriptor']['SPSSODescriptor']).to be_present
      expect(hash_result['EntityDescriptor']['SPSSODescriptor']['AssertionConsumerService']).to be_present
      expect(hash_result['EntityDescriptor']['SPSSODescriptor']['AssertionConsumerService']['Location']).to eql(acs_url)
    end
  end
end

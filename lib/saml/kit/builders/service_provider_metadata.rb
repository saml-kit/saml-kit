module Saml
  module Kit
    module Builders
      class ServiceProviderMetadata
        attr_accessor :id, :entity_id, :acs_urls, :logout_urls, :name_id_formats, :sign
        attr_accessor :organization_name, :organization_url, :contact_email
        attr_accessor :want_assertions_signed

        def initialize(configuration = Saml::Kit.configuration)
          @id = Id.generate
          @configuration = configuration
          @entity_id = configuration.issuer
          @acs_urls = []
          @logout_urls = []
          @name_id_formats = [Namespaces::PERSISTENT]
          @sign = true
          @want_assertions_signed = true
        end

        def add_assertion_consumer_service(url, binding: :http_post)
          @acs_urls.push(location: url, binding: Bindings.binding_for(binding))
        end

        def add_single_logout_service(url, binding: :http_post)
          @logout_urls.push(location: url, binding: Bindings.binding_for(binding))
        end

        def to_xml
          Signature.sign(sign: sign) do |xml, signature|
            xml.instruct!
            xml.EntityDescriptor entity_descriptor_options do
              signature.template(id)
              xml.SPSSODescriptor descriptor_options do
                if @configuration.signing_certificate_pem.present?
                  xml.KeyDescriptor use: "signing" do
                    xml.KeyInfo "xmlns": Namespaces::XMLDSIG do
                      xml.X509Data do
                        xml.X509Certificate @configuration.stripped_signing_certificate
                      end
                    end
                  end
                end
                if @configuration.encryption_certificate_pem.present?
                  xml.KeyDescriptor use: "encryption" do
                    xml.KeyInfo "xmlns": Namespaces::XMLDSIG do
                      xml.X509Data do
                        xml.X509Certificate @configuration.stripped_encryption_certificate
                      end
                    end
                  end
                end
                logout_urls.each do |item|
                  xml.SingleLogoutService Binding: item[:binding], Location: item[:location]
                end
                name_id_formats.each do |format|
                  xml.NameIDFormat format
                end
                acs_urls.each_with_index do |item, index|
                  xml.AssertionConsumerService Binding: item[:binding], Location: item[:location], index: index, isDefault: index == 0 ? true : false
                end
              end
              xml.Organization do
                xml.OrganizationName organization_name, 'xml:lang': "en"
                xml.OrganizationDisplayName organization_name, 'xml:lang': "en"
                xml.OrganizationURL organization_url, 'xml:lang': "en"
              end
              xml.ContactPerson contactType: "technical" do
                xml.Company "mailto:#{contact_email}"
              end
            end
          end
        end

        def build
          Saml::Kit::ServiceProviderMetadata.new(to_xml)
        end

        private

        def entity_descriptor_options
          {
            'xmlns': Namespaces::METADATA,
            ID: id,
            entityID: entity_id,
          }
        end

        def descriptor_options
          {
            AuthnRequestsSigned: sign,
            WantAssertionsSigned: want_assertions_signed,
            protocolSupportEnumeration: Namespaces::PROTOCOL,
          }
        end
      end
    end
  end
end

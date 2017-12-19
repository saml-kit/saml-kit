module Saml
  module Kit
    class Signatures # :nodoc:
      # @!visibility private
      attr_reader :configuration

      # @!visibility private
      def initialize(configuration:)
        @configuration = configuration
      end

      # @!visibility private
      def build(reference_id)
        return nil unless configuration.sign?
        Saml::Kit::Builders::XmlSignature.new(reference_id, configuration: configuration)
      end

      # @!visibility private
      def complete(raw_xml)
        return raw_xml unless configuration.sign?
        private_key = configuration.private_keys(use: :signing).last
        Xmldsig::SignedDocument.new(raw_xml).sign(private_key)
      end

      # @!visibility private
      def self.sign(xml: ::Builder::XmlMarkup.new, configuration: Saml::Kit.configuration)
        signatures = Saml::Kit::Signatures.new(configuration: configuration)
        yield xml, XmlSignatureTemplate.new(xml, signatures)
        signatures.complete(xml.target!)
      end

      class XmlSignatureTemplate # :nodoc:
        # @!visibility private
        attr_reader :signatures, :xml

        # @!visibility private
        def initialize(xml, signatures)
          @signatures = signatures
          @xml = xml
        end

        # @!visibility private
        def template(reference_id)
          Template.new(signatures.build(reference_id)).to_xml(xml: xml)
        end
      end
    end
  end
end

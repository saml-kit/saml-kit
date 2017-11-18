module Saml
  module Kit
    class Document
      PROTOCOL_XSD = File.expand_path("./xsd/saml-schema-protocol-2.0.xsd", File.dirname(__FILE__)).freeze
      include XsdValidatable
      include ActiveModel::Validations
      include Trustable
      validates_presence_of :content
      validate :must_match_xsd
      validate :must_be_expected_type
      validate :must_be_valid_version

      attr_reader :content, :name

      def initialize(xml, name:)
        @content = xml
        @name = name
        @xml_hash = Hash.from_xml(xml) || {}
      end

      def id
        to_h.fetch(name, {}).fetch('ID', nil)
      end

      def issuer
        to_h.fetch(name, {}).fetch('Issuer', nil)
      end

      def version
        to_h.fetch(name, {}).fetch('Version', {})
      end

      def destination
        to_h.fetch(name, {}).fetch('Destination', nil)
      end

      def expected_type?
        return false if to_xml.blank?
        to_h[name].present?
      end

      def to_h
        @xml_hash
      end

      def to_xml
        content
      end

      def to_s
        to_xml
      end

      class << self
        def to_saml_document(xml)
          hash = Hash.from_xml(xml)
          if hash['Response'].present?
            Response.new(xml)
          elsif hash['LogoutResponse'].present?
            LogoutResponse.new(xml)
          elsif hash['AuthnRequest'].present?
            AuthenticationRequest.new(xml)
          elsif hash['LogoutRequest'].present?
            LogoutRequest.new(xml)
          end
        rescue => error
          Saml::Kit.logger.error(error)
          InvalidDocument.new(xml)
        end
      end

      private

      def must_match_xsd
        matches_xsd?(PROTOCOL_XSD)
      end

      def must_be_expected_type
        return if to_h.nil?

        errors[:base] << error_message(:invalid) unless expected_type?
      end

      def must_be_valid_version
        return unless expected_type?
        return if "2.0" == version
        errors[:version] << error_message(:invalid_version)
      end
    end
  end
end

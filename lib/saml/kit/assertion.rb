# frozen_string_literal: true

module Saml
  module Kit
    # This class validates the Assertion
    # element nested in a Response element
    # of a SAML document.
    class Assertion
      include ActiveModel::Validations
      include Translatable
      include XmlParseable
      XPATH = [
        '/samlp:Response/saml:Assertion',
        '/samlp:Response/saml:EncryptedAssertion'
      ].join('|')

      validate :must_be_decryptable
      validate :must_match_issuer, if: :decryptable?
      validate :must_be_active_session, if: :decryptable?
      validate :must_have_valid_signature, if: :decryptable?
      attr_reader :name
      attr_accessor :occurred_at

      def initialize(
        node, configuration: Saml::Kit.configuration, private_keys: []
      )
        @name = 'Assertion'
        @node = node
        @configuration = configuration
        @occurred_at = Time.current
        @cannot_decrypt = false
        @encrypted = false
        private_keys = (
          configuration.private_keys(use: :encryption) + private_keys
        ).uniq
        decrypt(::Xml::Kit::Decryption.new(private_keys: private_keys))
      end

      def issuer
        at_xpath('./saml:Issuer').try(:text)
      end

      def name_id
        at_xpath('./saml:Subject/saml:NameID').try(:text)
      end

      def signed?
        signature.present?
      end

      def signature
        @signature ||= Signature.new(at_xpath('./ds:Signature'))
      end

      def expired?(now = occurred_at)
        now > expired_at
      end

      def active?(now = occurred_at)
        drifted_started_at = started_at - configuration.clock_drift.to_i.seconds
        now > drifted_started_at && !expired?(now)
      end

      def attributes
        xpath = './saml:AttributeStatement/saml:Attribute'
        @attributes ||= search(xpath).inject({}) do |memo, item|
          namespaces = Saml::Kit::Document::NAMESPACES
          attribute = item.at_xpath('./saml:AttributeValue', namespaces)
          memo[item.attribute('Name').value] = attribute.try(:text)
          memo
        end.with_indifferent_access
      end

      def started_at
        parse_date(at_xpath('./saml:Conditions/@NotBefore').try(:value))
      end

      def expired_at
        parse_date(at_xpath('./saml:Conditions/@NotOnOrAfter').try(:value))
      end

      def audiences
        xpath = './saml:Conditions/saml:AudienceRestriction/saml:Audience'
        search(xpath).map(&:text)
      end

      def encrypted?
        @encrypted
      end

      def decryptable?
        return true unless encrypted?
        !@cannot_decrypt
      end

      def present?
        @node.present?
      end

      def to_s
        @node.to_s
      end

      private

      attr_reader :configuration

      def decrypt(decryptor)
        encrypted_assertion = at_xpath('./xmlenc:EncryptedData')
        @encrypted = encrypted_assertion.present?
        return unless @encrypted
        @node = decryptor.decrypt_node(encrypted_assertion)
      rescue Xml::Kit::DecryptionError => error
        @cannot_decrypt = true
        Saml::Kit.logger.error(error)
      end

      def parse_date(value)
        DateTime.parse(value)
      rescue StandardError => error
        Saml::Kit.logger.error(error)
        Time.at(0).to_datetime
      end

      def must_match_issuer
        return if audiences.empty?
        return if audiences.include?(configuration.entity_id)
        errors[:audience] << error_message(:must_match_issuer)
      end

      def must_be_active_session
        return if active?
        errors[:base] << error_message(:expired)
      end

      def must_have_valid_signature
        return if !signed? || signature.valid?

        signature.errors.each do |attribute, message|
          errors.add(attribute, message)
        end
      end

      def must_be_decryptable
        errors.add(:base, error_message(:cannot_decrypt)) unless decryptable?
      end

      def to_nokogiri
        @node
      end
    end
  end
end

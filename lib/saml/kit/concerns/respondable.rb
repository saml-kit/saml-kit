# frozen_string_literal: true

module Saml
  module Kit
    # This module provides the behaviours
    # associated with SAML Response documents.
    # .e.g. Response, LogoutResponse
    module Respondable
      extend ActiveSupport::Concern
      attr_reader :request_id

      included do
        validates_inclusion_of :status_code, in: [Namespaces::SUCCESS]
        validate :must_match_request_id
      end

      # @!visibility private
      def query_string_parameter
        'SAMLResponse'
      end

      # Returns the /Status/StatusCode@Value
      def status_code
        at_xpath('./*/samlp:Status/samlp:StatusCode/@Value').try(:value)
      end

      # Returns the /Status/StatusMessage
      def status_message
        at_xpath('./*/samlp:Status/samlp:StatusMessage').try(:text)
      end

      # Returns the /InResponseTo attribute.
      def in_response_to
        at_xpath('./*/@InResponseTo').try(:value)
      end

      # Returns true if the Status code is #{Saml::Kit::Namespaces::SUCCESS}
      def success?
        Namespaces::SUCCESS == status_code
      end

      private

      def must_match_request_id
        return if request_id.nil?
        return if in_response_to == request_id

        errors.add(:in_response_to, error_message(:invalid_response_to))
      end
    end
  end
end

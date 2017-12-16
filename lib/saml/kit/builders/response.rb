module Saml
  module Kit
    module Builders
      class Response
        include Templatable
        attr_reader :user, :request
        attr_accessor :id, :reference_id, :now
        attr_accessor :version, :status_code
        attr_accessor :issuer, :destination, :encrypt
        attr_reader :configuration

        def initialize(user, request, configuration: Saml::Kit.configuration)
          @user = user
          @request = request
          @id = Id.generate
          @reference_id = Id.generate
          @now = Time.now.utc
          @version = "2.0"
          @status_code = Namespaces::SUCCESS
          @issuer = configuration.issuer
          @embed_signature = want_assertions_signed
          @encrypt = encryption_certificate.present?
          @configuration = configuration
        end

        def want_assertions_signed
          request.provider.want_assertions_signed
        rescue => error
          Saml::Kit.logger.error(error)
          nil
        end

        def build
          Saml::Kit::Response.new(to_xml, request_id: request.id, configuration: configuration)
        end

        def encryption_certificate
          request.provider.encryption_certificates.first
        rescue => error
          Saml::Kit.logger.error(error)
          nil
        end

        private

        def assertion
          @assertion ||= Saml::Kit::Builders::Assertion.new(self)
        end

        def response_options
          {
            ID: id,
            Version: version,
            IssueInstant: now.iso8601,
            Destination: destination,
            Consent: Namespaces::UNSPECIFIED,
            InResponseTo: request.id,
            xmlns: Namespaces::PROTOCOL,
          }
        end
      end
    end
  end
end

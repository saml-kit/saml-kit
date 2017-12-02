module Saml
  module Kit
    module Builders
      class LogoutResponse
        attr_accessor :id, :issuer, :version, :status_code, :sign, :now, :destination
        attr_reader :request

        def initialize(user, request, configuration: Saml::Kit.configuration, sign: true)
          @user = user
          @now = Time.now.utc
          @request = request
          @id = "_#{SecureRandom.uuid}"
          @version = "2.0"
          @status_code = Namespaces::SUCCESS
          @sign = sign
          @issuer = configuration.issuer
        end

        def to_xml
          Signature.sign(sign: sign) do |xml, signature|
            xml.LogoutResponse logout_response_options do
              xml.Issuer(issuer, xmlns: Namespaces::ASSERTION)
              signature.template(id)
              xml.Status do
                xml.StatusCode Value: status_code
              end
            end
          end
        end

        def build
          Saml::Kit::LogoutResponse.new(to_xml, request_id: request.id)
        end

        private

        def logout_response_options
          {
            xmlns: Namespaces::PROTOCOL,
            ID: id,
            Version: version,
            IssueInstant: now.utc.iso8601,
            Destination: destination,
            InResponseTo: request.id,
          }
        end
      end
    end
  end
end

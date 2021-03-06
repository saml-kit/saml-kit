# frozen_string_literal: true

module Saml
  module Kit
    module Bindings
      # This class is a base class for SAML bindings.
      # {include:file:spec/saml/kit/bindings/binding_spec.rb}
      class Binding
        attr_reader :binding, :location

        def initialize(binding:, location:)
          @binding = binding
          @location = location
        end

        def binding?(other)
          binding == other
        end

        def serialize(*)
          []
        end

        def deserialize(_params)
          raise ArgumentError, 'Unsupported binding'
        end

        def to_h
          { binding: binding, location: location }
        end

        def ==(other)
          to_s == other.to_s
        end

        def eql?(other)
          self == other
        end

        def hash
          to_s.hash
        end

        def to_s
          "#{location}#{binding}"
        end

        def inspect
          to_h.inspect
        end

        protected

        def saml_param_from(params)
          parameters = {
            SAMLRequest: params[:SAMLRequest] || params['SAMLRequest'],
            SAMLResponse: params[:SAMLResponse] || params['SAMLResponse'],
          }
          return parameters[:SAMLRequest] if parameters[:SAMLRequest].present?
          return parameters[:SAMLResponse] if parameters[:SAMLResponse].present?

          message = 'SAMLRequest or SAMLResponse parameter is required.'
          raise ArgumentError, message
        end
      end
    end
  end
end

module Saml
  module Kit
    class InvalidDocument < Document
      validate do |model|
        model.errors[:base] << model.error_message(:invalid)
      end

      def initialize(xml)
        super(xml, "InvalidDocument")
      end
    end
  end
end

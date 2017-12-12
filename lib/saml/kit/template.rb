module Saml
  module Kit
    class Template
      attr_reader :target

      def initialize(target)
        @target = target
      end

      def to_xml(options)
        template.render(target, options)
      end

      private

      def template_name
        "#{target.class.name.split("::").last.underscore}.builder"
      end

      def template_path
        root_path = File.expand_path(File.dirname(__FILE__))
        File.join(root_path, "builders/templates/", template_name)
      end

      def template
        Tilt.new(template_path)
      end
    end
  end
end

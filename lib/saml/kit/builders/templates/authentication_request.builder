# frozen_string_literal: true

xml.instruct!
xml.tag!('samlp:AuthnRequest', request_options) do
  xml.tag!('saml:Issuer', issuer)
  signature_for(reference_id: id, xml: xml)
  xml.tag!('samlp:NameIDPolicy', Format: name_id_format) if name_id_format.present?
end

# Monkey patch for REXML: use (") instead of (') in XML attributes, escape both.

module REXML
  class Attribute
    def to_string
      %{#@expanded_name="#{to_s().gsub(/"/, '&quot;').gsub(/'/, '&apos;')}"}
    end
  end
end

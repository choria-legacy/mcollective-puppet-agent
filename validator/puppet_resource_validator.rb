module MCollective
  module Validator
    class Puppet_resourceValidator
      def self.validate(resource)
        Validator.typecheck(resource, :string)

        raise("'%s' is not a valid resource name" % resource) unless resource =~ /\A[a-zA-Z0-9_]+\[.+\]\Z/
      end
    end
  end
end


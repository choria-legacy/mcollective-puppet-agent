module MCollective
  module Validator
    class Puppet_variableValidator
      def self.validate(variable)
        Validator.typecheck(variable, :string)
        Validator.validate(variable, :shellsafe)

        if variable.length == 1
          raise("Invalid variable name '%s' specified" % variable) unless variable =~ /\A[a-zA-Z]\Z/
        else
          raise("Invalid variable name '%s' specified" % variable) unless variable =~ /\A[a-zA-Z0-9_]+\Z/
        end
      end
    end
  end
end


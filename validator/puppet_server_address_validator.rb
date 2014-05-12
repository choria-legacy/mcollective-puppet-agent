require File.expand_path(File.join(File.dirname(__FILE__), '..', 'util',
                                   'puppet_server_address_validation'))

module MCollective
  module Validator
    class Puppet_server_addressValidator
      def self.validate(server)
        Validator.typecheck(server, :string)
        Validator.validate(server, :shellsafe)
        Util::PuppetServerAddressValidation.validate_server(server)
      end
    end
  end
end

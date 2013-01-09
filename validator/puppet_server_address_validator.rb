module MCollective
  module Validator
    class Puppet_server_addressValidator
      def self.validate(server)
        Validator.typecheck(server, :string)
        Validator.validate(server, :shellsafe)

        (host, port) = server.split(":")

        if host && !(host =~ /\A(([a-zA-Z]|[a-zA-Z][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])\Z/)
          raise "The hostname '%s' is not a valid hostname" % host
        end

        if port && !(port =~ /\A\d+\Z/)
          raise "The port '%s' is not a valid puppet master port" % port
        end
      end
    end
  end
end


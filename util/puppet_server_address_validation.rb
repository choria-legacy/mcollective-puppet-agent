module MCollective
  module Util
    module PuppetServerAddressValidation

      class Host
        require 'ipaddr'
        attr_reader :name, :port

        INT_REGEX         = /\A\d+\Z/
        PORT_REGEX        = /\A\d+\Z/
        IPV6_FORMAT_REGEX = /\A\[[a-fA-F0-9\:\.]*\](\:\d*)?/
        NAME_REGEX        = /\A(([a-zA-Z]|[a-zA-Z][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])\Z/

        def initialize(server)
          @server = server
          @name, @port = parse_name_and_port
        end

        private

        def parse_name_and_port
          name, port = nil
          if ipv6_server?
            # IPv6 address, without a port
            name = @server
          elsif @server =~ IPV6_FORMAT_REGEX
            # IPv6 url "[<ipv6_address>]:<port>", as in rfc2732
            name, port = @server[1..@server.size].split(']')
            if port
              # Remove the initial colon
              port = port[1..port.size]
            end
          else
            # Parse the port only if we have a single colon,
            # to avoid splitting invalid IPv6 addresses
            if @server && @server.count(':') == 1
              name, port = @server.split(':')
            else
              name = @server
            end
          end
          return name, port
        end

        def process_ip (addr)
          # NB: an int is a valid IPv6 addr for the ipaddr lib on ruby 1.8.7!
          unless addr =~ INT_REGEX
            begin
              IPAddr.new(addr)
            rescue
            end
          end
        end

        public

        def valid_text_name?
          @name =~ NAME_REGEX
        end

        def ipv6_server?
          ip = process_ip(@server)
          ip && ip.ipv6?
        end

        def valid_ip_name?
          ip = process_ip(@name)
          ip && (ip.ipv4? || ip.ipv6?)
        end

        def valid_port?
          @port =~ PORT_REGEX
        end
      end


      def self.validate_server(server)

        host = Host.new(server)

        if host.name && !(host.valid_ip_name? || host.valid_text_name?)
          raise "The hostname '%s' is not a valid hostname" % host.name
        end

        if host.port && !host.valid_port?
          raise "The port '%s' is not a valid puppet master port" % host.port
        end
      end

      def self.parse_name_and_port_of(server)
        host = Host.new(server)
        return host.name, host.port
      end

    end
  end
end

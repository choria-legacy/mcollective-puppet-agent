module MCollective
  class Aggregate
    class Boolean_summary<Base
      def startup_hook
        @result[:value] = {}
        @result[:type] = :collection

        # set default aggregate_format if it is undefined
        @arguments = {true => 'True', false => 'False'} unless @arguments

        # Support boolean and symbol arguments
        @arguments[true] = @arguments.delete(:true) if @arguments.include?(:true)
        @arguments[false] = @arguments.delete(:false) if @arguments.include?(:false)

        @aggregate_format = "%5s = %s" unless @aggregate_format
      end

      # Increments the value field if value has been seen before
      # Else create a new value field
      def process_result(value, reply)
        unless value.nil?
          if value.is_a? Array
            value.map{|val| add_value(val)}
          else
            add_value(value)
          end
        end
      end

      # Transform the true or false value into the replacement string
      def add_value(value)
        if @result[:value].keys.include?(@arguments[value])
          @result[:value][@arguments[value]] += 1
        else
          @result[:value][@arguments[value]] = 1
        end
      end
    end
  end
end

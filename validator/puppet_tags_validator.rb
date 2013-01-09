module MCollective
  module Validator
    class Puppet_tagsValidator
      def self.validate(tags)
        Validator.typecheck(tags, :string)
        Validator.validate(tags, :shellsafe)

        tags.split(",").each do |tag|
          tag.split("::").each do |part|
            Validator.validate(part, :puppet_variable)
          end
        end
      end
    end
  end
end


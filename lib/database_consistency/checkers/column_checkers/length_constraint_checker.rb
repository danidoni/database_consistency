# frozen_string_literal: true

module DatabaseConsistency
  module Checkers
    # This class checks missing presence validator
    class LengthConstraintChecker < ColumnChecker
      VALIDATOR_CLASS =
        if defined?(ActiveRecord::Validations::LengthValidator)
          ActiveRecord::Validations::LengthValidator
        else
          ActiveModel::Validations::LengthValidator
        end

      private

      # We skip check when:
      #  - column hasn't limit constraint
      #  - column insn't string nor text
      #  - column is array (PostgreSQL only)
      def preconditions
        !column.limit.nil? && %i[string text].include?(column.type) && !postgresql_array?
      end

      # @return [Boolean] true if it is an array (PostgreSQL only)
      def postgresql_array?
        column.respond_to?(:array) && column.array
      end

      # Table of possible statuses
      # | validation | status  |
      # | ---------- | ------- |
      # | provided   | ok      |
      # | small      | warning |
      # | missing    | fail    |
      def check
        return report_template(:fail, error_slug: :length_validator_missing) unless validator

        if valid?(:==)
          report_template(:ok)
        elsif valid?(:<)
          report_template(:warning, error_slug: :length_validator_greater_limit)
        else
          report_template(:fail, error_slug: :length_validator_lower_limit)
        end
      end

      def valid?(sign)
        %i[maximum is].each do |option|
          return validator.options[option].public_send(sign, column.limit) if validator.options[option]
        end

        false
      end

      def validator
        @validator ||= model.validators.grep(VALIDATOR_CLASS).find do |validator|
          Helper.check_inclusion?(validator.attributes, column.name)
        end
      end
    end
  end
end

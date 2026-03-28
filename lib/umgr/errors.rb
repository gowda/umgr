# frozen_string_literal: true

module Umgr
  module Errors
    class Error < StandardError
      EXIT_CODE = 1

      def exit_code
        self.class::EXIT_CODE
      end
    end

    class ValidationError < Error
      EXIT_CODE = 2
    end

    class UnknownActionError < Error
      EXIT_CODE = 3
    end

    class InternalError < Error
      EXIT_CODE = 70
    end
  end
end

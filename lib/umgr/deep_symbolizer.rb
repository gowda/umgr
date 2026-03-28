# frozen_string_literal: true

module Umgr
  module DeepSymbolizer
    module_function

    def call(value)
      case value
      when Hash
        symbolize_hash(value)
      when Array
        value.map { |item| call(item) }
      else
        value
      end
    end

    def symbolize_hash(value)
      value.each_with_object({}) do |(key, nested_value), memo|
        symbol_key = key.is_a?(String) ? key.to_sym : key
        memo[symbol_key] = call(nested_value)
      end
    end
  end
end

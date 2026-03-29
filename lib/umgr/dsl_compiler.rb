# frozen_string_literal: true

module Umgr
  class DslCompiler
    DEFAULT_DSL_PATH = 'umgr.rb'

    def self.compile_file(path)
      new(path).compile
    end

    def initialize(path)
      @path = path
    end

    def compile
      config = compiled_config_from_source(File.read(path))
      return ConfigValidator.validated_data(config, source: path) if config.is_a?(Hash)

      raise Errors::ValidationError, "DSL must define configuration in #{path}"
    rescue Errno::ENOENT
      raise Errors::ValidationError, "DSL file not found: #{path}"
    rescue SyntaxError => e
      raise Errors::ValidationError, "DSL parse error in #{path}: #{e.message}"
    end

    private

    attr_reader :path

    def compiled_config_from_source(source)
      context = Context.new
      result = context.instance_eval(source, path, 1)
      context.compiled_config || result
    end

    class Context
      def initialize
        @builder = Builder.new
      end

      def umgr(&)
        instance_eval(&)
      end

      def version(value)
        builder.version(value)
      end

      def resource(provider:, type:, name:, **)
        builder.resource(provider: provider, type: type, name: name, **)
      end

      def resources(items)
        items.each do |item|
          resource(**item.transform_keys(&:to_sym))
        end
      end

      def compiled_config
        return unless builder.used?

        builder.to_h
      end

      private

      attr_reader :builder
    end

    class Builder
      def initialize
        @version = nil
        @resources = []
      end

      def version(value)
        @version = value
      end

      def resource(provider:, type:, name:, **options)
        @resources << stringify_hash_keys(
          { provider: provider, type: type, name: name }.merge(options)
        )
      end

      def used?
        !@version.nil? || !@resources.empty?
      end

      def to_h
        {
          'version' => @version || 1,
          'resources' => @resources
        }
      end

      private

      def stringify_hash_keys(value)
        case value
        when Hash
          value.each_with_object({}) do |(key, nested_value), memo|
            memo[key.to_s] = stringify_hash_keys(nested_value)
          end
        when Array
          value.map { |item| stringify_hash_keys(item) }
        else
          value
        end
      end
    end
  end
end

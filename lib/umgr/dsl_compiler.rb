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

    class Context < BasicObject
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

      def if_enabled(condition, &)
        instance_eval(&) if condition
      end

      def for_each(items, &)
        items.each do |item|
          instance_exec(item, &)
        end
      end

      def provider_matrix(providers:, accounts:, type: 'user', **shared_options)
        providers.each do |provider|
          emit_matrix_resources(provider, type, accounts, shared_options)
        end
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

      def emit_matrix_resources(provider, type, accounts, shared_options)
        accounts.each do |entry|
          emit_matrix_resource(provider, type, entry, shared_options)
        end
      end

      def emit_matrix_resource(provider, type, entry, shared_options)
        account = normalize_account_entry(entry)
        account_name = account.delete('name')
        resource(
          provider: provider.to_s,
          type: type.to_s,
          name: account_name.to_s,
          **shared_options,
          **account.transform_keys(&:to_sym)
        )
      end

      def normalize_account_entry(entry)
        return { 'name' => entry.to_s } unless entry.is_a?(::Hash)

        normalized = entry.transform_keys(&:to_s)
        name = normalized['name']
        if !name.is_a?(::String) || name.empty?
          ::Kernel.raise ::Umgr::Errors::ValidationError, 'provider_matrix account requires non-empty `name`'
        end

        normalized
      end

      def method_missing(name, *_args, &)
        ::Kernel.raise(
          ::Umgr::Errors::ValidationError,
          "Unsupported DSL method `#{name}`. Allowed: umgr, version, resource, resources, " \
          'if_enabled, for_each, provider_matrix.'
        )
      end

      def respond_to_missing?(_name, _include_private = false)
        false
      end
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
          'resources' => sorted_resources
        }
      end

      private

      def sorted_resources
        @resources.sort_by do |resource|
          [resource['provider'].to_s, resource['type'].to_s, resource['name'].to_s]
        end
      end

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

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
      context = Context.new(source:)
      result = context.instance_eval(source, path, 1)
      context.compiled_config || result
    end

    class Context < BasicObject
      ASSIGNMENT_LINE_PATTERN = /^\s*([a-z_]\w*)\s*=/.freeze

      def initialize(source:)
        @builder = Builder.new
        @umgr_defined = false
        @inside_umgr = false
        @source_lines = source.lines
      end

      def umgr(&)
        if @inside_umgr || @umgr_defined
          ::Kernel.raise ::Umgr::Errors::ValidationError, 'Top-level `umgr` block can only be declared once'
        end

        @umgr_defined = true
        @inside_umgr = true
        apply_umgr_assignments(&)
      ensure
        @inside_umgr = false
      end

      def resource(provider:, type:, name:, **)
        if @inside_umgr
          ::Kernel.raise ::Umgr::Errors::ValidationError, '`resource` must be declared at top-level, outside `umgr`'
        end

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
        ::Kernel.raise ::Umgr::Errors::ValidationError, 'Top-level `umgr` block is required' unless @umgr_defined

        builder.to_h
      end

      private

      attr_reader :builder

      def apply_umgr_assignments(&block)
        assignment_names = umgr_assignment_names_for(block)
        instance_eval(&block)
        validate_umgr_assignments!(assignment_names)
        return unless block.binding.local_variable_defined?(:version)

        builder.version(block.binding.local_variable_get(:version))
      end

      def validate_umgr_assignments!(assignment_names)
        invalid = assignment_names - [:version]
        return if invalid.empty?

        ::Kernel.raise(
          ::Umgr::Errors::ValidationError,
          "Unsupported `umgr` assignment(s): #{invalid.join(', ')}"
        )
      end

      def umgr_assignment_names_for(block)
        start_index = block.source_location.fetch(1) - 1
        body_lines = extract_umgr_block_lines(start_index)
        body_lines.filter_map do |line|
          match = line.match(ASSIGNMENT_LINE_PATTERN)
          match && match[1].to_sym
        end.uniq
      end

      def extract_umgr_block_lines(start_index)
        line = @source_lines.fetch(start_index, '')
        if line.include?('{')
          return [line[/\{(.*)\}/, 1]].compact
        end

        lines = []
        depth = 1
        index = start_index + 1

        while depth.positive? && index < @source_lines.length
          current = @source_lines[index]
          stripped = current.strip

          depth -= 1 if stripped == 'end'
          break if depth.zero?

          lines << current
          depth += 1 if stripped.end_with?(' do')
          index += 1
        end

        lines
      end

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
          "Unsupported DSL method `#{name}`. Allowed methods: umgr, resource, resources, " \
          'if_enabled, for_each, provider_matrix. Set config with assignment in `umgr` (for example, `version = 1`).'
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

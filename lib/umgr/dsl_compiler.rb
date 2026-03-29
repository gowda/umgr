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

    class UmgrAssignmentParser
      ASSIGNMENT_LINE_PATTERN = /^\s*([a-z_]\w*)\s*=/

      def initialize(source_lines)
        @source_lines = source_lines
      end

      def assignment_names_for(block)
        start_index = block.source_location.fetch(1) - 1
        body_lines = extract_umgr_block_lines(start_index)
        body_lines.filter_map do |line|
          match = line.match(ASSIGNMENT_LINE_PATTERN)
          match && match[1].to_sym
        end.uniq
      end

      private

      def extract_umgr_block_lines(start_index)
        line = @source_lines.fetch(start_index, '')
        inline_body = line[/\{(.*)\}/, 1]
        return [inline_body] if line.include?('{') && inline_body

        nested_block_lines(start_index + 1)
      end

      def nested_block_lines(start_index)
        lines = []
        depth = 1
        index = start_index

        loop do
          break unless scanning_block?(depth, index)

          depth, index = scan_block_line(lines, depth, index)
        end

        lines
      end

      def scanning_block?(depth, index)
        depth.positive? && index < @source_lines.length
      end

      def scan_block_line(lines, depth, index)
        current = @source_lines[index]
        stripped = current.strip
        depth -= 1 if stripped == 'end'
        return [depth, index + 1] if depth.zero?

        lines << current
        depth += 1 if stripped.end_with?(' do')
        [depth, index + 1]
      end
    end

    class ResourceReferenceParser
      def call(identifier, name, options)
        raise_legacy_resource_syntax_error!(options) if legacy_resource_syntax?(identifier, name, options)

        provider, type = parse_resource_identifier!(identifier)
        resource_name = parse_resource_name!(name)
        [provider, type, resource_name]
      end

      private

      def legacy_resource_syntax?(identifier, name, options)
        identifier.nil? && name.nil? && options.key?(:provider) && options.key?(:type) && options.key?(:name)
      end

      def raise_legacy_resource_syntax_error!(options)
        ::Kernel.raise(
          ::Umgr::Errors::ValidationError,
          "Legacy resource syntax is not supported: #{options.inspect}. Use: resource 'provider.type', 'name'"
        )
      end

      def parse_resource_identifier!(identifier)
        match = identifier.to_s.match(/\A([^.]+)\.([^.]+)\z/)
        unless match
          ::Kernel.raise(
            ::Umgr::Errors::ValidationError,
            "Resource identifier must be in 'provider.type' format: #{identifier.inspect}"
          )
        end

        [match[1], match[2]]
      end

      def parse_resource_name!(name)
        value = name.to_s
        if value.empty?
          ::Kernel.raise(::Umgr::Errors::ValidationError, "Resource name must be a non-empty string: #{name.inspect}")
        end

        value
      end
    end

    class AccountEntryNormalizer
      def call(entry)
        return { 'name' => entry.to_s } unless entry.is_a?(::Hash)

        normalized = entry.transform_keys(&:to_s)
        name = normalized['name']
        if !name.is_a?(::String) || name.empty?
          ::Kernel.raise ::Umgr::Errors::ValidationError, 'provider_matrix account requires non-empty `name`'
        end

        normalized
      end
    end

    class ResourceItemValidator
      def call(item)
        required = %w[provider type name]
        missing = required.reject { |key| item.key?(key) }
        return if missing.empty?

        ::Kernel.raise(
          ::Umgr::Errors::ValidationError,
          "resources(...) item is missing required key(s): #{missing.join(', ')}"
        )
      end
    end

    class Context < BasicObject
      def initialize(source:)
        @builder = Builder.new
        @umgr_defined = false
        @inside_umgr = false
        @assignment_parser = UmgrAssignmentParser.new(source.lines)
        @resource_reference_parser = ResourceReferenceParser.new
        @account_entry_normalizer = AccountEntryNormalizer.new
        @resource_item_validator = ResourceItemValidator.new
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

      def resource(identifier = nil, name = nil, **options)
        if @inside_umgr
          ::Kernel.raise ::Umgr::Errors::ValidationError, '`resource` must be declared at top-level, outside `umgr`'
        end

        provider, type, resource_name = @resource_reference_parser.call(identifier, name, options)
        builder.resource(provider: provider, type: type, name: resource_name, **options)
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
          normalized = item.transform_keys(&:to_s)
          @resource_item_validator.call(normalized)
          resource(
            "#{normalized.fetch('provider')}.#{normalized.fetch('type')}",
            normalized.fetch('name'),
            **normalized.except('provider', 'type', 'name').transform_keys(&:to_sym)
          )
        end
      end

      def compiled_config
        ::Kernel.raise ::Umgr::Errors::ValidationError, 'Top-level `umgr` block is required' unless @umgr_defined
        builder.to_h
      end

      private

      attr_reader :builder

      def apply_umgr_assignments(&block)
        assignment_names = @assignment_parser.assignment_names_for(block)
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

      def emit_matrix_resources(provider, type, accounts, shared_options)
        accounts.each do |entry|
          emit_matrix_resource(provider, type, entry, shared_options)
        end
      end

      def emit_matrix_resource(provider, type, entry, shared_options)
        account = @account_entry_normalizer.call(entry)
        account_name = account.delete('name')
        resource(
          "#{provider}.#{type}",
          account_name.to_s,
          **shared_options,
          **account.transform_keys(&:to_sym)
        )
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

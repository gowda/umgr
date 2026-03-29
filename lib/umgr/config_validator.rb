# frozen_string_literal: true

require 'json'
require 'yaml'

module Umgr
  class ConfigValidator
    REQUIRED_TOP_LEVEL_KEYS = %w[version resources].freeze
    REQUIRED_RESOURCE_FIELDS = %w[provider type name].freeze

    def self.validated_config(config_path)
      new(config_path).validated_config
    end

    def self.validated_content(content, source: 'stdin')
      new(source, content: content, parse_mode: :auto).validated_config
    end

    def self.validated_data(data, source:)
      new(source, parsed_data: data).validated_config
    end

    def self.validate!(config_path)
      new(config_path).validate!
    end

    def initialize(config_path, content: nil, parse_mode: nil, parsed_data: nil)
      @config_path = config_path
      @content = content
      @parse_mode = parse_mode
      @parsed_data = parsed_data
    end

    def validated_config
      parsed = parse
      validate_root!(parsed)
      validate_resources!(parsed['resources'])
      parsed
    end

    def validate!
      validated_config
      nil
    end

    private

    attr_reader :config_path, :content, :parse_mode, :parsed_data

    def parse
      return parsed_data if parsed_data

      raw_content = content || File.read(config_path)
      parse_content(raw_content)
    rescue JSON::ParserError, Psych::SyntaxError => e
      raise Errors::ValidationError, "Config parse error in #{config_path}: #{e.message}"
    end

    def parse_content(content)
      parser_mode = parse_mode || extension_parse_mode
      return parse_by_extension(content) unless parser_mode == :auto

      parse_auto(content)
    end

    def parse_auto(content)
      JSON.parse(content)
    rescue JSON::ParserError
      YAML.safe_load(content, aliases: false)
    end

    def extension_parse_mode
      case File.extname(config_path).downcase
      when '.json'
        :json
      when '.yml', '.yaml'
        :yaml
      else
        :unsupported
      end
    end

    def parse_by_extension(content)
      case File.extname(config_path).downcase
      when '.json'
        JSON.parse(content)
      when '.yml', '.yaml'
        YAML.safe_load(content, aliases: false)
      else
        raise Errors::ValidationError, "Unsupported config format: #{config_path}"
      end
    end

    def validate_root!(parsed)
      raise Errors::ValidationError, "Config root must be an object in #{config_path}" unless parsed.is_a?(Hash)

      REQUIRED_TOP_LEVEL_KEYS.each do |key|
        next if parsed.key?(key)

        raise Errors::ValidationError, "Missing required key `#{key}` in #{config_path}"
      end

      version = parsed['version']
      return if version.is_a?(Integer) && version.positive?

      raise Errors::ValidationError, "`version` must be a positive integer in #{config_path}"
    end

    def validate_resources!(resources)
      raise Errors::ValidationError, "`resources` must be an array in #{config_path}" unless resources.is_a?(Array)

      resources.each_with_index do |resource, index|
        validate_resource!(resource, index)
      end
    end

    def validate_resource!(resource, index)
      unless resource.is_a?(Hash)
        raise Errors::ValidationError, "Resource at index #{index} must be an object in #{config_path}"
      end

      REQUIRED_RESOURCE_FIELDS.each do |field|
        value = resource[field]
        next if value.is_a?(String) && !value.empty?

        raise Errors::ValidationError, "Resource #{index} missing required string field `#{field}` in #{config_path}"
      end
    end
  end
end

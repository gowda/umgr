# frozen_string_literal: true

module Umgr
  module ImportResultBuilder
    module_function

    def call(state_backend:, options:, provider_registry:)
      desired_state = options.fetch(:desired_state)
      imported_resources = import_resources(
        desired_state.fetch(:resources, []),
        provider_registry
      )
      final_state = build_final_state(desired_state.fetch(:version), imported_resources)
      state_backend.write(final_state)
      build_result(options, state_backend, final_state)
    end

    def import_resources(resources, provider_registry)
      resources.flat_map do |resource|
        import_resource(resource, provider_registry)
      end
    end

    def import_resource(resource, provider_registry)
      provider_name = resource.fetch(:provider)
      provider = provider_registry.fetch(provider_name)
      current_result = provider.current(resource: resource)
      ensure_successful_current!(current_result, provider_name)
      extract_resources(current_result, resource)
    end

    def ensure_successful_current!(result, provider_name)
      return unless result.fetch(:ok, result.fetch('ok', true)) == false

      message = result[:error] || result['error'] || "provider current failed for #{provider_name}"
      raise Errors::InternalError, message
    end

    def extract_resources(result, fallback_resource)
      imported_accounts = result[:imported_accounts] || result['imported_accounts']
      return imported_accounts if imported_accounts.is_a?(Array)

      resource = result[:resource] || result['resource']
      return [resource] if resource

      account = result[:account] || result['account']
      return [fallback_resource.merge(attributes: account)] if account

      raise Errors::InternalError, 'Provider current result missing imported resources'
    end

    def build_final_state(version, imported_resources)
      enriched = DesiredStateEnricher.call(version: version, resources: imported_resources)
      deduped_resources = deduplicate_by_identity(enriched.fetch(:resources))
      {
        version: version,
        resources: deduped_resources
      }
    end

    def deduplicate_by_identity(resources)
      unique = {}
      resources.each { |resource| unique[resource.fetch(:identity)] = resource }
      unique.values.sort_by { |resource| resource.fetch(:identity) }
    end

    def build_result(options, state_backend, final_state)
      {
        ok: true,
        action: 'import',
        status: 'imported',
        options: options,
        state_path: state_backend.path,
        state: final_state,
        imported_count: final_state.fetch(:resources).length
      }
    end
  end
end

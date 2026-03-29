# frozen_string_literal: true

require 'octokit'

module Umgr
  module Providers
    class GithubApiClient
      def list_org_users(org:, token:)
        with_api_error_handling do
          build_client(token: token).org_members(org)
        end
      end

      def list_org_team_memberships(org:, token:)
        with_api_error_handling do
          client = build_client(token: token)
          teams = client.org_teams(org)
          build_team_memberships(client: client, teams: teams)
        end
      end

      def invite_org_member(org:, login:, token:)
        with_api_error_handling do
          build_client(token: token).update_organization_membership(org, user: login, role: 'member')
        end
      end

      def remove_org_member(org:, login:, token:)
        with_api_error_handling do
          build_client(token: token).remove_organization_membership(org, user: login)
        end
      end

      def add_team_membership(org:, team_slug:, login:, token:)
        with_api_error_handling do
          client = build_client(token: token)
          team_id = team_id_for!(client: client, org: org, team_slug: team_slug)
          client.add_team_membership(team_id, login)
        end
      end

      def remove_team_membership(org:, team_slug:, login:, token:)
        with_api_error_handling do
          client = build_client(token: token)
          team_id = team_id_for!(client: client, org: org, team_slug: team_slug)
          client.remove_team_membership(team_id, login)
        end
      end

      private

      def build_client(token:)
        Octokit::Client.new(access_token: token, auto_paginate: true)
      end

      def build_team_memberships(client:, teams:)
        memberships = Hash.new { |memo, key| memo[key] = [] }

        teams.each do |team|
          team_id = fetch_value(team, :id)
          team_slug = fetch_value(team, :slug)
          next unless team_id && team_slug

          add_team_members!(memberships: memberships, client: client, team_id: team_id, team_slug: team_slug)
        end

        memberships.transform_values!(&:sort)
      end

      def add_team_members!(memberships:, client:, team_id:, team_slug:)
        members = client.team_members(team_id)

        members.each do |member|
          login = fetch_value(member, :login)
          next unless login

          memberships[login] << team_slug
        end
      end

      def fetch_value(payload, key)
        return normalize_value(payload.public_send(key)) if payload.respond_to?(key)
        return fetch_indexed_value(payload, key) if payload.respond_to?(:[])

        nil
      end

      def fetch_indexed_value(payload, key)
        normalize_value(payload[key] || payload[key.to_s])
      end

      def normalize_value(value)
        value.is_a?(String) ? value : value&.to_s
      end

      def team_id_for!(client:, org:, team_slug:)
        teams = client.org_teams(org)
        matched = teams.find { |team| fetch_value(team, :slug) == team_slug }
        return fetch_value(matched, :id) if matched

        raise Errors::ValidationError, "GitHub team not found in org #{org}: #{team_slug}"
      end

      def with_api_error_handling
        yield
      rescue Octokit::Error => e
        raise Errors::ApiError, "GitHub API request failed: #{e.message}"
      end
    end
  end
end

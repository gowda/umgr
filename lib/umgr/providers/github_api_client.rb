# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

module Umgr
  module Providers
    class GithubApiClient
      API_BASE_URL = 'https://api.github.com'

      def list_org_users(org:, token:)
        paginate("/orgs/#{org}/members", token: token)
      end

      def list_org_team_memberships(org:, token:)
        team_memberships = Hash.new { |memo, key| memo[key] = [] }
        teams = paginate("/orgs/#{org}/teams", token: token)

        teams.each do |team|
          append_team_memberships!(team_memberships: team_memberships, org: org, token: token, team: team)
        end

        team_memberships.transform_values!(&:sort)
      end

      private

      def paginate(path, token:)
        results = []
        next_url = build_url(path)

        while next_url
          response = request_json(next_url, token: token)
          body = response.fetch(:body)
          headers = response.fetch(:headers)
          results.concat(body) if body.is_a?(Array)
          next_url = parse_next_url(headers[:link])
        end

        results
      end

      def build_url(path)
        URI.parse("#{API_BASE_URL}#{path}")
      end

      def request_json(url, token:)
        response = perform_request(url, token: token)
        ensure_success!(response, url)
        {
          body: JSON.parse(response.body),
          headers: response.to_hash.transform_keys(&:to_sym)
        }
      end

      def perform_request(url, token:)
        request = Net::HTTP::Get.new(url)
        request_headers(token).each { |key, value| request[key] = value }
        Net::HTTP.start(url.host, url.port, use_ssl: url.scheme == 'https') { |http| http.request(request) }
      end

      def request_headers(token)
        {
          'Accept' => 'application/vnd.github+json',
          'Authorization' => "Bearer #{token}",
          'X-GitHub-Api-Version' => '2022-11-28'
        }
      end

      def ensure_success!(response, url)
        status_code = response.code.to_i
        return if status_code.between?(200, 299)

        raise Errors::ApiError,
              "GitHub API request failed (#{response.code}) for #{url}: #{response.body}"
      end

      def parse_next_url(link_header)
        return nil unless link_header

        header_value = normalize_header_value(link_header)
        return nil unless header_value

        links = header_value.split(',').map(&:strip)
        next_entry = links.find { |entry| entry.end_with?('rel="next"') }
        return nil unless next_entry

        raw_url = next_entry[/<([^>]+)>/, 1]
        raw_url ? URI.parse(raw_url) : nil
      end

      def normalize_header_value(value)
        return value.first if value.is_a?(Array)
        return value if value.is_a?(String)

        nil
      end

      def append_team_memberships!(team_memberships:, org:, token:, team:)
        team_slug = team.fetch('slug', nil)
        return unless team_slug.is_a?(String) && !team_slug.empty?

        members = paginate("/orgs/#{org}/teams/#{team_slug}/members", token: token)
        members.each do |member|
          login = member.fetch('login', nil)
          next unless login.is_a?(String) && !login.empty?

          team_memberships[login] << team_slug
        end
      end
    end
  end
end

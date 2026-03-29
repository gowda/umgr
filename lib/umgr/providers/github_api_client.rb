# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

module Umgr
  module Providers
    class GithubApiClient
      API_BASE_URL = 'https://api.github.com'

      def list_org_users(org:, token:)
        path = "/orgs/#{org}/members"
        paginate(path, token: token)
      end

      def list_user_teams(org:, login:, token:)
        path = "/orgs/#{org}/memberships/#{login}/teams"
        paginate(path, token: token).map { |team| team.fetch('slug') }
      end

      private

      def paginate(path, token:)
        items = []
        next_url = URI.join(API_BASE_URL, path)

        while next_url
          response = request_json(next_url, token: token)
          items.concat(response.fetch('body'))
          next_url = next_link(response.fetch('headers')['link'])
        end

        items
      end

      def request_json(url, token:)
        response = execute_get(url, token: token)
        ensure_success!(response, url)
        {
          body: JSON.parse(response.body),
          headers: response.each_header.to_h
        }
      end

      def execute_get(url, token:)
        request = Net::HTTP::Get.new(url)
        request_headers(token).each { |key, value| request[key] = value }
        Net::HTTP.start(url.host, url.port, use_ssl: true) { |http| http.request(request) }
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

        raise Errors::ValidationError, "GitHub API request failed (#{status_code}) for #{url.path}"
      end

      def next_link(link_header)
        return nil unless link_header

        links = link_header.split(',').map(&:strip)
        next_entry = links.find { |entry| entry.end_with?('rel="next"') }
        return nil unless next_entry

        URI(next_entry[/<([^>]+)>/, 1])
      end
    end
  end
end

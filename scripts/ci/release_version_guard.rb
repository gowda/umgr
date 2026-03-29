# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'
require_relative '../../lib/umgr/version'

class ReleaseVersionGuard
  TAG_PATTERN = /\Av(?<version>\d+\.\d+\.\d+(?:[.-][0-9A-Za-z]+)*)\z/

  def self.call
    new.call
  end

  def call
    config = env_config
    tag_version = extract_tag_version(config[:release_tag])
    gem_version = Umgr::VERSION

    ensure_tag_matches_gem_version!(tag_version, gem_version)

    latest_published = latest_published_version(config)
    ensure_progressive_version!(gem_version, latest_published) if latest_published

    puts "Release version guard passed for #{config[:release_tag]} (gem #{gem_version})."
  end

  private

  def env_config
    {
      release_tag: fetch_env('RELEASE_TAG'),
      owner: fetch_env('REPOSITORY_OWNER'),
      owner_type: fetch_env('REPOSITORY_OWNER_TYPE'),
      package_name: fetch_env('PACKAGE_NAME'),
      token: fetch_env('GITHUB_TOKEN')
    }
  end

  def fetch_env(key)
    value = ENV.fetch(key, nil)
    return value unless value.nil? || value.empty?

    raise ArgumentError, "Missing required environment variable: #{key}"
  end

  def extract_tag_version(release_tag)
    match = TAG_PATTERN.match(release_tag)
    raise ArgumentError, "Invalid release tag format: #{release_tag}. Expected: v<version>" unless match

    match[:version]
  end

  def ensure_tag_matches_gem_version!(tag_version, gem_version)
    return if tag_version == gem_version

    raise ArgumentError, "Release tag version #{tag_version} does not match gem version #{gem_version}"
  end

  def latest_published_version(config)
    response = fetch_versions_response_for(config)
    return nil if package_not_found?(response)

    ensure_success_response!(response)
    latest_version_from_body(response.body)
  end

  def fetch_versions_response_for(config)
    uri = URI(endpoint(config[:owner], config[:owner_type], config[:package_name]))
    fetch_versions_response(uri, config[:token])
  end

  def package_not_found?(response)
    response.code.to_i == 404
  end

  def latest_version_from_body(body)
    versions = extract_versions(body)
    return nil if versions.empty?

    versions.map { |version| Gem::Version.new(version) }.max.to_s
  end

  def ensure_success_response!(response)
    return if response.code.to_i == 200

    raise "Failed to fetch published versions (HTTP #{response.code}): #{response.body}"
  end

  def extract_versions(body)
    JSON.parse(body).filter_map { |entry| entry['name'] }
  end

  def fetch_versions_response(uri, token)
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{token}"
    request['Accept'] = 'application/vnd.github+json'
    request['User-Agent'] = 'umgr-release-version-guard'

    Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
  end

  def endpoint(owner, owner_type, package_name)
    encoded_name = URI.encode_www_form_component(package_name)
    case owner_type
    when 'Organization'
      "https://api.github.com/orgs/#{owner}/packages/rubygems/#{encoded_name}/versions?per_page=100"
    else
      "https://api.github.com/users/#{owner}/packages/rubygems/#{encoded_name}/versions?per_page=100"
    end
  end

  def ensure_progressive_version!(gem_version, latest_published)
    current = Gem::Version.new(gem_version)
    latest = Gem::Version.new(latest_published)
    return if current > latest

    raise ArgumentError, "Gem version #{gem_version} must be greater than published #{latest_published}"
  end
end

ReleaseVersionGuard.call

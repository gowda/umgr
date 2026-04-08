# frozen_string_literal: true

require_relative 'lib/umgr/version'

Gem::Specification.new do |spec|
  spec.name = 'umgr'
  spec.version = Umgr::VERSION
  spec.authors = ['Basavanagowda Kanur']
  spec.email = ['basavanagowda@gmail.com']

  spec.summary = 'Declarative account lifecycle management'
  spec.description = 'Manage account state across providers via CLI and API'
  spec.homepage = 'https://github.com/gowda/umgr'
  spec.license = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 3.4.0')
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.glob(%w[
                          Gemfile
                          Rakefile
                          README.md
                          exe/umgr
                          lib/**/*.rb
                          spec/**/*.rb
                          umgr.gemspec
                        ])
  spec.bindir = 'exe'
  spec.executables = ['umgr']
  spec.require_paths = ['lib']

  spec.add_dependency 'faraday-retry', '~> 2.3'
  spec.add_dependency 'octokit', '>= 9.2', '< 11.0'
  spec.add_dependency 'thor', '~> 1.3'
end

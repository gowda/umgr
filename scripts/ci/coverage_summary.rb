# frozen_string_literal: true

require 'json'

last_run_file = 'coverage/.last_run.json'
section_title = ARGV.fetch(0, 'Coverage')

unless File.exist?(last_run_file)
  warn 'coverage summary unavailable'
  exit 0
end

result = JSON.parse(File.read(last_run_file)).fetch('result')
line = format(
  'line: %<percent>.2f%% (%<covered>d/%<total>d)',
  percent: result.fetch('covered_percent'),
  covered: result.fetch('covered_lines'),
  total: result.fetch('total_lines')
)
branch = if result['covered_branches'] && result['total_branches']
           format(
             'branch: %<percent>.2f%% (%<covered>d/%<total>d)',
             percent: result.fetch('covered_branches_percent'),
             covered: result.fetch('covered_branches'),
             total: result.fetch('total_branches')
           )
         else
           'branch: n/a'
         end

puts line
puts branch

File.open(ENV.fetch('GITHUB_STEP_SUMMARY'), 'a') do |file|
  file.puts "### #{section_title}"
  file.puts "- #{line}"
  file.puts "- #{branch}"
end

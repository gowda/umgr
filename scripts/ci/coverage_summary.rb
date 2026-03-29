# frozen_string_literal: true

require 'json'

class CoverageSummaryService
  def initialize(last_run_file)
    @last_run_file = last_run_file
  end

  def call
    unless File.exist?(last_run_file)
      warn 'coverage summary unavailable'
      return
    end

    result = JSON.parse(File.read(last_run_file)).fetch('result')
    line = format_line(result)
    branch = format_branch(result)

    puts line
    puts branch
    append_step_summary(line, branch)
  end

  private

  attr_reader :last_run_file

  def format_line(result)
    return format_line_with_totals(result) if result.key?('covered_percent')
    return format('line: %<percent>.2f%%', percent: result.fetch('line')) if result.key?('line')

    'line: n/a'
  end

  def format_branch(result)
    return format_branch_with_totals(result) if result['covered_branches'] && result['total_branches']
    return format('branch: %<percent>.2f%%', percent: result.fetch('branch')) if result.key?('branch')

    'branch: n/a'
  end

  def format_line_with_totals(result)
    format(
      'line: %<percent>.2f%% (%<covered>d/%<total>d)',
      percent: result.fetch('covered_percent'),
      covered: result.fetch('covered_lines'),
      total: result.fetch('total_lines')
    )
  end

  def format_branch_with_totals(result)
    format(
      'branch: %<percent>.2f%% (%<covered>d/%<total>d)',
      percent: result.fetch('covered_branches_percent'),
      covered: result.fetch('covered_branches'),
      total: result.fetch('total_branches')
    )
  end

  def append_step_summary(line, branch)
    step_summary = ENV.fetch('GITHUB_STEP_SUMMARY', nil)
    return if step_summary.nil? || step_summary.empty?

    section_title = ENV.fetch('COVERAGE_SECTION', 'Coverage')
    File.open(step_summary, 'a') do |file|
      file.puts "### #{section_title}"
      file.puts "- #{line}"
      file.puts "- #{branch}"
    end
  end
end

CoverageSummaryService.new(ARGV.fetch(0)).call

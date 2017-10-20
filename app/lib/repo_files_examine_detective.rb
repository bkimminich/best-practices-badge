# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# CII Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Examine repository files at the top level and in key subdirectories
# (those conventionally used for source and documentation).
# Note that a key precondition is determining how to open repo files.

class RepoFilesExamineDetective < Detective
  INPUTS = [:repo_files].freeze
  OUTPUTS = %i[
    contribution_status license_location_status release_notes_status
  ].freeze

  # Minimum file sizes (in bytes) before they are considered useful.
  # Empty files, in particular, clearly do NOT have enough content.
  NONTRIVIAL_MIN_SIZE = 40
  # Contribution should be longer to be considered useful.
  CONTRIBUTION_MIN_SIZE = 100

  # Given an enumeration of fso info hashes, return the fso info for files
  # that match the regex name pattern and are at least minimum_size in length.
  def files_named(name_pattern, minimum_size)
    @top_level.select do |fso|
      fso['type'] == 'file' && fso['name'].match(name_pattern) &&
        fso['size'] >= minimum_size
    end
  end

  def unmet_result(result_description)
    {
      value: 'Unmet', confidence: 1,
      explanation: "# No #{result_description} file found."
    }
  end

  def met_result(result_description, html_url)
    {
      value: 'Met', confidence: 3,
      explanation:
        "Non-trivial #{result_description} file in repository: " \
        "<#{html_url}>."
    }
  end

  def determine_results(status, name_pattern, minimum_size, result_description)
    found_files = files_named(name_pattern, minimum_size)
    @results[status] =
      if found_files.empty?
        unmet_result result_description
      else
        met_result result_description, found_files.first['html_url']
      end
  end

  # rubocop:disable Metrics/MethodLength
  def analyze(_evidence, current)
    repo_files = current[:repo_files]
    return {} if repo_files.blank?

    @results = {}

    # Top_level is iterable, contains a hash with name, size, type (file|dir).
    @top_level = repo_files.get_info('/')

    # TODO: Look in subdirectories.

    determine_results(
      :contribution_status,
      /\A(contributing|contribute)(\.md|\.txt)?\Z/i,
      CONTRIBUTION_MIN_SIZE, 'contribution'
    )

    determine_results(
      :license_location_status,
      /\A([A-Za-z0-9]+-)?(license|copying)(\.md|\.txt)?\Z/i,
      NONTRIVIAL_MIN_SIZE, 'license location'
    )

    determine_results(
      :release_notes_status,
      /\A(changelog|news)(\.md|\.markdown|\.txt|\.html)?\Z/i,
      NONTRIVIAL_MIN_SIZE, 'release notes'
    )

    @results
  end
end

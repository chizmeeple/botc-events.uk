#!/usr/bin/env ruby
# frozen_string_literal: true

# Validates all _clubs/*.md files for correct YAML frontmatter.
# Requires only Ruby stdlib — no gems needed.
# Usage: ruby script/validate_clubs.rb

require "yaml"
require "date"

clubs_dir = File.expand_path("../source/_clubs", __dir__)

unless Dir.exist?(clubs_dir)
  puts "ERROR: _clubs/ directory not found at #{clubs_dir}"
  exit 1
end

files = Dir.glob(File.join(clubs_dir, "*.md")).sort
if files.empty?
  puts "ERROR: No .md files found in _clubs/"
  exit 1
end

errors = {}
slugs_seen = {}

files.each do |file|
  basename = File.basename(file)
  slug = File.basename(file, ".md")
  file_errors = []

  # Check for duplicate slugs
  if slugs_seen.key?(slug)
    file_errors << "Duplicate slug '#{slug}' (also used by #{slugs_seen[slug]})"
  else
    slugs_seen[slug] = basename
  end

  content = File.read(file)

  # Extract frontmatter
  unless content.match?(/\A---\s*\n/)
    file_errors << "Missing YAML frontmatter (file must start with ---)"
    errors[basename] = file_errors
    next
  end

  parts = content.split(/^---\s*$/, 3)
  if parts.length < 3
    file_errors << "Invalid frontmatter format (missing closing ---)"
    errors[basename] = file_errors
    next
  end

  # Parse YAML
  begin
    data = YAML.safe_load(parts[1], permitted_classes: [Date])
  rescue Psych::SyntaxError => e
    file_errors << "Invalid YAML: #{e.message}"
    errors[basename] = file_errors
    next
  end

  unless data.is_a?(Hash)
    file_errors << "Frontmatter must be a YAML mapping, got #{data.class}"
    errors[basename] = file_errors
    next
  end

  # name: non-empty string
  if !data["name"].is_a?(String) || data["name"].strip.empty?
    file_errors << "name: must be a non-empty string"
  end

  # events: required (top-level event data has moved into events)
  if !data.key?("events")
    file_errors << "events: must be present"
  end

  # Reject deprecated top-level keys (event data belongs under events)
  %w[days time frequency location cost].each do |key|
    if data.key?(key)
      file_errors << "#{key}: must not exist at top level (event data belongs under events)"
    end
  end

  # description: non-empty string
  if !data["description"].is_a?(String) || data["description"].strip.empty?
    file_errors << "description: must be a non-empty string"
  end

  errors[basename] = file_errors unless file_errors.empty?
end

# Report results
if errors.empty?
  puts "All #{files.length} club files are valid."
  unless system("ruby", File.join(__dir__, "validate_event_identity.rb"))
    exit 1
  end

  exit 0
else
  puts "Validation failed!\n\n"
  errors.each do |file, file_errors|
    puts "  #{file}:"
    file_errors.each { |e| puts "    - #{e}" }
    puts
  end
  total = errors.values.sum(&:length)
  puts "#{total} error(s) in #{errors.length} file(s)."
  exit 1
end

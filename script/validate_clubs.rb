#!/usr/bin/env ruby
# frozen_string_literal: true

# Validates all _clubs/*.md files for correct YAML frontmatter.
# Requires only Ruby stdlib — no gems needed.
# Usage: ruby script/validate_clubs.rb

require "yaml"
require "date"

VALID_DAYS = %w[Monday Tuesday Wednesday Thursday Friday Saturday Sunday Various].freeze
LAT_RANGE = (49.0..61.0)
LNG_RANGE = (-9.0..3.0)

clubs_dir = File.expand_path("../_clubs", __dir__)

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

  # days: non-empty array of valid day names
  if !data["days"].is_a?(Array) || data["days"].empty?
    file_errors << "days: must be a non-empty array of day names (got #{data['days'].inspect})"
  elsif data["days"].is_a?(Array)
    data["days"].each_with_index do |d, i|
      unless d.is_a?(String) && VALID_DAYS.include?(d)
        file_errors << "days[#{i}]: must be one of #{VALID_DAYS.join(', ')} (got #{d.inspect})"
      end
    end
  end

  # frequency: non-empty string
  if !data["frequency"].is_a?(String) || data["frequency"].strip.empty?
    file_errors << "frequency: must be a non-empty string"
  end

  # description: non-empty string
  if !data["description"].is_a?(String) || data["description"].strip.empty?
    file_errors << "description: must be a non-empty string"
  end

  # location: hash with required fields
  loc = data["location"]
  if !loc.is_a?(Hash)
    file_errors << "location: must be a mapping with name, address, lat, lng"
  else
    if !loc["name"].is_a?(String) || loc["name"].strip.empty?
      file_errors << "location.name: must be a non-empty string"
    end

    if !loc["address"].is_a?(String) || loc["address"].strip.empty?
      file_errors << "location.address: must be a non-empty string"
    end

    if !loc["lat"].is_a?(Numeric)
      file_errors << "location.lat: must be a number (got #{loc['lat'].inspect})"
    elsif !LAT_RANGE.cover?(loc["lat"])
      file_errors << "location.lat: must be between #{LAT_RANGE.min} and #{LAT_RANGE.max} (got #{loc['lat']})"
    end

    if !loc["lng"].is_a?(Numeric)
      file_errors << "location.lng: must be a number (got #{loc['lng'].inspect})"
    elsif !LNG_RANGE.cover?(loc["lng"])
      file_errors << "location.lng: must be between #{LNG_RANGE.min} and #{LNG_RANGE.max} (got #{loc['lng']})"
    end
  end

  errors[basename] = file_errors unless file_errors.empty?
end

# Report results
if errors.empty?
  puts "All #{files.length} club files are valid."
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

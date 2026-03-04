#!/usr/bin/env ruby
# frozen_string_literal: true

# Validates _site/api/clubs.json produced by Jekyll build.
# Catches invalid JSON (e.g. from missing lat/lng producing "lat": ,).
# Requires only Ruby stdlib — no gems needed.
# Usage: ruby script/validate_clubs_json.rb [path]
#        (default path: _site/api/clubs.json)

require "json"

path = ARGV[0] || File.expand_path("../_site/api/clubs.json", __dir__)

unless File.exist?(path)
  puts "ERROR: #{path} not found (run Jekyll build first)"
  exit 1
end

begin
  clubs = JSON.parse(File.read(path))
rescue JSON::ParserError => e
  puts "ERROR: Invalid JSON in #{path}: #{e.message}"
  exit 1
end

unless clubs.is_a?(Array)
  puts "ERROR: Expected an array, got #{clubs.class}"
  exit 1
end

required_keys = %w[name slug url description]
errors = []

clubs.each_with_index do |club, i|
  required_keys.each do |key|
    if club[key].nil?
      errors << "Club ##{i} (#{club["name"] || "unknown"}): missing \"#{key}\""
    end
  end
end

if errors.any?
  puts "clubs.json validation failed!\n\n"
  errors.each { |e| puts "  - #{e}" }
  exit 1
end

puts "clubs.json is valid: #{clubs.length} clubs with all required fields."

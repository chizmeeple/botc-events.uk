#!/usr/bin/env ruby
# frozen_string_literal: true

# Validates _data/rendered_special_events.json produced by
# script/generate_special_events.rb.
#
# Usage:
#   ruby script/validate_special_events.rb [path]
#   (default path: source/_data/rendered_special_events.json)

require "json"

path = ARGV[0] || File.expand_path("../source/_data/rendered_special_events.json", __dir__)

unless File.exist?(path)
  puts "ERROR: #{path} not found (run script/generate_special_events.rb first)"
  exit 1
end

begin
  data = JSON.parse(File.read(path))
rescue JSON::ParserError => e
  puts "ERROR: Invalid JSON in #{path}: #{e.message}"
  exit 1
end

unless data.is_a?(Hash)
  puts "ERROR: Expected an object, got #{data.class}"
  exit 1
end

unless data.key?("generated_at")
  puts "ERROR: missing \"generated_at\""
  exit 1
end

map_slugs = data["map_slugs"]
unless map_slugs.is_a?(Array)
  puts "ERROR: \"map_slugs\" must be an array, got #{map_slugs.class}"
  exit 1
end

required_all_occurrence_keys = %w[eventname start_time end_time location cost]
required_location_keys = %w[name address lat lng]

errors = []

by_slug = data["by_slug"]
unless by_slug.is_a?(Hash)
  puts "ERROR: \"by_slug\" must be an object, got #{by_slug.class}"
  exit 1
end

unless map_slugs.sort == by_slug.keys.sort
  puts "ERROR: \"map_slugs\" must list the same slugs as \"by_slug\" keys"
  exit 1
end

all_upcoming = data["all_upcoming"]
unless all_upcoming.is_a?(Array)
  puts "ERROR: \"all_upcoming\" must be an array, got #{all_upcoming.class}"
  exit 1
end

all_upcoming.each_with_index do |evt, i|
  unless evt.is_a?(Hash)
    errors << "all_upcoming[#{i}]: expected object, got #{evt.class}"
    next
  end

  required_all_occurrence_keys.each do |key|
    if evt[key].nil?
      errors << "all_upcoming[#{i}] missing \"#{key}\""
    end
  end

  loc = evt["location"]
  if loc.is_a?(Hash)
    required_location_keys.each do |key|
      if loc[key].nil?
        errors << "all_upcoming[#{i}] location missing \"#{key}\""
      end
    end
  else
    errors << "all_upcoming[#{i}] missing location object"
  end
end

by_slug.each do |slug, info|
  next unless info.is_a?(Hash)

  required_slug_keys = %w[eventname start_time end_time locations cost]
  required_slug_keys.each do |key|
    if info[key].nil?
      errors << "#{slug} missing \"#{key}\""
    end
  end

  locs = info["locations"]
  unless locs.is_a?(Array)
    errors << "#{slug} missing \"locations\" array"
    next
  end

  locs.each_with_index do |loc, idx|
    unless loc.is_a?(Hash)
      errors << "#{slug} locations[#{idx}] expected object, got #{loc.class}"
      next
    end

    required_location_keys.each do |key|
      if loc[key].nil?
        errors << "#{slug} locations[#{idx}] missing \"#{key}\""
      end
    end
    if loc["parking"] && !loc["parking"].is_a?(Array)
      errors << "#{slug} locations[#{idx}] \"parking\" must be an array"
    end
  end
end

if errors.any?
  puts "rendered_special_events.json validation failed!\n\n"
  errors.each { |e| puts "  - #{e}" }
  exit 1
end

puts "rendered_special_events.json is valid: #{by_slug.size} special events."


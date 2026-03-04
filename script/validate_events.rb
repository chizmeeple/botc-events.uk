#!/usr/bin/env ruby
# frozen_string_literal: true

# Validates _data/rendered_events.json produced by script/generate_events.rb.
# Requires only Ruby stdlib — no gems needed.
# Usage: ruby script/validate_events.rb [path]
#        (default path: _data/rendered_events.json)

require "json"

path = ARGV[0] || File.expand_path("../source/_data/rendered_events.json", __dir__)

unless File.exist?(path)
  puts "ERROR: #{path} not found (run script/generate_events.rb first)"
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

by_slug = data["by_slug"]
unless by_slug.is_a?(Hash)
  puts "ERROR: \"by_slug\" must be an object, got #{by_slug.class}"
  exit 1
end

required_event_keys = %w[eventname start_time location signup cost]
required_location_keys = %w[name address lat lng]
errors = []

by_slug.each do |slug, club_data|
  next unless club_data.is_a?(Hash)

  unless club_data.key?("club_name")
    errors << "#{slug}: missing \"club_name\""
  end

  upcoming = club_data["upcoming"]
  next unless upcoming.is_a?(Array)

  upcoming.each_with_index do |evt, i|
    required_event_keys.each do |key|
      if evt[key].nil?
        errors << "#{slug} event ##{i}: missing \"#{key}\""
      end
    end

    loc = evt["location"]
    if loc.is_a?(Hash)
      required_location_keys.each do |key|
        if loc[key].nil?
          errors << "#{slug} event ##{i}: missing \"location.#{key}\""
        end
      end
    end
  end
end

if errors.any?
  puts "rendered_events.json validation failed!\n\n"
  errors.each { |e| puts "  - #{e}" }
  exit 1
end

puts "rendered_events.json is valid: #{by_slug.size} clubs with required event fields."

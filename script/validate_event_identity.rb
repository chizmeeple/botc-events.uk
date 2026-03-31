#!/usr/bin/env ruby
# frozen_string_literal: true

# Validates canonical identity fields in source YAML (clubs + special events).
# Run before generate_events.rb / generate_special_events.rb.

require "yaml"
require "date"

ID_PART = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

def extract_frontmatter(path)
  content = File.read(path)
  return nil unless content.match?(/\A---\s*\n/)

  parts = content.split(/^---\s*$/, 3)
  return nil if parts.length < 3

  YAML.safe_load(parts[1], permitted_classes: [Date])
rescue Psych::SyntaxError
  nil
end

def validate_id_string!(label, value)
  return if value.is_a?(String) && !value.strip.empty? && ID_PART.match?(value.strip)

  puts "ERROR: #{label} must be a non-empty string matching #{ID_PART.inspect}, got #{value.inspect}"
  exit 1
end

errors = []
root = File.expand_path("..", __dir__)
clubs_dir = File.join(root, "source", "_clubs")
special_dir = File.join(root, "source", "_special_events")

group_ids_global = {}

# --- Clubs ---
Dir.glob(File.join(clubs_dir, "*.md")).sort.each do |path|
  slug = File.basename(path, ".md")
  data = extract_frontmatter(path)
  next unless data.is_a?(Hash)

  events = data["events"]
  next unless events.is_a?(Hash)

  recurring = events["recurring"]
  adhoc = events["adhoc"]
  next unless (recurring.is_a?(Array) && recurring.any?) || (adhoc.is_a?(Array) && adhoc.any?)

  gid = data["group_id"].to_s.strip
  gid = slug if gid.empty?
  validate_id_string!("group_id in #{slug}.md", gid)

  if group_ids_global[gid]
    errors << "Duplicate group_id #{gid.inspect} (#{slug}.md and #{group_ids_global[gid]})"
  else
    group_ids_global[gid] = slug
  end

  event_ids = []
  special_ids = []

  (recurring || []).each do |ev|
    next unless ev.is_a?(Hash)

    eid = ev["event_id"]
    validate_id_string!("events.recurring[].event_id in #{slug}.md (#{ev['eventname']})", eid)
    event_ids << eid.strip
  end

  (adhoc || []).each do |ev|
    next unless ev.is_a?(Hash)

    sid = ev["special_event_id"]
    validate_id_string!("events.adhoc[].special_event_id in #{slug}.md (#{ev['eventname']})", sid)
    special_ids << sid.strip
  end

  dups = event_ids.group_by(&:itself).select { |_, v| v.size > 1 }.keys
  dups.each { |id| errors << "#{slug}.md: duplicate event_id #{id.inspect} in recurring" }

  dups = special_ids.group_by(&:itself).select { |_, v| v.size > 1 }.keys
  dups.each { |id| errors << "#{slug}.md: duplicate special_event_id #{id.inspect} in adhoc" }

  overlap = event_ids & special_ids
  overlap.each do |id|
    errors << "#{slug}.md: event_id and special_event_id both use #{id.inspect} (must be disjoint)"
  end
end

# --- Special events ---
if Dir.exist?(special_dir)
  Dir.glob(File.join(special_dir, "*.md")).sort.each do |path|
    slug = File.basename(path, ".md")
    data = extract_frontmatter(path)
    next unless data.is_a?(Hash)

    special_list = data.dig("events", "special")
    next unless special_list.is_a?(Array) && special_list.any?

    gid = data["group_id"]
    validate_id_string!("group_id in _special_events/#{slug}.md", gid)
    gid = gid.strip

    if group_ids_global[gid]
      errors << "Duplicate group_id #{gid.inspect} (_special_events/#{slug}.md and #{group_ids_global[gid]})"
    else
      group_ids_global[gid] = "special:#{slug}"
    end

    special_list.each do |ev|
      next unless ev.is_a?(Hash)

      sid = ev["special_event_id"]
      validate_id_string!("events.special[].special_event_id in _special_events/#{slug}.md", sid)
    end

    ids = special_list.map { |ev| ev.is_a?(Hash) ? ev["special_event_id"]&.strip : nil }.compact
    dups = ids.group_by(&:itself).select { |_, v| v.size > 1 }.keys
    dups.each { |id| errors << "_special_events/#{slug}.md: duplicate special_event_id #{id.inspect}" }
  end
end

if errors.any?
  puts "Event identity validation failed!\n\n"
  errors.each { |e| puts "  - #{e}" }
  exit 1
end

puts "Event identity validation passed (#{group_ids_global.size} group_id(s) in source data)."

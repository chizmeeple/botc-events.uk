#!/usr/bin/env ruby
# frozen_string_literal: true

# One-off migration (already applied in this repo): add group_id, event_id, and
# special_event_id to club and special-event source files. Safe to re-run: only
# fills missing keys. Prefer editing YAML by hand for new groups.

require "date"
require "yaml"

def extract_parts(path)
  content = File.read(path)
  return nil unless content.match?(/\A---\s*\n/)

  parts = content.split(/^---\s*$/, 3)
  return nil if parts.length < 3

  [parts[0], parts[1], parts[2]]
end

def slugify(str)
  s = str.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-+|-+$/, "").squeeze("-")
  s.empty? ? "event" : s
end

def assign_recurring_ids!(events)
  list = events["recurring"]
  return unless list.is_a?(Array)

  seen = Hash.new(0)
  list.each do |ev|
    next unless ev.is_a?(Hash)

    base = slugify(ev["eventname"])
    seen[base] += 1
    key = seen[base] > 1 ? "#{base}-#{seen[base]}" : base
    ev["event_id"] ||= key
  end
end

def assign_adhoc_ids!(events)
  list = events["adhoc"]
  return unless list.is_a?(Array)

  seen = Hash.new(0)
  list.each do |ev|
    next unless ev.is_a?(Hash)

    d = ev["startdate"]
    dstr =
      if d.is_a?(Date)
        d.strftime("%Y%m%d")
      else
        Date.parse(d.to_s).strftime("%Y%m%d")
      end
    base = "#{slugify(ev['eventname'])}-#{dstr}"
    seen[base] += 1
    key = seen[base] > 1 ? "#{base}-#{seen[base]}" : base
    ev["special_event_id"] ||= key
  end
end

def migrate_club(path)
  slug = File.basename(path, ".md")
  parts = extract_parts(path)
  return unless parts

  data = YAML.safe_load(parts[1], permitted_classes: [Date])
  return unless data.is_a?(Hash)

  events = data["events"]
  return unless events.is_a?(Hash)

  recurring = events["recurring"]
  adhoc = events["adhoc"]
  return unless (recurring.is_a?(Array) && recurring.any?) || (adhoc.is_a?(Array) && adhoc.any?)

  data["group_id"] ||= slug
  assign_recurring_ids!(events)
  assign_adhoc_ids!(events)

  File.write(path, "#{YAML.dump(data).rstrip}\n---\n#{parts[2]}")
  true
end

def migrate_special(path)
  slug = File.basename(path, ".md")
  parts = extract_parts(path)
  return unless parts

  data = YAML.safe_load(parts[1], permitted_classes: [Date])
  return unless data.is_a?(Hash)

  special_list = data.dig("events", "special")
  return unless special_list.is_a?(Array) && special_list.any?

  data["group_id"] ||= slug
  n = 0
  special_list.each do |ev|
    next unless ev.is_a?(Hash)

    n += 1
    ev["special_event_id"] ||= (n == 1 ? "main" : "main-#{n}")
  end

  File.write(path, "#{YAML.dump(data).rstrip}\n---\n#{parts[2]}")
  true
end

root = File.expand_path("..", __dir__)
Dir.glob(File.join(root, "source", "_clubs", "*.md")).sort.each do |path|
  migrate_club(path)
end

Dir.glob(File.join(root, "source", "_special_events", "*.md")).sort.each do |path|
  migrate_special(path)
end

puts "Migration finished."

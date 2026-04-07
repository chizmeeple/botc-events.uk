#!/usr/bin/env ruby
# frozen_string_literal: true

# Builds source/calendar/events.ics from rendered_events.json and
# rendered_special_events.json. UIDs use CalendarUid only:
# - Recurring series: one VEVENT per (group_id, event_id) with RRULE (stable UID).
# - One-off (club adhoc + special): one VEVENT per occurrence.

require "json"
require "icalendar"
require "time"

require_relative "calendar_uid"

SITE_URL = "https://botc-events.uk"
CALENDAR_PREFIX = "🕯️🎭"
LONDON_TZID = "Europe/London"

def calendar_summary(text)
  t = text.to_s.strip
  return CALENDAR_PREFIX if t.empty?
  return t if t.start_with?(CALENDAR_PREFIX)

  "#{CALENDAR_PREFIX} #{t}"
end

def club_source_file_hint(row)
  slug = row["slug"].to_s.strip
  return "" if slug.empty?

  " — source: source/_clubs/#{slug}.md"
end

def load_json(path)
  JSON.parse(File.read(path))
rescue Errno::ENOENT
  nil
end

def row_uid(row)
  gid = row["group_id"].to_s.strip
  eid = row["event_id"]
  sid = row["special_event_id"]
  CalendarUid.ical_uid(group_id: gid, event_id: eid, special_event_id: sid)
end

def ical_london_datetime(time)
  # Emit Europe/London wall-clock time (no trailing "Z"), so calendar clients
  # don't reinterpret local event times as UTC.
  Icalendar::Values::DateTime.new(time.strftime("%Y%m%dT%H%M%S"), "tzid" => LONDON_TZID)
end

def build_club_oneoff_event(row, feed_updated)
  dtstart = Time.iso8601(row["start_time"].to_s)
  end_time_missing = row["end_time"].to_s.strip.empty?
  dtend = end_time_missing ? dtstart + 7200 : Time.iso8601(row["end_time"].to_s)

  event = Icalendar::Event.new
  event.dtstart = ical_london_datetime(dtstart)
  event.dtend = ical_london_datetime(dtend)

  based_in = row["based_in"].to_s.strip
  loc_name = row["location"].is_a?(Hash) ? row["location"]["name"].to_s.strip : ""
  event.summary = calendar_summary([based_in, loc_name].reject(&:empty?).join(" - "))

  event.uid = row_uid(row)
  event.dtstamp = Icalendar::Values::DateTime.new(feed_updated, "tzid" => "UTC")
  event.last_modified = feed_updated

  parts = []
  parts << row["club_name"].to_s if row["club_name"].to_s.strip != ""
  if row["location"].is_a?(Hash) && row["location"]["address"].to_s.strip != ""
    parts << row["location"]["address"]
  end
  event.location = parts.join(", ") if parts.any?

  desc_parts = []
  desc_parts << row["club_name"].to_s if row["club_name"].to_s.strip != ""
  desc_parts << "Cost: #{row["cost"]}" if row["cost"].to_s.strip != ""
  desc_parts << "Sign up: #{row["signup"]}" if row["signup"].to_s.strip != ""
  slug = row["slug"].to_s.strip
  desc_parts << "#{SITE_URL}/clubs/#{slug}/" if slug != ""
  desc_parts << "End time estimated" if end_time_missing
  event.description = desc_parts.join("\n\n") if desc_parts.any?

  if row["signup"].to_s.strip != ""
    event.url = row["signup"]
  elsif slug != ""
    event.url = "#{SITE_URL}/clubs/#{slug}/"
  end

  event
end

def build_recurring_series_event(rows, feed_updated)
  rows = rows.sort_by { |r| r["start_time"].to_s }
  first = rows.first
  rrule = first["rrule"].to_s.strip
  if rrule.empty?
    warn "ERROR: missing rrule for recurring series #{first["group_id"]}.#{first["event_id"]}#{club_source_file_hint(first)}"
    exit 1
  end

  dtstart = Time.iso8601(first["start_time"].to_s)
  end_time_missing = first["end_time"].to_s.strip.empty?
  dtend = end_time_missing ? dtstart + 7200 : Time.iso8601(first["end_time"].to_s)

  event = Icalendar::Event.new
  event.dtstart = ical_london_datetime(dtstart)
  event.dtend = ical_london_datetime(dtend)
  event.rrule = rrule

  based_in = first["based_in"].to_s.strip
  loc_name = first["location"].is_a?(Hash) ? first["location"]["name"].to_s.strip : ""
  event.summary = calendar_summary([based_in, loc_name].reject(&:empty?).join(" - "))

  event.uid = CalendarUid.ical_uid(group_id: first["group_id"], event_id: first["event_id"])
  event.dtstamp = Icalendar::Values::DateTime.new(feed_updated, "tzid" => "UTC")
  event.last_modified = feed_updated

  parts = []
  parts << first["club_name"].to_s if first["club_name"].to_s.strip != ""
  if first["location"].is_a?(Hash) && first["location"]["address"].to_s.strip != ""
    parts << first["location"]["address"]
  end
  event.location = parts.join(", ") if parts.any?

  desc_parts = []
  desc_parts << first["club_name"].to_s if first["club_name"].to_s.strip != ""
  desc_parts << "Cost: #{first["cost"]}" if first["cost"].to_s.strip != ""
  desc_parts << "Sign up: #{first["signup"]}" if first["signup"].to_s.strip != ""
  slug = first["slug"].to_s.strip
  desc_parts << "#{SITE_URL}/clubs/#{slug}/" if slug != ""
  desc_parts << "End time estimated" if end_time_missing
  event.description = desc_parts.join("\n\n") if desc_parts.any?

  if first["signup"].to_s.strip != ""
    event.url = first["signup"]
  elsif slug != ""
    event.url = "#{SITE_URL}/clubs/#{slug}/"
  end

  event
end

def build_special_ics_event(row, feed_updated)
  dtstart = Time.iso8601(row["start_time"].to_s)
  end_time_missing = row["end_time"].to_s.strip.empty?
  dtend = end_time_missing ? dtstart + 7200 : Time.iso8601(row["end_time"].to_s)

  event = Icalendar::Event.new
  event.dtstart = ical_london_datetime(dtstart)
  event.dtend = ical_london_datetime(dtend)

  based_in = row["based_in"].to_s.strip
  loc_name = row["location"].is_a?(Hash) ? row["location"]["name"].to_s.strip : ""
  event.summary = calendar_summary([based_in, loc_name].reject(&:empty?).join(" - "))

  event.uid = row_uid(row)
  event.dtstamp = Icalendar::Values::DateTime.new(feed_updated, "tzid" => "UTC")
  event.last_modified = feed_updated

  parts = []
  name = row["eventname"].to_s.strip
  parts << name if name != ""
  if row["location"].is_a?(Hash) && row["location"]["address"].to_s.strip != ""
    parts << row["location"]["address"]
  end
  event.location = parts.join(", ") if parts.any?

  desc_parts = []
  desc_parts << row["eventname"].to_s if row["eventname"].to_s.strip != ""
  desc_parts << "Cost: #{row["cost"]}" if row["cost"].to_s.strip != ""
  slug = row["slug"].to_s.strip
  desc_parts << "#{SITE_URL}/special/#{slug}/" if slug != ""
  desc_parts << "End time estimated" if end_time_missing
  event.description = desc_parts.join("\n\n") if desc_parts.any?

  event.url = "#{SITE_URL}/special/#{slug}/" if slug != ""

  event
end

def main
  root = File.expand_path("..", __dir__)
  data_dir = File.join(root, "source", "_data")
  events_path = File.join(data_dir, "rendered_events.json")
  special_path = File.join(data_dir, "rendered_special_events.json")

  club_data = load_json(events_path)
  unless club_data.is_a?(Hash)
    warn "ERROR: #{events_path} missing or invalid (run script/generate_events.rb first)"
    exit 1
  end

  generated_at = club_data["generated_at"].to_s
  feed_updated = Time.parse(generated_at)

  club_rows = club_data["all_upcoming"]
  club_rows = [] unless club_rows.is_a?(Array)

  special_data = load_json(special_path)
  special_rows = special_data.is_a?(Hash) && special_data["all_upcoming"].is_a?(Array) ? special_data["all_upcoming"] : []

  recurring_groups = {}
  adhoc_rows = []

  club_rows.each do |row|
    next unless row.is_a?(Hash)

    eid = row["event_id"].to_s.strip
    sid = row["special_event_id"].to_s.strip
    if !eid.empty?
      key = [row["group_id"].to_s.strip, eid]
      (recurring_groups[key] ||= []) << row
    elsif !sid.empty?
      adhoc_rows << row
    else
      warn "ERROR: club all_upcoming row missing event_id and special_event_id"
      exit 1
    end
  end

  emit_queue = []

  recurring_groups.each_value do |rows|
    rr = rows.map { |r| r["rrule"].to_s.strip }.uniq
    if rr.size > 1
      r0 = rows.first
      g = r0["group_id"]
      e = r0["event_id"]
      warn "ERROR: inconsistent rrule for series #{g}.#{e}#{club_source_file_hint(r0)}"
      exit 1
    end
    emit_queue << { kind: :recurring_series, rows: rows }
  end

  adhoc_rows.each { |r| emit_queue << { kind: :club_adhoc, row: r } }
  special_rows.each { |r| emit_queue << { kind: :special, row: r } } if special_rows.is_a?(Array)

  emit_queue.sort_by! do |q|
    case q[:kind]
    when :recurring_series
      q[:rows].map { |r| r["start_time"].to_s }.min
    when :club_adhoc, :special
      q[:row]["start_time"].to_s
    end
  end

  uids_seen = {}
  emit_queue.each do |q|
    uid = case q[:kind]
          when :recurring_series
            first = q[:rows].first
            CalendarUid.ical_uid(group_id: first["group_id"], event_id: first["event_id"])
          when :club_adhoc
            row_uid(q[:row])
          when :special
            row_uid(q[:row])
          end
    if uids_seen[uid]
      warn "ERROR: duplicate ICS UID #{uid.inspect}"
      exit 1
    end
    uids_seen[uid] = true
  end

  calendar = Icalendar::Calendar.new
  calendar.prodid = "-//BOTC Events UK//botc-events.uk//EN"
  calendar.version = "2.0"
  calendar.x_wr_calname = "BOTC Events UK"
  calendar.append_custom_property("X-WR-CALDESC", "Blood on the Clocktower events across the UK")
  calendar.append_custom_property("X-WR-TIMEZONE", "Europe/London")
  calendar.append_custom_property("REFRESH-INTERVAL;VALUE=DURATION", "PT1H")

  emit_queue.each do |q|
    ev = case q[:kind]
         when :recurring_series
           build_recurring_series_event(q[:rows], feed_updated)
         when :club_adhoc
           build_club_oneoff_event(q[:row], feed_updated)
         when :special
           build_special_ics_event(q[:row], feed_updated)
         end
    calendar.add_event(ev)
  end

  calendar_dir = File.join(root, "source", "calendar")
  Dir.mkdir(calendar_dir) unless Dir.exist?(calendar_dir)
  ics_path = File.join(calendar_dir, "events.ics")
  File.write(ics_path, calendar.to_ical)
  warn "Wrote #{ics_path} (#{emit_queue.size} calendar components)"
end

main if __FILE__ == $PROGRAM_NAME

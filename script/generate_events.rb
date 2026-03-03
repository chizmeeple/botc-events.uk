#!/usr/bin/env ruby
# frozen_string_literal: true

# Generates _data/rendered_events.json from events.recurring in _clubs/*.md.
# Run before Jekyll build (e.g. in deploy workflow or locally before jekyll serve).
# Uses Europe/London for all times. Output is used by the club layout and
# future "all upcoming events" pages.

require "date"
require "json"
require "time"
require "tzinfo"
require "yaml"

TZ = TZInfo::Timezone.get("Europe/London")
LOOKAHEAD_DAYS = 180
UPCOMING_PER_CLUB = 4
ALL_UPCOMING_LIMIT = 100

WDAY_MAP = {
  "MO" => 1, "TU" => 2, "WE" => 3, "TH" => 4,
  "FR" => 5, "SA" => 6, "SU" => 0,
}.freeze

def parse_rrule(rrule)
  (rrule || "").split(";").each_with_object({}) do |part, h|
    k, v = part.split("=", 2)
    h[k] = v if k && v
  end
end

def parse_hhmm(val)
  str = val.to_s
  return [0, 0] if str.empty?
  hour = str.length >= 2 ? str[0..1].to_i : 0
  min  = str.length >= 4 ? str[-2..].to_i : 0
  [hour, min]
end

def nth_wday_of_month(year, month, wday, n)
  if n > 0
    first = Date.new(year, month, 1)
    delta = (wday - first.wday) % 7
    date = first + delta + 7 * (n - 1)
    date.month == month ? date : nil
  else
    last = Date.new(year, month, -1)
    delta = (last.wday - wday) % 7
    date = last - delta - 7 * (n.abs - 1)
    date.month == month ? date : nil
  end
end

def expand_recurrence(startdate, starttime, endtime, rrule, now, range_end)
  parts = parse_rrule(rrule)
  freq = parts["FREQ"]
  byday = (parts["BYDAY"] || "").split(",")
  return [] unless freq == "MONTHLY" && !byday.empty?

  start_date = startdate.is_a?(Date) ? startdate : Date.parse(startdate.to_s)
  shour, smin = parse_hhmm(starttime)
  ehour, emin = parse_hhmm(endtime) if endtime

  occurrences = []
  current = [start_date, now.to_date].max
  last_date = range_end.to_date

  while current <= last_date
    year = current.year
    month = current.month

    byday.each do |token|
      m = token.match(/\A(-?\d)?([A-Z]{2})\z/)
      next unless m
      n = (m[1] || "1").to_i
      wday = WDAY_MAP[m[2]]
      next unless wday

      occ_date = nth_wday_of_month(year, month, wday, n)
      next unless occ_date
      next if occ_date < start_date || occ_date < now.to_date || occ_date > last_date

      start_t = TZ.local_time(occ_date.year, occ_date.month, occ_date.day, shour, smin, 0)
      end_t = if endtime
                TZ.local_time(occ_date.year, occ_date.month, occ_date.day, ehour, emin, 0)
              end

      occurrences << [start_t, end_t]
    end

    current = Date.new(year, month, 1) >> 1
  end

  occurrences.sort_by(&:first)
rescue ArgumentError
  []
end

def collect_upcoming(recurring_list, now, range_end, limit: nil)
  all = []

  recurring_list.each do |ev|
    eventname = ev["eventname"]
    rrule = ev["rrule"]
    next unless eventname.is_a?(String) && rrule.is_a?(String) && !rrule.strip.empty?

    startdate = ev["startdate"]
    starttime = ev["starttime"]
    endtime = ev["endtime"]
    location = ev["location"].is_a?(Hash) ? ev["location"] : {}

    occurrences = expand_recurrence(startdate, starttime, endtime, rrule, now, range_end)

    signup = ev["signup"].to_s.strip
    signup = nil if signup.empty?

    occurrences.each do |start_t, end_t|
      next if start_t < now
      occ = {
        "eventname" => eventname,
        "start_time" => start_t.iso8601,
        "end_time" => end_t&.iso8601,
        "location" => location,
      }
      occ["signup"] = signup if signup
      all << occ
    end
  end

  all.sort_by! { |o| o["start_time"] }
  all = all.take(limit) if limit
  all
end

def extract_frontmatter(path)
  content = File.read(path)
  return nil unless content.match?(/\A---\s*\n/)
  parts = content.split(/^---\s*$/, 3)
  return nil if parts.length < 3
  YAML.safe_load(parts[1], permitted_classes: [Date])
rescue Psych::SyntaxError
  nil
end

def main
  root = File.expand_path("..", __dir__)
  clubs_dir = File.join(root, "_clubs")
  data_dir = File.join(root, "_data")
  out_path = File.join(data_dir, "rendered_events.json")

  Dir.mkdir(data_dir) unless Dir.exist?(data_dir)

  now = TZ.now
  range_end = now + (LOOKAHEAD_DAYS * 24 * 60 * 60)

  by_slug = {}
  all_upcoming = []

  Dir.glob(File.join(clubs_dir, "*.md")).sort.each do |path|
    slug = File.basename(path, ".md")
    data = extract_frontmatter(path)
    next unless data.is_a?(Hash)

    events = data["events"]
    next unless events.is_a?(Hash)

    recurring = events["recurring"]
    next unless recurring.is_a?(Array) && recurring.any?

    club_name = data["name"].to_s

    upcoming = collect_upcoming(recurring, now, range_end, limit: UPCOMING_PER_CLUB)
    next if upcoming.empty?

    by_slug[slug] = {
      "club_name" => club_name,
      "upcoming" => upcoming,
    }

    upcoming.each do |occ|
      all_upcoming << {
        "slug" => slug,
        "club_name" => club_name,
        "eventname" => occ["eventname"],
        "start_time" => occ["start_time"],
        "end_time" => occ["end_time"],
        "location" => occ["location"],
      }
    end
  end

  all_upcoming.sort_by! { |o| o["start_time"] }
  all_upcoming = all_upcoming.take(ALL_UPCOMING_LIMIT)

  payload = {
    "generated_at" => now.utc.iso8601,
    "by_slug" => by_slug,
    "all_upcoming" => all_upcoming,
  }

  File.write(out_path, JSON.pretty_generate(payload))
  warn "Wrote #{out_path} (#{by_slug.size} clubs, #{all_upcoming.size} events in all_upcoming)"
end

main if __FILE__ == $PROGRAM_NAME

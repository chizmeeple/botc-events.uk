#!/usr/bin/env ruby
# frozen_string_literal: true

# Generates _data/rendered_events.json from events.recurring and events.adhoc in _clubs/*.md.
# Run before Jekyll build (e.g. in deploy workflow or locally before jekyll serve).
# Uses Europe/London for all times. Output is used by the club layout and
# future "all upcoming events" pages. The combined ICS feed is built by
# script/generate_calendar_ics.rb (canonical UIDs from group_id + event_id / special_event_id).

require "date"
require "json"
require "icalendar"
require "set"
require "time"
require "ice_cube"
require "icalendar/recurrence"
require "tzinfo"
require "yaml"

SITE_URL = "https://botc-events.uk"

TZ = TZInfo::Timezone.get("Europe/London")
LOOKAHEAD_DAYS = 180
UPCOMING_PER_CLUB = 6
ALL_UPCOMING_LIMIT = 500
EARTH_RADIUS_M = 6_371_000

DAY_ABBREV = { "MO" => "Monday", "TU" => "Tuesday", "WE" => "Wednesday",
               "TH" => "Thursday", "FR" => "Friday", "SA" => "Saturday",
               "SU" => "Sunday" }.freeze
DAY_ORDER = %w[Monday Tuesday Wednesday Thursday Friday Saturday Sunday].freeze

def haversine_distance_m(lat1, lng1, lat2, lng2)
  lat1_rad = lat1.to_f * Math::PI / 180.0
  lng1_rad = lng1.to_f * Math::PI / 180.0
  lat2_rad = lat2.to_f * Math::PI / 180.0
  lng2_rad = lng2.to_f * Math::PI / 180.0

  dlat = lat2_rad - lat1_rad
  dlng = lng2_rad - lng1_rad

  a = Math.sin(dlat / 2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlng / 2)**2
  c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  EARTH_RADIUS_M * c
end

def days_from_rrule(rrule)
  return [] unless rrule.is_a?(String) && !rrule.strip.empty?
  match = rrule.match(/BYDAY=([A-Z0-9,-]+)/i)
  return [] unless match
  match[1].split(",").map do |part|
    abbrev = part.gsub(/\A-?\d+/, "")
    DAY_ABBREV[abbrev]
  end.compact
end

def day_from_date(date)
  return nil unless date
  d = date.is_a?(Date) ? date : Date.parse(date.to_s)
  d.strftime("%A")
end

def collect_event_days(recurring_list, adhoc_list)
  days = Set.new
  (recurring_list || []).each do |ev|
    days_from_rrule(ev["rrule"]).each { |d| days << d }
  end
  (adhoc_list || []).each do |ev|
    d = day_from_date(ev["startdate"])
    days << d if d
  end
  days.to_a.sort_by { |d| DAY_ORDER.index(d) || 99 }
end

def rrule_to_frequency(rrule)
  return nil unless rrule.is_a?(String) && !rrule.strip.empty?

  IceCube::Rule.from_ical(rrule).to_s
rescue ArgumentError, StandardError
  nil
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
  expand_recurrence_with_icalendar(startdate, starttime, endtime, rrule, now, range_end)
end

def expand_recurrence_with_icalendar(startdate, starttime, endtime, rrule, now, range_end)
  return [] unless rrule.is_a?(String) && !rrule.strip.empty?

  start_date = startdate.is_a?(Date) ? startdate : Date.parse(startdate.to_s)
  shour, smin = parse_hhmm(starttime)
  ehour, emin = parse_hhmm(endtime) if endtime

  dtstart = TZ.local_time(start_date.year, start_date.month, start_date.day, shour, smin, 0)
  dtend = if endtime
            TZ.local_time(start_date.year, start_date.month, start_date.day, ehour, emin, 0)
          end

  ics_lines = []
  ics_lines << "BEGIN:VCALENDAR"
  ics_lines << "VERSION:2.0"
  ics_lines << "BEGIN:VEVENT"
  ics_lines << "DTSTART:#{dtstart.strftime('%Y%m%dT%H%M%S')}"
  ics_lines << "DTEND:#{dtend.strftime('%Y%m%dT%H%M%S')}" if dtend
  ics_lines << "RRULE:#{rrule}"
  ics_lines << "END:VEVENT"
  ics_lines << "END:VCALENDAR"
  ics = ics_lines.join("\n")

  cal = Icalendar::Calendar.parse(ics).first
  event = cal.events.first
  return [] unless event

  occs = event.occurrences_between(now, range_end)
  occs.map do |occ|
    s = occ.start_time
    e = occ.end_time
    start_t = TZ.local_time(s.year, s.month, s.day, s.hour, s.min, s.sec)
    end_t = if e
              TZ.local_time(e.year, e.month, e.day, e.hour, e.min, e.sec)
            end
    [start_t, end_t]
  end
rescue StandardError
  []
end

def collect_upcoming(recurring_list, now, range_end, limit: nil, slug: nil, group_id: nil)
  all = []

  recurring_list.each do |ev|
    eventname = ev["eventname"]
    rrule = ev["rrule"]
    next unless eventname.is_a?(String) && rrule.is_a?(String) && !rrule.strip.empty?

    frequency = rrule_to_frequency(rrule)
    if frequency.nil?
      context = slug ? " (#{slug}, event: #{eventname})" : " (event: #{eventname})"
      warn "Could not generate user-friendly frequency for RRULE#{context}: #{rrule}"
    end

    startdate = ev["startdate"]
    starttime = ev["starttime"]
    endtime = ev["endtime"]
    location = ev["location"].is_a?(Hash) ? ev["location"] : {}

    occurrences = expand_recurrence(startdate, starttime, endtime, rrule, now, range_end)

    signup = ev["signup"].to_s.strip
    signup = nil if signup.empty?

    cost = ev["cost"].to_s.strip
    cost = nil if cost.empty?

    eid = ev["event_id"].to_s.strip
    if eid.empty?
      ctx = slug ? " (#{slug}, event: #{eventname})" : " (event: #{eventname})"
      warn "Missing event_id#{ctx}"
      exit 1
    end

    gid = group_id.to_s.strip
    if gid.empty?
      warn "Missing group_id for recurring event#{slug ? " (#{slug})" : ""}"
      exit 1
    end

    occurrences.each do |start_t, end_t|
      next if start_t < now
      occ = {
        "eventname" => eventname,
        "start_time" => start_t.iso8601,
        "end_time" => end_t&.iso8601,
        "location" => location,
        "group_id" => gid,
        "event_id" => eid,
        "rrule" => rrule,
      }
      occ["frequency"] = frequency if frequency
      occ["signup"] = signup if signup
      occ["cost"] = cost if cost
      all << occ
    end
  end

  all.sort_by! { |o| o["start_time"] }
  all = all.take(limit) if limit
  all
end

def collect_adhoc(adhoc_list, now, range_end, slug: nil, group_id: nil)
  return [] unless adhoc_list.is_a?(Array)

  all = []
  adhoc_list.each do |ev|
    eventname = ev["eventname"]
    next unless eventname.is_a?(String)

    startdate = ev["startdate"]
    starttime = ev["starttime"]
    endtime = ev["endtime"]
    location = ev["location"].is_a?(Hash) ? ev["location"] : {}

    start_date = startdate.is_a?(Date) ? startdate : Date.parse(startdate.to_s)
    shour, smin = parse_hhmm(starttime)
    ehour, emin = parse_hhmm(endtime) if endtime

    start_t = TZ.local_time(start_date.year, start_date.month, start_date.day, shour, smin, 0)
    end_t = if endtime
              TZ.local_time(start_date.year, start_date.month, start_date.day, ehour, emin, 0)
            end

    next if start_t < now || start_t > range_end

    sid = ev["special_event_id"].to_s.strip
    if sid.empty?
      ctx = slug ? " (#{slug}, event: #{eventname})" : " (event: #{eventname})"
      warn "Missing special_event_id#{ctx}"
      exit 1
    end

    gid = group_id.to_s.strip
    if gid.empty?
      warn "Missing group_id for adhoc event#{slug ? " (#{slug})" : ""}"
      exit 1
    end

    signup = ev["signup"].to_s.strip
    signup = nil if signup.empty?

    cost = ev["cost"].to_s.strip
    cost = nil if cost.empty?

    occ = {
      "eventname" => eventname,
      "start_time" => start_t.iso8601,
      "end_time" => end_t&.iso8601,
      "location" => location,
      "group_id" => gid,
      "special_event_id" => sid,
    }
    occ["signup"] = signup if signup
    occ["cost"] = cost if cost
    all << occ
  end

  all.sort_by! { |o| o["start_time"] }
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

def valid_lat_lng?(lat, lng)
  lat_f = Float(lat)
  lng_f = Float(lng)
  lat_f.finite? && lng_f.finite? &&
    lat_f >= -90 && lat_f <= 90 &&
    lng_f >= -180 && lng_f <= 180
rescue ArgumentError, TypeError
  false
end

def validate_event_location!(slug, eventname, loc)
  label = eventname.to_s.strip.empty? ? "(unnamed event)" : eventname
  return if loc.is_a?(Hash) && valid_lat_lng?(loc["lat"], loc["lng"])

  warn "Invalid or missing lat/lng for #{slug} (#{label}): #{loc.inspect}"
  exit 1
end

# Venues from club YAML for the map / distance search. The map must show every
# meeting place even when a club has no upcoming events in the lookahead window.
def yaml_map_locations(locations_lookup)
  return [] unless locations_lookup.is_a?(Hash)

  locs = []
  locations_lookup.each_value do |loc|
    next unless loc.is_a?(Hash) && valid_lat_lng?(loc["lat"], loc["lng"])

    base = {
      "name" => loc["name"],
      "lat" => loc["lat"],
      "lng" => loc["lng"],
    }
    base["parking"] = loc["parking"] if loc["parking"].is_a?(Array) && !loc["parking"].empty?
    locs << base
  end
  locs.uniq { |l| [l["lat"].to_f.round(6), l["lng"].to_f.round(6)] }
end

# Union by rounded lat/lng; event-derived rows (parking enrichment) win over YAML.
def merge_map_locations(event_locs, yaml_locs)
  by_key = {}
  yaml_locs.each do |loc|
    k = [loc["lat"].to_f.round(6), loc["lng"].to_f.round(6)]
    by_key[k] = loc
  end
  event_locs.each do |loc|
    k = [loc["lat"].to_f.round(6), loc["lng"].to_f.round(6)]
    by_key[k] = loc
  end
  by_key.values
end

def main
  warn "Generating JSON file for events"
  root = File.expand_path("..", __dir__)
  clubs_dir = File.join(root, "source", "_clubs")
  data_dir = File.join(root, "source", "_data")
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
    adhoc = events["adhoc"]
    next unless (recurring.is_a?(Array) && recurring.any?) || (adhoc.is_a?(Array) && adhoc.any?)

    club_name = data["name"].to_s

    locations_lookup = data["locations"].is_a?(Hash) ? data["locations"] : {}

    normalise_location = lambda do |ev|
      loc = ev["location"]
      if loc.is_a?(String)
        resolved = locations_lookup[loc]
        unless resolved.is_a?(Hash)
          warn "Unknown location '#{loc}' for #{slug} (#{club_name}) event '#{ev['eventname']}'"
          exit 1
        end
        ev.merge("location" => resolved)
      else
        ev
      end
    end

    normalised_recurring = (recurring || []).map { |ev| normalise_location.call(ev) }.compact
    normalised_adhoc = (adhoc || []).map { |ev| normalise_location.call(ev) }.compact

    (normalised_recurring + normalised_adhoc).each do |ev|
      validate_event_location!(slug, ev["eventname"], ev["location"])
    end

    group_id = data["group_id"].to_s.strip
    if group_id.empty?
      warn "Missing group_id for club #{slug}"
      exit 1
    end

    upcoming_recurring = collect_upcoming(normalised_recurring, now, range_end, slug: slug, group_id: group_id)
    upcoming_adhoc = collect_adhoc(normalised_adhoc, now, range_end, slug: slug, group_id: group_id)
    full_upcoming = (upcoming_recurring + upcoming_adhoc).sort_by { |o| o["start_time"] }
    upcoming = full_upcoming.take(UPCOMING_PER_CLUB)
    yaml_locs = yaml_map_locations(locations_lookup)

    if upcoming.empty?
      next if yaml_locs.empty?

      event_days = collect_event_days(normalised_recurring, normalised_adhoc)
      by_slug[slug] = {
        "club_name" => club_name,
        "upcoming" => [],
        "upcoming_limited" => false,
        "upcoming_limit" => UPCOMING_PER_CLUB,
        "pills" => {
          "frequency" => [],
        },
        "locations" => yaml_locs,
        "event_days" => event_days,
      }
      next
    end

    upcoming_limited = full_upcoming.size > UPCOMING_PER_CLUB

    # Enrich parking entries with distance_from_venue_m (where possible)
    upcoming.each do |occ|
      loc = occ["location"]
      next unless loc.is_a?(Hash) && loc["lat"] && loc["lng"]
      next unless loc["parking"].is_a?(Array)

      venue_lat = loc["lat"].to_f
      venue_lng = loc["lng"].to_f

      loc["parking"] = loc["parking"].map do |pv|
        next pv unless pv.is_a?(Hash) && pv["lat"] && pv["lng"]
        dist_m = haversine_distance_m(venue_lat, venue_lng, pv["lat"], pv["lng"])
        rounded_5m = (dist_m.to_f / 5).round * 5
        pv.merge("distance_from_venue_m" => rounded_5m.to_i)
      end
    end

    frequency_pills = upcoming.map { |o| o["frequency"] }.compact.uniq
    event_days = collect_event_days(normalised_recurring, normalised_adhoc)

    event_unique_locations = upcoming
      .map { |o| o["location"] }
      .select { |loc| loc.is_a?(Hash) && loc["lat"] && loc["lng"] }
      .uniq { |loc| [loc["lat"], loc["lng"]] }
      .map do |loc|
        base = {
          "name" => loc["name"],
          "lat" => loc["lat"],
          "lng" => loc["lng"],
        }
        base["parking"] = loc["parking"] if loc["parking"].is_a?(Array) && !loc["parking"].empty?
        base
      end

    unique_locations = merge_map_locations(event_unique_locations, yaml_locs)

    by_slug[slug] = {
      "club_name" => club_name,
      "upcoming" => upcoming,
      "upcoming_limited" => upcoming_limited,
      "upcoming_limit" => UPCOMING_PER_CLUB,
      "pills" => {
        "frequency" => frequency_pills,
      },
      "locations" => unique_locations,
      "event_days" => event_days,
    }

    club_image = data["image"].to_s.strip
    club_image = nil if club_image.empty?

    based_in = data["based_in"].to_s.strip
    based_in = nil if based_in.empty?

    upcoming.each do |occ|
      row = {
        "slug" => slug,
        "group_id" => occ["group_id"],
        "club_name" => club_name,
        "based_in" => based_in,
        "image" => club_image,
        "eventname" => occ["eventname"],
        "start_time" => occ["start_time"],
        "end_time" => occ["end_time"],
        "location" => occ["location"],
        "frequency" => occ["frequency"],
        "cost" => occ["cost"],
        "signup" => occ["signup"],
      }
      row["event_id"] = occ["event_id"] if occ["event_id"]
      row["special_event_id"] = occ["special_event_id"] if occ["special_event_id"]
      row["rrule"] = occ["rrule"] if occ["rrule"]
      all_upcoming << row.compact
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

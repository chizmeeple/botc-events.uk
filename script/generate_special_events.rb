#!/usr/bin/env ruby
# frozen_string_literal: true

# frozen_string_literal: true
#
# Generates _data/rendered_special_events.json from special event markdown in
# source/_special_events/*.md.
#
# Special events are treated as non-recurring "one occurrence per markdown file"
# (i.e. each file contains a `events.special` list, but we render all items as
# separate occurrences and still derive the URL from the markdown filename).
#
# Output is used by the special events listing page and the special event
# detail layout.

require "date"
require "json"
require "time"
require "tzinfo"
require "yaml"

SITE_URL = "https://botc-events.uk"

TZ = TZInfo::Timezone.get("Europe/London")
LOOKAHEAD_DAYS = 180
ALL_UPCOMING_LIMIT = 500

EARTH_RADIUS_M = 6_371_000

DAY_ORDER = %w[Monday Tuesday Wednesday Thursday Friday Saturday Sunday].freeze
DAY_ABBREV = { "MO" => "Monday", "TU" => "Tuesday", "WE" => "Wednesday",
               "TH" => "Thursday", "FR" => "Friday", "SA" => "Saturday",
               "SU" => "Sunday" }.freeze

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

def parse_hhmm(val)
  str = val.to_s
  return [0, 0] if str.empty?

  hour = str.length >= 2 ? str[0..1].to_i : 0
  min = str.length >= 4 ? str[-2..].to_i : 0
  [hour, min]
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

def day_keys_between(start_date, end_date)
  return [] unless start_date && end_date

  sd = start_date.is_a?(Date) ? start_date : Date.parse(start_date.to_s)
  ed = end_date.is_a?(Date) ? end_date : Date.parse(end_date.to_s)
  ed = sd if ed < sd

  (sd..ed).map { |d| d.strftime("%A") }.uniq
rescue StandardError
  []
end

def normalise_location_for_occ(loc)
  return loc unless loc.is_a?(Hash)

  if loc["lat"] && loc["lng"] && loc["parking"].is_a?(Array) && !loc["parking"].empty?
    venue_lat = loc["lat"].to_f
    venue_lng = loc["lng"].to_f

    loc["parking"] = loc["parking"].map do |pv|
      next pv unless pv.is_a?(Hash) && pv["lat"] && pv["lng"]

      dist_m = haversine_distance_m(venue_lat, venue_lng, pv["lat"], pv["lng"])
      rounded_5m = (dist_m.to_f / 5).round * 5
      pv.merge("distance_from_venue_m" => rounded_5m.to_i)
    end
  end

  loc
end

def build_unique_locations_from_occs(occs)
  return [] unless occs.is_a?(Array)

  occs
    .map { |o| o["location"] }
    .select { |loc| loc.is_a?(Hash) && loc["lat"] && loc["lng"] }
    .uniq { |loc| [loc["lat"], loc["lng"]] }
    .map do |loc|
      base = {
        "name" => loc["name"],
        "address" => loc["address"],
        "lat" => loc["lat"],
        "lng" => loc["lng"]
      }
      base["parking"] = loc["parking"] if loc["parking"].is_a?(Array) && !loc["parking"].empty?
      base
    end
end

def main
  warn "Generating JSON file for special events"

  root = File.expand_path("..", __dir__)
  events_dir = File.join(root, "source", "_special_events")
  data_dir = File.join(root, "source", "_data")
  out_path = File.join(data_dir, "rendered_special_events.json")

  Dir.mkdir(data_dir) unless Dir.exist?(data_dir)

  now = TZ.now
  range_end = now + (LOOKAHEAD_DAYS * 24 * 60 * 60)

  by_slug = {}
  all_upcoming = []

  Dir.glob(File.join(events_dir, "*.md")).sort.each do |path|
    slug = File.basename(path, ".md")
    data = extract_frontmatter(path)
    next unless data.is_a?(Hash)

    eventname = data["name"].to_s
    based_in = data["based_in"].to_s.strip
    banner_image = data["banner_image"]
    banner_image =
      if banner_image.is_a?(Hash)
        banner_image["image"].to_s
      else
        banner_image.to_s
      end
    banner_image = banner_image.strip

    image = data["image"]
    image =
      if image.is_a?(Hash)
        image["image"].to_s
      else
        image.to_s
      end
    image = image.strip

    locations_lookup = data["locations"].is_a?(Hash) ? data["locations"] : {}

    special_list = data.dig("events", "special")
    next unless special_list.is_a?(Array) && special_list.any?
    if special_list.size > 1
      warn "Multiple events.special entries in #{slug}; only the first will be rendered."
      special_list = [special_list.first]
    end
    next if eventname.strip.empty?

    occs_for_slug = []

    special_list.each do |ev|
      next unless ev.is_a?(Hash)

      startdate = ev["startdate"]
      enddate = ev["enddate"]
      starttime = ev["starttime"]
      endtime = ev["endtime"]
      loc_key = ev["location"]

      next unless startdate && enddate && starttime && endtime && loc_key.is_a?(String)

      resolved_location = locations_lookup[loc_key]
      next unless resolved_location.is_a?(Hash)

      shour, smin = parse_hhmm(starttime)
      ehour, emin = parse_hhmm(endtime)

      start_d = startdate.is_a?(Date) ? startdate : Date.parse(startdate.to_s)
      end_d = enddate.is_a?(Date) ? enddate : Date.parse(enddate.to_s)

      start_t = TZ.local_time(start_d.year, start_d.month, start_d.day, shour, smin, 0)
      end_t = TZ.local_time(end_d.year, end_d.month, end_d.day, ehour, emin, 0)

      next if start_t < now || start_t > range_end

      cost = ev["cost"].to_s.strip
      cost = nil if cost.empty?

      location = normalise_location_for_occ(resolved_location)

      occ = {
        "slug" => slug,
        "eventname" => eventname,
        "based_in" => based_in,
        "start_time" => start_t.iso8601,
        "end_time" => end_t&.iso8601,
        "location" => location,
        "cost" => cost,
        "banner_image" => banner_image,
        "image" => image
      }.compact

      next unless occ["cost"]

      occs_for_slug << occ
    end

    next if occs_for_slug.empty?

    occs_for_slug.sort_by! { |o| o["start_time"] }
    main = occs_for_slug.first
    event_days = day_keys_between(
      Date.parse(main["start_time"].to_s),
      Date.parse(main["end_time"].to_s)
    ).sort_by { |d| DAY_ORDER.index(d) || 99 }

    unique_locations = build_unique_locations_from_occs(occs_for_slug)

    by_slug[slug] = {
      "eventname" => eventname,
      "based_in" => based_in,
      "start_time" => main["start_time"],
      "end_time" => main["end_time"],
      "cost" => main["cost"],
      "banner_image" => banner_image,
      "image" => image,
      "locations" => unique_locations,
      "event_days" => event_days,
      "description" => data["description"].to_s,
      "website" => data["website"].to_s
    }

    occs_for_slug.each { |occ| all_upcoming << occ }
  end

  all_upcoming.sort_by! { |o| o["start_time"] }
  all_upcoming = all_upcoming.take(ALL_UPCOMING_LIMIT)

  payload = {
    "generated_at" => now.utc.iso8601,
    "by_slug" => by_slug,
    "map_slugs" => by_slug.keys.sort,
    "all_upcoming" => all_upcoming
  }

  File.write(out_path, JSON.pretty_generate(payload))
  warn "Wrote #{out_path} (#{by_slug.size} special events, #{all_upcoming.size} occurrences)"

  # (Future) calendar feeds for special events.
  # For now, we rely on the existing events feed.
end

main if __FILE__ == $PROGRAM_NAME


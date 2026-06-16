# frozen_string_literal: true

# Shared RRULE / EXRULE expansion for club recurring events.
# EXRULE is deprecated in RFC 5545; we accept it in YAML and apply exclusions
# when expanding occurrences. Calendar ICS output uses EXDATE instead.

require "date"
require "icalendar"
require "icalendar/recurrence"
require "set"
require "tzinfo"

module RecurrenceRules
  TZ = TZInfo::Timezone.get("Europe/London")
  LOOKAHEAD_DAYS = 180

  module_function

  def parse_hhmm(val)
    str = val.to_s
    return [0, 0] if str.empty?

    hour = str.length >= 2 ? str[0..1].to_i : 0
    min  = str.length >= 4 ? str[-2..].to_i : 0
    [hour, min]
  end

  # Normalise EXRULE patterns that icalendar expands incorrectly.
  def normalize_exrule(exrule)
    rule = exrule.to_s.strip
    return rule if rule.empty?

    if (m = rule.match(/\AFREQ=MONTHLY;BYDAY=(MO|TU|WE|TH|FR|SA|SU);BYSETPOS=-1\z/i))
      return "FREQ=MONTHLY;BYDAY=-1#{m[1].upcase}"
    end

    rule
  end

  def supported_exrule?(exrule)
    rule = exrule.to_s.strip
    return true if rule.empty?

    normalized = normalize_exrule(rule)
    normalized.match?(/\AFREQ=MONTHLY;BYDAY=-[1-5](MO|TU|WE|TH|FR|SA|SU)\z/i)
  end

  def validate_exrule!(exrule, slug: nil, eventname: nil)
    rule = exrule.to_s.strip
    return if supported_exrule?(rule)

    context = +""
    context << " (#{slug}, event: #{eventname})" if slug || eventname
    warn "Unsupported EXRULE#{context}: #{rule} (try FREQ=MONTHLY;BYDAY=-1WE for last Wednesday of month)"
    exit 1
  end

  def expand_recurrence_with_icalendar(startdate, starttime, endtime, rrule, range_start, range_end)
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

    event.occurrences_between(range_start, range_end).map do |occ|
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

  def expand_recurrence(startdate, starttime, endtime, rrule, range_start, range_end, exrule: nil)
    occurrences = expand_recurrence_with_icalendar(
      startdate, starttime, endtime, rrule, range_start, range_end
    )
    return occurrences if exrule.to_s.strip.empty?

    exclusion_dates = exclusion_datetimes(
      startdate, starttime, endtime, exrule, range_start, range_end
    ).map { |t| Date.new(t.year, t.month, t.day) }.to_set

    occurrences.reject do |start_t, _end_t|
      exclusion_dates.include?(Date.new(start_t.year, start_t.month, start_t.day))
    end
  end

  def exclusion_datetimes(startdate, starttime, endtime, exrule, range_start, range_end)
    rule = normalize_exrule(exrule)
    expand_recurrence_with_icalendar(
      startdate, starttime, endtime, rule, range_start, range_end
    ).map(&:first)
  end
end

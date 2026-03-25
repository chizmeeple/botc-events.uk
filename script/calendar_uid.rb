# frozen_string_literal: true

# Canonical ICS UID format (RFC 5545): stable identity from group + series/one-off IDs only.
module CalendarUid
  DOMAIN = "botc-events.uk"

  module_function

  def ical_uid(group_id:, event_id: nil, special_event_id: nil)
    gid = group_id.to_s.strip
    raise ArgumentError, "group_id is required" if gid.empty?

    eid = event_id.to_s.strip if event_id
    sid = special_event_id.to_s.strip if special_event_id

    if eid && !eid.empty? && sid && !sid.empty?
      raise ArgumentError, "provide only one of event_id or special_event_id"
    end

    segment = if eid && !eid.empty?
                eid
              elsif sid && !sid.empty?
                sid
              else
                raise ArgumentError, "event_id or special_event_id is required"
              end

    "#{gid}.#{segment}@#{DOMAIN}"
  end
end

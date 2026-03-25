---
name: "{{GROUP_NAME}}"
based_in: "{{GROUP_BASED_IN}}"
# Stable ID for calendar feeds and APIs; do not change when renaming the file or URL slug.
group_id: "{{GROUP_SLUG}}"
image: ""
website: ""
meetup: ""
facebook: ""
discord: ""
bgg: ""
description: >-
locations:
  the-name:
    name: ""
    address: ""
    lat:
    lng:
    # Optional: extended information such as parking
    # parking:
    #   # Example off-site car park
    #   - onsite: false          # true for on-site parking, false for separate car park
    #     free: false            # true for free, false for paid
    #     name: ""
    #     address: ""
    #     website: ""
    #     lat:
    #     lng:
    #     distance_from_venue_m: 0
    #   # Example on-site parking
    #   - onsite: true
    #     free: true
    #     notes: >-
    #       Any extra information about where to park, access restrictions,
    #       or how busy it gets.
events:
  recurring:
    - eventname: ""
      # Stable ID for this series (unique within this group; used in calendar UIDs).
      event_id: ""
      signup: ""
      cost: ""
      startdate: 2026-02-10
      starttime: 1800
      endtime: 2200
      rrule: "FREQ=MONTHLY;BYDAY=2TU"
      location: "the-name"
  adhoc:
    - eventname: ""
      # Stable ID for this one-off (unique within this group; used in calendar UIDs).
      special_event_id: ""
      signup: ""
      cost: ""
      startdate: 2026-02-10
      starttime: 1800
      endtime: 2200
      location: "the-name"
---

---
name: "Sheffield BotC Community"
based_in: "Sheffield"
# Optional: group_id — omit when the stable id matches this file's slug (without .md).
# Set explicitly when renaming the file but keeping the same calendar/API identity.
image: ""
website: "https://www.eventbrite.com/o/118038186641"
meetup: ""
facebook: ""
discord: ""
bgg: ""
description: >-
  Blood on the Clocktower in Sheffield
locations:
  rutland-arms:
    name: "Rutland Arms"
    address: "86 Brown St, Sheffield City Centre, Sheffield S1 2BS"
    lat: 53.37650849659051
    lng: -1.4675507441757243
  the-harlequin:
    name: "The Harlequin"
    address: "108 Nursery St, Sheffield, S3 8GG"
    lat: 53.388510370830105
    lng: -1.4663016307366283
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
    - eventname: "Blood on the Clocktower"
      # Stable ID for this series (unique within this group; used in calendar UIDs).
      event_id: "rutland-arms-sheffield-alternate-fridays"
      signup: "https://www.eventbrite.com/o/118038186641"
      cost: "Free"
      startdate: 2026-04-10
      starttime: 1730
      endtime: 2200
      rrule: "FREQ=WEEKLY;INTERAL=2;BYDAY=FR"
      location: "rutland-arms"
    - eventname: "Blood on the Clocktower"
      # Stable ID for this series (unique within this group; used in calendar UIDs).
      event_id: "the-harlequin-sheffield-every-monday"
      signup: "https://www.eventbrite.com/o/118038186641"
      cost: "Free"
      startdate: 2026-04-10
      starttime: 1730
      endtime: 2200
      rrule: "FREQ=WEEKLY;BYDAY=MO"
      location: "the-harlequin"
---

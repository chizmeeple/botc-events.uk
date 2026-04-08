---
name: "Great Baddow Barn"
based_in: "Chelmsford"
# Optional: group_id — omit when the stable id matches this file's slug (without .md).
# Set explicitly when renaming the file but keeping the same calendar/API identity.
image: ""
website: ""
meetup: ""
facebook: ""
discord: ""
bgg: ""
description: >-
  Free to play, all levels of experience.
locations:
  great-baddow-barn:
    name: "Great Baddow Barn"
    address: "Galleywood Rd, Chelmsford, CM2 8NB"
    lat: 51.7070771574714
    lng: 0.4852032386291511
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
      event_id: "great-baddow-barn-weekly-thursday"
      signup: "https://discord.gg/PUTkJXwUJY"
      cost: "Free"
      startdate: 2026-04-09
      starttime: 1900
      endtime: 2300
      rrule: "FREQ=WEEKLY;BYDAY=TH"
      location: "great-baddow-barn"
---

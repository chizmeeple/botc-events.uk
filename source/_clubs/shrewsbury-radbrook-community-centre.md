---
name: "Radbrook Community Centre"
based_in: "Shrewsbury"
# Optional: group_id — omit when the stable id matches this file's slug (without .md).
# Set explicitly when renaming the file but keeping the same calendar/API identity.
image: ""
website: "https://www.radbrookcc.org.uk/index.htm"
meetup: ""
facebook: "https://www.facebook.com/Radbrook-Community-Cent"
discord: ""
bgg: ""
description: >-
  Blood on the Clocktower in Shrewsbury
locations:
  radbrook-community-centre:
    name: "Radbrook Community Centre"
    address: "Calverton Way, Shrewsbury SY3 6DZ"
    lat: 52.69748873367987
    lng: -2.7761590981539848
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
      event_id: "radbrook-cc-weekly-friday"
      signup: "https://www.radbrookcc.org.uk/index.htm"
      cost: "Unknown"
      startdate: 2026-04-10
      starttime: 1830
      endtime: 2230
      rrule: "FREQ=WEEKLY;BYDAY=FR"
      location: "radbrook-community-centre"
---

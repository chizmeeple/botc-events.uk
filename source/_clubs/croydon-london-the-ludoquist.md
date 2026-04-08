---
name: "The Ludoquist"
based_in: "Croydon (London)"
# Optional: group_id — omit when the stable id matches this file's slug (without .md).
# Set explicitly when renaming the file but keeping the same calendar/API identity.
image: "croydon-london-the-ludoquist.png"
website: "https://www.theludoquist.com/"
meetup: ""
facebook: "https://facebook.com/theludoquist"
discord: ""
bgg: ""
description: >-
  Tickets must be bought from the following link and are not available to buy
  in person on the day. Please try to buy ahead of the night so we can monitor
  numbers for game setup, and note that we frequently sell out by the Monday or
  Tuesday each week. Note - you’ll need to filter this list to show only the
  BoTC games:

  <a href="https://www.theludoquist.com/collections/blood-on-the-clocktower">https://www.theludoquist.com/collections/blood-on-the-clocktower</a>
locations:
  the-ludoquist:
    name: "The Ludoquist - Board Game Cafe Bar"
    address: "63-67 High St, Croydon, CR0 1QE"
    lat: 51.371659423021335
    lng: -0.10028144232971022
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
      event_id: "ludoquist-croydon-weekly-friday"
      signup: "https://www.theludoquist.com/collections/blood-on-the-clocktower"
      cost: "£8"
      startdate: 2026-04-10
      starttime: 1900
      rrule: "FREQ=MONTHLY;BYDAY=2TU"
      location: "the-ludoquist"
---

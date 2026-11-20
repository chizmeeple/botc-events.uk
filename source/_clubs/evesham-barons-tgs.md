---
display_2026_cleanup_message: true
name: Evesham Barons TGS
based_in: Evesham
group_id: evesham-barons-tgs
image: "evesham-barons-tgs.jpg"
website: https://eveshamclocktower.mezepheles.com/
meetup: ""
facebook: ""
discord: ""
bgg: ""
description: >-
  Evesham Clocktower is a fan-run Blood on the Clocktower group in the Vale of
  Evesham, Worcestershire, kindly hosted by the Evesham Barons Tabletop Gaming
  Society at Wallace House Community Centre. We play on selected Sundays from 10:30am
  to 3:30pm, with at least two games a day and scripts matched to the group,
  from the base editions to custom ones. Newcomers are welcome and the rules are
  taught on the day. Book on
  [our website](https://eveshamclocktower.mezepheles.com/book), which also shows
  who's coming, and follow us on
  [Instagram](https://www.instagram.com/clocktower.evesham/) for news.
locations:
  wallace-house:
    name: Wallace House Community Centre
    address: Oat Street, Evesham. WR11 4PJ
    lat: 52.09344124095535
    lng: -1.9456587013868827
    parking:
      # Off-site free car park
      - onsite: false
        free: true
        name: "Oat Street Short Stay Car Park"
        address: "Oat Street Short Stay Car Park, Chapel Street Evesham WR11 4QJ"
        website: "https://www.wychavon.gov.uk/carparks"
        lat: 52.093717068306084
        lng: -1.9447715515162676
        distance_from_venue_m: 50

events:
  adhoc:
    - eventname: Blood on the Clocktower @ EBTGS
      signup: https://eveshamclocktower.mezepheles.com/
      cost: "£5 (18+), £2 (ages 15–17)"
      startdate: 2026-06-14
      starttime: 1000
      endtime: 1600
      location: wallace-house
      special_event_id: blood-on-the-clocktower-ebtgs-20260614

    - eventname: Blood on the Clocktower Evesham @ EBTGS
      signup: https://eveshamclocktower.mezepheles.com/book?event=2004008466269
      cost: "£5 (18+), £2 (under 18) venue entry"
      startdate: 2026-11-15
      starttime: 1030
      endtime: 1530
      location: wallace-house
      special_event_id: blood-on-the-clocktower-ebtgs-20261115

  recurring:
    - eventname: "Blood on the Clocktower Evesham @ EBTGS"
      event_id: "sunday-evesham-games"
      signup: "https://eveshamclocktower.mezepheles.com/book"
      cost: "£5 (18+), £2 (under 18) venue entry"
      startdate: 2026-06-28
      starttime: 1030
      endtime: 1530
      rrule: "FREQ=WEEKLY;INTERVAL=2;BYDAY=SU;UNTIL=20261231T153000"
      exdate:
        - 2026-09-20
        - 2026-10-18
        - 2026-11-15
        - 2026-12-27
      location: "wallace-house"
---
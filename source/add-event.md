---
layout: default
title: "Add an Event to Our UK Directory"
description: "Submit an event for an existing board game group on Board Game Clubs UK. Events must belong to a group already in our directory."
permalink: /add-event/
---

<div class="content-page" markdown="1">

# Add an Event

Add an event for a group that's already listed on {{site.title}}.

**Important:** We only accept event submissions for groups that already exist in our directory. If your group isn't listed yet, please [add your group first](/add-group/) — we will reject event submissions for groups that do not exist.

## Submit via our form

The easiest way to add an event is to fill in our form on GitHub. No technical knowledge required — just fill in the details and we'll add it to the correct group.

<div class="contribute-actions">
  <a href="https://github.com/{{ site.repository }}/issues/new?template=add-event.yml" class="contribute-btn contribute-btn--primary">+ Add an Event</a>
</div>

## Adding an Event via Pull Request

If you're comfortable with GitHub, you can add an event directly by editing the group's file:

### 1. Find the group's file

Browse the [group files](https://github.com/{{ site.repository }}/tree/main/source/\_clubs) and open the file for the group you want to add an event to (e.g. `oxford-on-board.md`).

### 2. Add a new location (if needed)

If the venue isn't already in the group's `locations` section, add it. Use a slug (lowercase, hyphens): e.g. `the-kings-arms`:

```yaml
locations:
  the-kings-arms:
    name: "The King's Arms"
    address: "12 High Street, Leeds, LS1 1AA"
    lat: 53.7960
    lng: -1.5476
```

To get coordinates: search the address on [OpenStreetMap](https://www.openstreetmap.org), right-click the map and select "Show address" — the lat/lng appear in the URL.

### 3. Add the event

Add your event to either `events.recurring` or `events.adhoc`, depending on whether it repeats.

**One-off event** — add to `events.adhoc`:

```yaml
events:
  adhoc:
    - eventname: "Blood on the Clocktower - Westgate Social"
      signup: "https://www.meetup.com/oxfordonboard/events/313473390/"
      cost: "Free"
      startdate: 2026-03-16
      starttime: 1900
      endtime: 2200
      location: "westgate-social"
```

**Recurring event** — add to `events.recurring`:

```yaml
events:
  recurring:
    - eventname: "Blood on the Clocktower"
      signup: "https://www.meetup.com/example/events/"
      cost: "£3"
      startdate: 2026-03-10
      starttime: 1900
      endtime: 2200
      rrule: "FREQ=WEEKLY;BYDAY=TU"
      location: "the-kings-arms"
```

The `location` value must match a slug from the group's `locations` section. For `rrule` examples: `FREQ=WEEKLY;BYDAY=TU` (every Tuesday), `FREQ=MONTHLY;BYDAY=2SA` (2nd Saturday of month), `FREQ=WEEKLY;INTERVAL=2;BYDAY=WE` (every other Wednesday).

### 4. Submit a pull request

Commit your changes and [open a pull request](https://github.com/{{ site.repository }}/pulls). We'll review it and merge it in.

</div>

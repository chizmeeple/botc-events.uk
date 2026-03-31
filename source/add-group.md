---
layout: default
title: "Add Your Blood on the Clocktower Group to Our UK Directory"
description: "Submit your board game group to botc-events.uk. Our free, community-maintained directory helps people find board game groups near them across the UK."
permalink: /add-group/
---

<div class="content-page" markdown="1">

# Add Your Blood on the Clocktower Group

{{site.title}} is community-maintained and hosted on GitHub. Anyone can add a new group or update existing information.

## Submit via our form

The easiest way to add your group is to fill in our form on GitHub. No technical knowledge required - just fill in the details and we'll do the rest.

<div class="contribute-actions">
  <a href="https://github.com/{{ site.repository }}/issues/new?template=add-club.yml" class="contribute-btn contribute-btn--primary">+ Add a Group</a>
  <a href="https://github.com/{{ site.repository }}/issues/new?template=edit-club.yml" class="contribute-btn contribute-btn--secondary">Edit a Group</a>
</div>

## Adding a Group via Pull Request

If you're comfortable with GitHub, you can add a group directly:

### 1. Create a new file

[Create a new file](https://github.com/{{ site.repository }}/new/main/source/\_clubs) in the `source/_clubs/` folder on GitHub. Name it using the format `{town}-{your-club-name}.md`
([lowercase, hyphens instead of spaces](https://dencode.com/en/string/kebab-case?v=RAVENSWOOD%20bluff%20_%20The%20Determined%20Villagers)).

### 2. Copy this template

Paste the following into your new file and fill in the details. See `_club-template.md` in the repo root for the canonical template.

```yaml
---
name: "Unlucky Villagers"
based_in: "Leeds"
group_id: "unlucky-villagers"
image: "unlucky-villagers.png"
website: "https://example.com"
meetup: "https://www.meetup.com/unlucky-villagers/"
facebook: "https://facebook.com/unluckyvillagers"
discord: "https://discord.gg/example"
bgg: "https://boardgamegeek.com/guild/1234"
description: >-
  A friendly group who play Blood on the Clocktower. Newcomers welcome!
  We meet every Tuesday at The King's Arms.
locations:
  the-kings-arms:
    name: "The King's Arms"
    address: "12 High Street, Leeds, LS1 1AA"
    lat: 53.7960
    lng: -1.5476
events:
  recurring:
    - eventname: "Blood on the Clocktower"
      event_id: "tuesday-game-night"
      signup: "https://www.meetup.com/unlucky-villagers/events/"
      cost: "£3"
      startdate: 2026-03-10
      starttime: 1900
      endtime: 2200
      rrule: "FREQ=WEEKLY;BYDAY=TU"
      location: "the-kings-arms"
  adhoc:
    - eventname: "One-off Taster Session"
      special_event_id: "taster-2026-03-15"
      signup: "https://www.meetup.com/unlucky-villagers/events/123"
      cost: "Free"
      startdate: 2026-03-15
      starttime: 1800
      endtime: 2100
      location: "the-kings-arms"
---
```

### 3. Fill in the details

| Field              | Description                                                                                                                                           |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`             | Your group's full name                                                                                                                                |
| `based_in`         | Town or city where you're based                                                                                                                       |
| `group_id`         | Stable ID (lowercase, hyphens). Used for calendar feeds; do not change when renaming the file. Must be unique site-wide. Omit when it matches the filename slug (without `.md`); set explicitly if the stable id must differ from the slug. Required when you list events. |
| `image`            | A URL or filename in `source/assets/images/clubs/` (see [step 5](#5-adding-a-logo) below)                                                             |
| `website`          | Link to your group's website                                                                                                                          |
| `meetup`           | Meetup group URL                                                                                                                                      |
| `facebook`         | Link to your groups's Facebook page or group                                                                                                          |
| `discord`          | Discord invite link                                                                                                                                   |
| `bgg`              | BoardGameGeek guild or group link                                                                                                                     |
| `description`      | A short description. What games do you play? Are newcomers welcome?                                                                                   |
| `locations`        | Venues keyed by slug (e.g. `the-kings-arms`). Each needs `name`, `address`, `lat`, `lng`                                                              |
| `events.recurring` | Array of recurring events. Each needs `eventname`, `event_id` (stable, unique within the group), `signup`, `cost`, `startdate`, `starttime`, `endtime`, `rrule`, `location` (slug from `locations`) |
| `events.adhoc`     | Array of one-off events. Each needs `eventname`, `special_event_id` (stable, unique within the group), `signup`, `cost`, `startdate`, `starttime`, `location`. Optionally `endtime`               |
| `rrule`            | Recurrence rule, e.g. `FREQ=WEEKLY;BYDAY=TU` (every Tuesday), `FREQ=MONTHLY;BYDAY=2SA` (2nd Saturday of month)                                        |

### Extended Information: Parking

Optionally, you can add parking information under each venue in `locations`. This powers:

- The **Parking information** cards on the club page
- The small map on the right that shows both the venue and the car park
- The walking **View directions** link between car park and venue

Add a `parking` array under a location like this:

```yaml
locations:
  dice-tower-basingstoke:
    name: "Dice Tower Basingstoke"
    address: "London St, Basingstoke RG21 7NY"
    lat: 51.262409339480726
    lng: -1.0850773394547892
    parking:
      # Off-site paid car park
      - onsite: false
        free: false
        name: "Central Car Park"
        address: "Central Short Stay Car Park, Red Lion Ln, Basingstoke RG21 7LX"
        website: "https://www.basingstoke.gov.uk/carparks"
        lat: 51.263485749076025
        lng: -1.0850903424007872
        distance_from_venue_m: 120
      # Example on-site parking
      - onsite: true
        free: true
        notes: >
          Limited on-site parking behind the venue. Please leave the front
          spaces free for customers with access needs.
```

**Parking fields**

- `parking` (array, optional): When present and non-empty, a **Parking information** section is shown for this venue.
- For each item in `parking`:
  - `onsite` (true/false): `true` for on-site parking, `false` for a separate car park.
  - `free` (true/false): Whether parking is free. Drives the green **Free** / orange **Paid** pill.
  - `name` (string, optional for on-site): Name of the car park. On-site entries are labelled “On Site Parking” automatically.
  - `address` (string, recommended): Shown under the heading and used to build the walking directions link.
  - `website` (string, optional): Car park information or booking page.
  - `notes` (markdown string, optional): Extra details – height limits, evening charges, which level to use, etc.
  - `distance_from_venue_m` (number, optional but recommended): Distance from the venue in metres (approximate is fine).
  - `lat` / `lng` (numbers, strongly recommended): Coordinates for the car park. If present (and the venue also has `lat`/`lng`), a small Leaflet map will show both pins and centre the view automatically.

If you only add `name`/`address` (without `lat`/`lng`), the **View directions** link will still work, but the mini map cannot be drawn for that car park.

### 4. Find your coordinates

To get the latitude and longitude for your venue:

1. Go to [OpenStreetMap](https://www.openstreetmap.org)
2. Search for your venue's address
3. Right-click on the map and select "Show address"
4. The coordinates will appear in the URL bar (lat and lng)

### 5. Adding a logo

You can add a logo or image for your group:

1. Upload your image to the `source/assets/images/clubs/` folder in the repository (PNG or JPG, ideally square and under 200KB)
2. Set the `image` field in your group file to the filename, e.g. `image: "your-group-logo.png"`

Alternatively, you can use a direct URL to an image hosted elsewhere, e.g. `image: "https://example.com/logo.png"`

### 6. Submit a pull request

Commit your file and [open a pull request](https://github.com/{{ site.repository }}/pulls). We'll review it and merge it in.

## Updating an Existing Group

Find the group's file in the [`source/_clubs/` folder on GitHub](https://github.com/{{ site.repository }}/tree/main/source/\_clubs), make your changes, and submit a pull request. Or just **[open an edit request](https://github.com/{{ site.repository }}/issues/new?template=edit-club.yml)** and we'll update it for you.

</div>

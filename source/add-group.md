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
      signup: "https://www.meetup.com/unlucky-villagers/events/"
      cost: "£3"
      startdate: 2026-03-10
      starttime: 1900
      endtime: 2200
      rrule: "FREQ=WEEKLY;BYDAY=TU"
      location: "the-kings-arms"
  adhoc:
    - eventname: "One-off Taster Session"
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
| `image`            | A URL or filename in `source/assets/images/clubs/` (see [step 5](#5-adding-a-logo) below)                                                             |
| `website`          | Link to your group's website                                                                                                                          |
| `meetup`           | Meetup group URL                                                                                                                                      |
| `facebook`         | Link to your groups's Facebook page or group                                                                                                          |
| `discord`          | Discord invite link                                                                                                                                   |
| `bgg`              | BoardGameGeek guild or group link                                                                                                                     |
| `description`      | A short description. What games do you play? Are newcomers welcome?                                                                                   |
| `locations`        | Venues keyed by slug (e.g. `the-kings-arms`). Each needs `name`, `address`, `lat`, `lng`                                                              |
| `events.recurring` | Array of recurring events. Each needs `eventname`, `signup`, `cost`, `startdate`, `starttime`, `endtime`, `rrule`, `location` (slug from `locations`) |
| `events.adhoc`     | Array of one-off events. Each needs `eventname`, `signup`, `cost`, `startdate`, `starttime`, `location`. Optionally `endtime`                         |
| `rrule`            | Recurrence rule, e.g. `FREQ=WEEKLY;BYDAY=TU` (every Tuesday), `FREQ=MONTHLY;BYDAY=2SA` (2nd Saturday of month)                                        |

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

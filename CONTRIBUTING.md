# Contributing to Board Game Clubs UK

Thanks for helping grow the directory! Here's how to contribute.

## Adding a New Club

1. Fork this repository
2. Create a new file in `source/_clubs/` named `your-club-name.md`
3. Use the frontmatter template below (see `_club-template.md` in the repo root for the canonical template)
4. Submit a pull request

### Frontmatter Template

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

### Field Guide

| Field | Required | Notes |
|-------|----------|-------|
| `name` | Yes | Full club name |
| `based_in` | Yes | Town or city |
| `description` | Yes | 1-3 sentence description |
| `locations` | Yes | Venues keyed by slug. Each needs `name`, `address`, `lat`, `lng` |
| `events.recurring` | No | Array of recurring events. Each needs `eventname`, `signup`, `cost`, `startdate`, `starttime`, `endtime`, `rrule`, `location` |
| `events.adhoc` | No | Array of one-off events. Each needs `eventname`, `signup`, `cost`, `startdate`, `starttime`, `location`. Optionally `endtime` |
| `rrule` | — | Recurrence rule, e.g. `FREQ=WEEKLY;BYDAY=TU` (every Tuesday), `FREQ=MONTHLY;BYDAY=2SA` (2nd Saturday). Times in 24hr format (e.g. 1900). |
| `image` | No | Photo URL or filename in `source/assets/images/clubs/` |
| `website` | No | Full URL |
| `meetup` | No | Meetup group URL |
| `facebook` | No | Facebook page or group URL |
| `discord` | No | Discord invite link |
| `bgg` | No | BoardGameGeek guild or group link |

At least one of `events.recurring` or `events.adhoc` must have entries.

### Finding Coordinates

1. Go to [openstreetmap.org](https://www.openstreetmap.org)
2. Search for the venue address
3. The URL will contain the coordinates, or right-click and "Show address"

## Updating a Club

Edit the relevant file in `source/_clubs/` and submit a pull request with a brief description of what changed.

## Validating Locally

Before submitting a PR, you can validate your club file:

```bash
ruby script/validate_clubs.rb
```

This checks all `source/_clubs/*.md` files for correct frontmatter (required fields, valid day names, coordinate ranges, etc.). The same check runs automatically on every pull request.

## Local Development

```bash
bundle install
bundle exec jekyll serve
```

The site will be available at `http://localhost:4000`.

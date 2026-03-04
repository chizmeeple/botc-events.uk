# Contributing to GameClub

Thanks for helping grow the GameClub directory! Here's how to contribute.

## Adding a New Club

1. Fork this repository
2. Create a new file in `source/_clubs/` named `your-club-name.md`
3. Use the frontmatter template below
4. Submit a pull request

### Frontmatter Template

```yaml
---
name: "Your Club Name"
days: ["Thursday"]
time: "7:00pm - 10:00pm"
frequency: "Weekly"
location:
  name: "Venue Name"
  address: "Full Address, Town, Postcode"
  lat: 53.0000
  lng: -1.0000
cost: "Free"
image: ""
website: ""
facebook: ""
description: >-
  A short description of your club.
---
```

### Field Guide

| Field | Required | Notes |
|-------|----------|-------|
| `name` | Yes | Full club name |
| `days` | Yes | Array of meeting days, e.g. `["Thursday"]` or `["Monday", "Friday"]` |
| `time` | No | Meeting time, e.g. "7:00pm - 10:00pm" |
| `frequency` | Yes | "Weekly", "Fortnightly", or "Monthly" (title-cased) |
| `location.name` | Yes | Venue name |
| `location.address` | Yes | Full address including postcode |
| `location.lat` | Yes | Latitude (decimal degrees) |
| `location.lng` | Yes | Longitude (decimal degrees) |
| `cost` | No | Currency value (e.g. "£2") or "Free" |
| `image` | No | Photo URL or filename in `source/assets/images/clubs/` |
| `website` | No | Full URL or empty string |
| `facebook` | No | Full URL or empty string |
| `description` | Yes | 1-3 sentence description |

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

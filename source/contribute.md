---
layout: default
title: "Add Your Board Game Group to Our UK Directory"
description: "Submit your board game group to Board Game Clubs UK. Our free, community-maintained directory helps people find board game groups near them across the UK."
permalink: /contribute/
---

<div class="content-page" markdown="1">

# Add Your Board Game Group

Board Game Clubs UK is community-maintained and hosted on GitHub. Anyone can add a new group or update existing information.

## Submit via our form

The easiest way to add your group is to fill in our form on GitHub. No technical knowledge required - just fill in the details and we'll do the rest.

<div class="contribute-actions">
  <a href="https://github.com/{{ site.repository }}/issues/new?template=add-club.yml" class="contribute-btn contribute-btn--primary">+ Add a Group</a>
  <a href="https://github.com/{{ site.repository }}/issues/new?template=edit-club.yml" class="contribute-btn contribute-btn--secondary">Edit a Group</a>
</div>

## Adding a Group via Pull Request

If you're comfortable with GitHub, you can add a group directly:

### 1. Create a new file

[Create a new file](https://github.com/{{ site.repository }}/new/main/source/_clubs) in the `source/_clubs/` folder on GitHub. Name it using the format `your-club-name.md` (lowercase, hyphens instead of spaces).

### 2. Copy this template

Paste the following into your new file and fill in the details:

```yaml
---
name: "Your Group Name"
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
discord: ""
bgg: ""
description: >-
  A short description of your group. What games do you play?
  Are newcomers welcome? Any other useful info.
---
```

### 3. Fill in the details

| Field | Description |
|-------|-------------|
| `name` | Your group's full name |
| `days` | Array of days you meet, e.g. `["Thursday"]` or `["Monday", "Friday"]` |
| `time` | When you meet, e.g. "7:00pm - 10:00pm" |
| `frequency` | "Weekly", "Fortnightly", "Monthly", or "Ad-hoc" |
| `location` | Venue name, full address, and coordinates |
| `cost` | "Free" or a money amount, e.g. "£2", "£5 (First Session Free)" |
| `image` | A URL or filename in `source/assets/images/clubs/` (see [step 5](#5-adding-a-logo) below) |
| `website` | Link to your group's website |
| `facebook` | Link to your club's Facebook page or group |
| `discord` | Discord invite link |
| `bgg` | BoardGameGeek guild or group link |

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

Find the group's file in the [`source/_clubs/` folder on GitHub](https://github.com/{{ site.repository }}/tree/main/source/_clubs), make your changes, and submit a pull request. Or just **[open an edit request](https://github.com/{{ site.repository }}/issues/new?template=edit-club.yml)** and we'll update it for you.

</div>

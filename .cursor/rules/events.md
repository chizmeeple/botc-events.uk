# Groups and events

Read this file first — do not search the repo to derive structure unless something
here is missing or ambiguous.

## Repo map

| What                             | Path                                                            |
| -------------------------------- | --------------------------------------------------------------- |
| Groups                           | `source/_clubs/{town}-{club-slug}.md`                           |
| New group template               | `_club-template.md` (repo root)                                 |
| Special events (cons, festivals) | `source/_special_events/{YYYY-MM-DD}-{slug}.md`                 |
| Club logos                       | `source/assets/images/clubs/`                                   |
| Human docs                       | `source/add-group.md`, `source/add-event.md`, `CONTRIBUTING.md` |

Filename slug, `group_id`, and display `name` are different things. `group_id` is
the stable calendar/API identity (usually matches the filename without `.md`).

## Find an existing group

Before creating a file, check whether the group already exists:

```bash
rg -l 'based_in: Chester' source/_clubs/
rg -l 'name: BOTChes' source/_clubs/
```

## File structure

Every group file is YAML front matter only (between `---` markers). Canonical
shape — see `_club-template.md` for comments and optional fields (e.g. parking):

```yaml
---
name: "Group Name"
based_in: Town
group_id: town-club-slug # required when events exist; unique site-wide
image: "" # filename in assets/images/clubs/ or a URL
website: ""
meetup: ""
facebook: ""
discord: ""
bgg: ""
description: >-
locations:
  venue-slug: # referenced by events[].location
    name: ""
    address: ""
    lat: 53.79
    lng: -1.54
events:
  recurring: # repeating series
    - eventname: ""
      event_id: stable-series-id # unique within group; never reuse
      signup: ""
      cost: ""
      startdate: 2026-06-20
      starttime: 1900 # 24hr HHMM, no colon
      endtime: 2200
      rrule: FREQ=WEEKLY;BYDAY=TU
      # Optional: UNTIL=YYYYMMDDTHHMMSS (inclusive last occurrence at endtime)
      # Optional: exdate: list of YYYY-MM-DD skips; exrule: repeating skips
      location: venue-slug
  adhoc: # one-offs (Discord monthly dates go here)
    - eventname: ""
      special_event_id: blood-on-the-clocktower-20260721
      signup: ""
      cost: ""
      startdate: 2026-07-21
      starttime: 1800
      endtime: 2200
      location: venue-slug
---
```

### Field rules

- **Recurring** events use `event_id`. **Adhoc** events use `special_event_id`.
  Never swap them; IDs must be disjoint within a group.
- IDs: lowercase, hyphens only — `[a-z0-9]+(?:-[a-z0-9]+)*`.
- Common adhoc ID pattern: `blood-on-the-clocktower-YYYYMMDD`.
- `location` must match a key under `locations`.
- At least one of `events.recurring` or `events.adhoc` must have entries when
  adding a new group.
- Match the YAML indentation of the target file (some clubs use 2-space lists,
  others 4).
- Common `rrule` values: `FREQ=WEEKLY;BYDAY=TU`, `FREQ=WEEKLY;INTERVAL=2;BYDAY=SA`
  (fortnightly), `FREQ=MONTHLY;BYDAY=1TH` (first Thursday),
  `FREQ=MONTHLY;BYDAY=1SA,3SA` (1st and 3rd Saturday).
- **`UNTIL`** — append to the existing `rrule` to end a series. Format
  `UNTIL=YYYYMMDDTHHMMSS` using the last occurrence's date and that event's
  `endtime` (HHMM → HHMMSS). Inclusive: that last date still appears. Example:
  `FREQ=WEEKLY;BYDAY=TU;UNTIL=20260811T220000`.
- **`exdate`** — YAML list of `YYYY-MM-DD` under the recurring event; skips
  one-off dates without ending the series. Keep chronological.
- **`exrule`** — repeating skip pattern. Supported shape is last-N weekday of
  the month, e.g. `FREQ=MONTHLY;BYDAY=WE;BYSETPOS=-1` (every Wednesday except
  the last). Do not use `exrule` for one-off skips.

### Reference examples

- Monthly Discord adhoc dates: `source/_clubs/chester-botches.md`
- Recurring fortnightly series: `source/_clubs/york-up-a-level.md`
- Multiple venues, adhoc only: `source/_clubs/bristol-clocktower.md`
- Ended series (`UNTIL`): `source/_clubs/basingstoke-dice-tower.md`
- Skipped dates (`exdate`): `source/_clubs/york-up-a-level.md`
- Repeating skip (`exrule`): `source/_clubs/bristol-replay.md`
- Parking: `_club-template.md` and `source/_clubs/basingstoke-dice-tower.md`

## Rules

- **Never update an existing event entry to represent a new date.** Append a new
  adhoc or recurring entry unless explicitly fixing a mistake, rescheduling a
  future adhoc, or ending/skipping a recurring series as below.
- Keep adhoc entries in chronological order when appending.
- Do not delete events that have already happened.
- In-place edits are fine for signup, cost, times, description, links, parking,
  and logos. Do not change `event_id` / `special_event_id` except when a future
  adhoc's id embeds a date that moved.
- British spelling in commit messages.

## Workflows

### Add adhoc dates (e.g. from Discord)

1. Find the group file under `source/_clubs/`.
2. Append a new entry to `events.adhoc` with a fresh `special_event_id`.
3. Run `./script/cursor-check` (see `validating.md`).

### Add a recurring series to an existing group

1. Append to `events.recurring` with a new unique `event_id`.
2. Set `startdate` to the first occurrence on or after today; set `rrule`.
3. Run `./script/cursor-check`.

### Add a new group

1. Copy `_club-template.md` → `source/_clubs/{town}-{slug}.md`.
2. Fill `locations` and at least one event under `events.recurring` or
   `events.adhoc`.
3. Optionally add a logo to `source/assets/images/clubs/` and set `image`.
4. Run `./script/cursor-check`.

### End a recurring series

1. Do **not** delete the recurring entry or convert it to adhoc.
2. Append `;UNTIL=YYYYMMDDTHHMMSS` to the existing `rrule`. Keep `event_id`.
3. `UNTIL` is inclusive. Use the last occurrence's date and that event's
   `endtime`. Example last Tuesday 11 Aug, endtime 2200:
   `UNTIL=20260811T220000`.
4. If the last session is unknown but there are no events **from DATE
   onwards**, use the last occurrence that falls **before** that date.
5. Run `./script/cursor-check`.

### Skip or cancel dates in a recurring series

1. Do **not** delete the series or change `startdate` / `event_id`.
2. Add or append ISO dates under `exdate` on that recurring event, chronological:

   ```yaml
   exdate:
     - 2026-08-29
   ```

3. Use `exdate` for one-off skips. Use `UNTIL` only when the series has ended.
4. Run `./script/cursor-check`.

### Recurring pattern exceptions (`exrule`)

When a series skips a repeating pattern (e.g. weekly except the last Wednesday
of each month), set `exrule` on the recurring event rather than listing every
date in `exdate`:

```yaml
rrule: FREQ=WEEKLY;BYDAY=WE
exrule: FREQ=MONTHLY;BYDAY=WE;BYSETPOS=-1
```

Only last-N weekday-of-month `exrule` values are supported. See
`source/_clubs/bristol-replay.md`.

### Replace one occurrence with a different adhoc event

When a recurring date still happens but under a different name, cost, or time
(or a one-off replaces it):

1. Add that date to the series `exdate`.
2. Append a new `events.adhoc` entry with a fresh `special_event_id`.
3. See `source/_clubs/frome-table-and-tale-gaming.md`.

### Reschedule a future adhoc event

If an upcoming one-off **moved** (same event, new date): update `startdate` and,
if the `special_event_id` embeds the old date, update that id to match. Never
do this for a date that has already happened, and never reuse this to roll a
recurring series forward.

### Add parking to a venue

Add a `parking` array under the venue in `locations`. Copy the field shape from
`_club-template.md` (`onsite`, `free`, `name`, `address`, `lat`, `lng`,
`distance_from_venue_m`, optional `website` / `notes`). Do not invent car
parks. Then `./script/cursor-check`.

### Add or replace a group logo

Put the file in `source/assets/images/clubs/` and set `image` to the filename
only (not a path). Typical names match the club file slug.

### Add a special event (con, festival)

Use `source/_special_events/` — a separate collection with `events.special`,
not club `events.adhoc`. Multi-day events use `enddate` on the special entry,
not `UNTIL`. See an existing file such as
`source/_special_events/2026-05-02-milton-keynes-bloodfest.md`.

## Validation

After any change to group or special-event files, run from the repo root:

```bash
PS1='> ' zsh --no-rcs -c './script/cursor-check'
```

See `validating.md` for Ruby/Bundler environment details.

## Commit command

After **every** change that adds or updates a group and/or event, end the
response with a ready-to-run commit command. Do not commit unless the user asks.

```bash
git add <changed files only>

git commit -m "$(cat <<'EOF'
Commit message here.

EOF
)"
```

- Stage only files changed for the update (never `python/` or credential files).
- One or two sentences; British spelling; focus on why.
- Match recent style, e.g. "Add Worthing Blood on the Clocktower July dates from Discord."

**Adhoc/recurring update** — stage the club file only:

```bash
git add source/_clubs/chester-botches.md

git commit -m "$(cat <<'EOF'
Add BOTChes July date from Discord.

EOF
)"
```

**End or skip a series** — stage the club file only:

```bash
git add source/_clubs/basingstoke-dice-tower.md

git commit -m "$(cat <<'EOF'
End The Tavern Basingstoke weekly series from 13 Aug.

EOF
)"
```

```bash
git add source/_clubs/york-up-a-level.md

git commit -m "$(cat <<'EOF'
Exclude Up A Level 29 August date for Demons Wake.

EOF
)"
```

**New group** — stage the club file and any logo:

```bash
git add source/_clubs/worthing-blood-on-the-clocktower.md source/assets/images/clubs/worthing-blood-on-the-clocktower.png

git commit -m "$(cat <<'EOF'
Add Worthing Blood on the Clocktower group.

EOF
)"
```

If the change is related to any issues add "This resolves #{number}" to the commit message description.

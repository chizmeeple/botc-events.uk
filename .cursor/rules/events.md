# Groups and events

Read this file first — do not search the repo to derive structure unless something
here is missing or ambiguous.

## Repo map

| What | Path |
|------|------|
| Groups | `source/_clubs/{town}-{club-slug}.md` |
| New group template | `_club-template.md` (repo root) |
| Special events (cons, festivals) | `source/_special_events/{YYYY-MM-DD}-{slug}.md` |
| Club logos | `source/assets/images/clubs/` |
| Human docs | `source/add-group.md`, `source/add-event.md`, `CONTRIBUTING.md` |

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
group_id: town-club-slug          # required when events exist; unique site-wide
image: ""                         # filename in assets/images/clubs/ or a URL
website: ""
meetup: ""
facebook: ""
discord: ""
bgg: ""
description: >-
locations:
  venue-slug:                     # referenced by events[].location
    name: ""
    address: ""
    lat: 53.79
    lng: -1.54
events:
  recurring:                      # repeating series
    - eventname: ""
      event_id: stable-series-id  # unique within group; never reuse
      signup: ""
      cost: ""
      startdate: 2026-06-20
      starttime: 1900             # 24hr HHMM, no colon
      endtime: 2200
      rrule: FREQ=WEEKLY;BYDAY=TU
      location: venue-slug
  adhoc:                          # one-offs (Discord monthly dates go here)
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

### Reference examples

- Monthly Discord adhoc dates: `source/_clubs/chester-botches.md`
- Recurring fortnightly series: `source/_clubs/york-up-a-level.md`
- Multiple venues, adhoc only: `source/_clubs/bristol-clocktower.md`

## Rules

- **Never update an existing event entry to represent a new date.** Append a new
  adhoc or recurring entry unless explicitly fixing a mistake.
- Keep adhoc entries in chronological order when appending.
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

### Add a special event (con, festival)

Use `source/_special_events/` — a separate collection with `events.special`,
not club `events.adhoc`. See an existing file such as
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

**New group** — stage the club file and any logo:

```bash
git add source/_clubs/worthing-blood-on-the-clocktower.md source/assets/images/clubs/worthing-blood-on-the-clocktower.png

git commit -m "$(cat <<'EOF'
Add Worthing Blood on the Clocktower group.

EOF
)"
```

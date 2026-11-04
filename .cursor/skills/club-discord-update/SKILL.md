---
name: club-discord-update
description: >-
  Adds adhoc event dates to an existing club from a Discord (or similar) paste.
  Use when the user says "{place} updates", pastes Discord/Facebook schedule
  text, or asks to add dates to a group under source/_clubs/. Look up
  Eventbrite times, prices, and ticket URLs with script/query-api/eventbrite.
---

# Club Discord update

Existing group, new dates from a paste. Structure is in this file and in
`.cursor/rules/events.mdc` — do not search the repo to learn it.

This workflow **does not** restart `script/jekyll-serve` and **does not** use
the browser. Ignore those steps in `events.mdc` / `validating.md` here.

## First tool calls

1. Open `source/_clubs/{town}-*.md` when the place is obvious
   (`Beverley` → `source/_clubs/beverley-*.md`, `#oxford` → `oxford-*.md`).
   A glob limited to that prefix is fine.
2. Otherwise `rg -l` under `source/_clubs/` for `based_in:` or `name:`.

Do not glob the whole repo, grep for event structure, read another club file,
read `jekyll-serve`, or inspect terminals.

If no club file exists, stop and say so. Do not create a group unless the user
clearly asked for a new group.

## Eventbrite

If the paste or the open club file has an Eventbrite URL (`eventbrite.com` or
`eventbrite.co.uk`, including `website` or `signup`), get the listing from the
helper. Do not WebFetch, WebSearch, or curl Eventbrite.

From the repo root, once per update:

```bash
PS1='> ' zsh --no-rcs -c './script/query-api/eventbrite URL [URL ...]'
```

- A ticket URL (`/e/…`) returns that event. Pass every ticket URL in one call.
- An organiser URL (`/o/…`) returns current events (`live,started`). Use it when
  the paste has dates but no ticket link, and when `website` or `signup` is the
  organiser page. Match each paste date to a printed event. If a date is
  missing, rerun that organiser with `--status live,started,ended`.

Use the script for anything the paste does not already state. The paste wins
when it gives a time or cost; mention the Eventbrite value if they differ.

- `when` → `startdate`, and `starttime` / `endtime` as `HHMM` (`11:00–14:00` →
  `1100` / `1400`).
- `price` → `cost` in the file's style (`Free`, or `3.00 GBP` → `£3`).
- `url` → `signup`. Prefer that ticket URL over the organiser page.
- `venue` only chooses a `location` key already in the file. If none match,
  keep the copied location and say so.

## Edit

- **Never** change an existing event into a new date. Append a new `events.adhoc`
  entry with a fresh `special_event_id`.
- Copy `eventname`, `signup`, `cost`, times, and `location` from the latest
  matching adhoc (or the recurring series if that is the template).
- Prefer a URL, cost, or time from the paste when it states one. When the
  listing is on Eventbrite, fill anything the paste omits from the helper, as
  in Eventbrite above.
- Times are 24hr `HHMM` with no colon (`6.30-9pm` → `1830` / `2100`).
- Year: same as that file's upcoming dates.
- Common id: `blood-on-the-clocktower-YYYYMMDD`. IDs: `[a-z0-9]+(?:-[a-z0-9]+)*`.
- Keep adhoc chronological. Match the file's YAML indentation.
- If a recurring series would also emit those dates, add matching `exdate`
  values. Do not delete past events.

## Validate

From the repo root, after the edits (once at the end of a batch):

```bash
PS1='> ' zsh --no-rcs -c './script/cursor-events-check'
```

Leave any running Jekyll server alone. Do not run `script/jekyll-serve`,
`script/cursor-check`, or browser tools.

## Finish

Do not commit. Give **one commit command per place/update**, even when several
are in the same chat. Never combine club files into one commit.

Each command stages **only** that club file:

```bash
git add source/_clubs/{file}.md

git commit -m "$(cat <<'EOF'
Add {Group} {Month} date from Discord.

EOF
)"
```

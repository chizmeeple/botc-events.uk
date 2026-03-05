<div align="center">

<img src="source/assets/meeple-map-icon.svg" alt="botc-events.uk" width="120">

# botc-events.uk

**Find your nearest board game club in the UK.**

A community-built directory powered by an interactive map.

[![GitHub Pages](https://img.shields.io/badge/Hosted%20on-GitHub%20Pages-blue?logo=github)](https://boardgameclubs.uk)
[![Built with Jekyll](https://img.shields.io/badge/Built%20with-Jekyll-cc0000?logo=jekyll)](https://jekyllrb.com/)
[![MIT License](https://img.shields.io/badge/License-MIT-green)](#license)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-orange)](https://botc-events.uk/add-group/)

[Live Site](https://botc-events.uk) · [Add a Group](https://botc-events.uk/add-group/) · [Report a Bug](https://github.com/chizmeeple/botc-events.uk/issues/new)

</div>

<br>

## What is this?

botc-events.uk helps people find Blood on the Clocktower groups near them. Search by postcode, browse the map, or filter by day and distance. Every club listing is maintained by the community through GitHub.

## How it works

- The site is built with [Jekyll](https://jekyllrb.com/) and hosted on [GitHub Pages](https://pages.github.com/)
- Each club is a Markdown file in the `source/_clubs/` directory
- Club data is served as JSON and rendered on an interactive [Leaflet](https://leafletjs.com/) map
- Anyone can add or update a club by submitting a pull request

## Adding or editing a club

See the [add-group page](https://botc-events.uk/add-group/) for a full guide on adding a new club or updating an existing listing.

Not comfortable with GitHub? [Open an issue](https://github.com/chizmeeple/botc-events.uk/issues/new) with your club's details and we'll add it for you.

## Running locally

```bash
bundle install
bundle exec jekyll serve
```

Then visit `http://localhost:4000`.

## Tech stack

- **Jekyll**: static site generator
- **Leaflet**: interactive maps
- **GitHub Pages**: hosting and deployment
- **Lucide**: icons

## Original Project

This project is a copy of the
[BoardGameClubsUK](https://github.com/BoardGameClubs/BoardGameClubsUK) project.
Almost all of the awesome features come from the original project.

## License

This project is licensed under the [MIT License](LICENSE). You're free to use, modify, and distribute the code.

Club data is contributed by the community and is available under [Creative Commons Attribution 4.0 (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/) - you can share and adapt the data as long as you give appropriate credit.

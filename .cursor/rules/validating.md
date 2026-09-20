# Ruby environment and site validation

Cursor’s shell does not load chruby. Never run bare `ruby`, `gem`, `bundle`, or
`jekyll`.

## Discord / adhoc club updates

For dates on an existing group, run `./script/cursor-events-check` (validates
clubs and regenerates `rendered_events.json`). Do not restart Jekyll and do
not use the browser. See the `club-discord-update` skill.

```bash
PS1='> ' zsh --no-rcs -c './script/cursor-events-check'
```

## Local server (club / event changes)

Use `script/jekyll-serve` — it sources chruby, regenerates event data, builds,
and serves with livereload.

**Kill and restart it** for new groups, special events, or when previewing
the site. Discord/adhoc updates to an existing group should use
`cursor-events-check` instead (a running server does not regenerate
`rendered_events.json` on its own). Do not keep serving `_site` with
`python3 -m http.server`.

```bash
PS1='> ' zsh --no-rcs -c './script/jekyll-serve'
```

Serves at http://127.0.0.1:4000/.

## Jekyll build / site validation

For a one-off build without serving, run from the repo root:

```bash
PS1='> ' zsh --no-rcs -c './script/cursor-check'
```

Do **not** run `bundle exec jekyll build`, `npm test`, or similar directly.
`cursor-check` does not regenerate event JSON.

## Other Ruby/Bundler commands

Prefix with the same environment as `script/cursor-check` (lines 7–12), `cd` to
the repo root, then use the project Bundler:

```bash
PS1='> ' zsh --no-rcs -c '
export RUBY_ROOT="/Users/chisel/.rubies/ruby-3.4.5"
export RUBY_ENGINE="ruby"
export RUBY_VERSION="3.4.5"
export GEM_ROOT="/Users/chisel/.rubies/ruby-3.4.5/lib/ruby/gems/3.4.0"
export GEM_HOME="/Users/chisel/.gem/ruby/3.4.5"
export GEM_PATH="/Users/chisel/.gem/ruby/3.4.5:/Users/chisel/.rubies/ruby-3.4.5/lib/ruby/gems/3.4.0"
export PATH="${RUBY_ROOT}/bin:${PATH}"
cd "/Users/chisel/development/chizmeeple/botc-events.uk"
"${RUBY_ROOT}/bin/bundler" exec <command>
'
```

Examples: `"${RUBY_ROOT}/bin/bundler" install`, `"${RUBY_ROOT}/bin/bundler" exec rubocop`.

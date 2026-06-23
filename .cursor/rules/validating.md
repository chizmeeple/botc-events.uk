# Ruby environment and site validation

Cursor’s shell does not load chruby. Never run bare `ruby`, `gem`, `bundle`, or
`jekyll`.

## Jekyll build / site validation

Run from the repo root:

```bash
PS1='> ' zsh --no-rcs -c './script/cursor-check'
```

Do **not** run `bundle exec jekyll build`, `npm test`, or similar directly.

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

#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "open3"
require "tmpdir"

require_relative "changed_group_pages"

failures = 0

def assert(condition, message)
  unless condition
    warn "FAIL: #{message}"
    return false
  end

  true
end

def git(dir, *args)
  identity = [
    "-c", "user.name=Test",
    "-c", "user.email=test@example.com",
    "-c", "commit.gpgsign=false",
    "-c", "core.hooksPath=/dev/null"
  ]
  stdout, stderr, status = Open3.capture3("git", "-C", dir, *identity, *args)
  raise "git #{args.join(' ')} failed: #{stderr}" unless status.success?

  stdout.strip
end

def club_file(name:, slug:)
  <<~YAML
    ---
    name: "#{name}"
    based_in: Testville
    group_id: #{slug}
    description: >-
      Test group.
    locations:
      venue:
        name: Venue
        address: 1 Test Street
        lat: 51.0
        lng: -1.0
    events:
      recurring:
        - eventname: Blood on the Clocktower
          event_id: weekly
          signup: https://example.com
          cost: Free
          startdate: 2026-08-18
          starttime: 1900
          endtime: 2200
          rrule: FREQ=WEEKLY;BYDAY=TU
          location: venue
    ---
  YAML
end

def special_file(name:, slug:)
  <<~YAML
    ---
    name: "#{name}"
    based_in: Testville
    group_id: #{slug}
    description: A special event.
    locations:
      venue:
        name: Venue
        address: 1 Test Street
        lat: 51.0
        lng: -1.0
    events:
      special:
        - startdate: 2026-09-01
          starttime: "0900"
          enddate: 2026-09-01
          endtime: 1700
          location: venue
          cost: Free
          special_event_id: main
    ---
  YAML
end

def write_repo(dir)
  FileUtils.mkdir_p(File.join(dir, "source/_clubs"))
  FileUtils.mkdir_p(File.join(dir, "source/_special_events"))
  File.write(File.join(dir, "README.md"), "# test\n")
  git(dir, "init", "-b", "main")
  git(dir, "add", "README.md")
  git(dir, "commit", "-m", "Initial commit")
end

# --- unit tests ---

unless assert(ChangedGroupPages.classify("source/_clubs/oxford-on-board.md") == [:clubs, "oxford-on-board"],
              "classify club path")
  failures += 1
end
unless assert(ChangedGroupPages.classify("source/_special_events/2026-05-02-bloodfest.md") == [:special_events, "2026-05-02-bloodfest"],
              "classify special event path")
  failures += 1
end
unless assert(ChangedGroupPages.classify("README.md").nil?, "ignore unrelated paths")
  failures += 1
end

empty = ChangedGroupPages.render([])
unless assert(empty == ChangedGroupPages::EMPTY_MESSAGE, "empty render message")
  failures += 1
end

added = ChangedGroupPages::Change.new(kind: :added, collection: :clubs, slug: "ipswich-v4gcl", name: "V4GCL")
modified = ChangedGroupPages::Change.new(kind: :modified, collection: :clubs, slug: "oxford-on-board", name: "On Board")
markdown = ChangedGroupPages.render([added, modified])
unless assert(markdown.include?("## New Groups") && markdown.include?("[V4GCL](https://botc-events.uk/clubs/ipswich-v4gcl/)"),
              "new groups section")
  failures += 1
end
unless assert(markdown.include?("## Updated Groups / Events") && markdown.include?("[On Board](https://botc-events.uk/clubs/oxford-on-board/)"),
              "updated groups section")
  failures += 1
end
unless assert(!markdown.include?("Removed") && !markdown.include?("Special Events"),
              "omit empty sections")
  failures += 1
end

renamed = ChangedGroupPages::Change.new(
  kind: :renamed,
  collection: :clubs,
  slug: "new-slug",
  name: "Renamed Club",
  old_slug: "old-slug"
)
rename_md = ChangedGroupPages.render([renamed])
unless assert(rename_md.include?("(was [old-slug](https://botc-events.uk/clubs/old-slug/))"),
              "renamed group notes previous URL")
  failures += 1
end

entries = ChangedGroupPages.parse_name_status(<<~DIFF)
  A	source/_clubs/new-group.md
  M	source/_clubs/existing.md
  D	source/_clubs/gone.md
  R100	source/_clubs/old.md	source/_clubs/renamed.md
  M	README.md
DIFF
changes = ChangedGroupPages.changes_from_entries(entries)
kinds = changes.map { |change| [change.kind, change.slug] }
unless assert(kinds == [
               [:added, "new-group"],
               [:modified, "existing"],
               [:deleted, "gone"],
               [:renamed, "renamed"]
             ], "parse name-status into club changes (got #{kinds.inspect})")
  failures += 1
end
unless assert(changes.find { |change| change.kind == :renamed }.old_slug == "old",
              "rename keeps old slug")
  failures += 1
end

name = ChangedGroupPages.name_from_content(club_file(name: "Meeplefolk", slug: "basingstoke-meeplefolk"), fallback: "fallback")
unless assert(name == "Meeplefolk", "read name from frontmatter")
  failures += 1
end
unless assert(ChangedGroupPages.name_from_content("not yaml", fallback: "fallback") == "fallback",
              "fallback when frontmatter missing")
  failures += 1
end

# --- git integration ---

Dir.mktmpdir("changed-group-pages-") do |dir|
  write_repo(dir)
  File.write(File.join(dir, "source/_clubs/oxford-on-board.md"), club_file(name: "On Board", slug: "oxford-on-board"))
  git(dir, "add", "source/_clubs/oxford-on-board.md")
  git(dir, "commit", "-m", "Add Oxford")
  base = git(dir, "rev-parse", "HEAD")

  File.write(File.join(dir, "source/_clubs/ipswich-v4gcl.md"), club_file(name: "V4GCL", slug: "ipswich-v4gcl"))
  File.write(File.join(dir, "source/_clubs/oxford-on-board.md"), club_file(name: "On Board", slug: "oxford-on-board").sub("Test group.", "Updated description."))
  File.write(File.join(dir, "source/_special_events/2026-09-01-test-con.md"), special_file(name: "Test Con", slug: "2026-09-01-test-con"))
  git(dir, "add", "source/_clubs", "source/_special_events")
  git(dir, "commit", "-m", "Add Ipswich, update Oxford, add con")
  head = git(dir, "rev-parse", "HEAD")

  output = ChangedGroupPages.run(repo: dir, base: base, head: head)
  unless assert(output.include?("## New Groups") && output.include?("[V4GCL](https://botc-events.uk/clubs/ipswich-v4gcl/)"),
                "git: new group (got:\n#{output})")
    failures += 1
  end
  unless assert(output.include?("## Updated Groups / Events") && output.include?("[On Board](https://botc-events.uk/clubs/oxford-on-board/)"),
                "git: updated group")
    failures += 1
  end
  unless assert(output.include?("## New Special Events") && output.include?("[Test Con](https://botc-events.uk/special/2026-09-01-test-con/)"),
                "git: new special event")
    failures += 1
  end

  docs_base = head
  File.write(File.join(dir, "README.md"), "# docs only\n")
  git(dir, "add", "README.md")
  git(dir, "commit", "-m", "Docs")
  docs_head = git(dir, "rev-parse", "HEAD")
  docs_output = ChangedGroupPages.run(repo: dir, base: docs_base, head: docs_head)
  unless assert(docs_output == ChangedGroupPages::EMPTY_MESSAGE, "git: docs-only PR (got #{docs_output.inspect})")
    failures += 1
  end

  delete_base = docs_head
  FileUtils.rm(File.join(dir, "source/_clubs/ipswich-v4gcl.md"))
  git(dir, "add", "-A", "source/_clubs")
  git(dir, "commit", "-m", "Remove Ipswich")
  delete_head = git(dir, "rev-parse", "HEAD")
  delete_output = ChangedGroupPages.run(repo: dir, base: delete_base, head: delete_head)
  unless assert(delete_output.include?("## Removed Groups") && delete_output.include?("[V4GCL](https://botc-events.uk/clubs/ipswich-v4gcl/)"),
                "git: removed group keeps production URL and name (got:\n#{delete_output})")
    failures += 1
  end
end

if failures.positive?
  warn "\n#{failures} failure(s)."
  exit 1
end

puts "All changed_group_pages tests passed."

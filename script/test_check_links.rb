#!/usr/bin/env ruby
# frozen_string_literal: true

require "socket"
require "tmpdir"

require_relative "check_links"

$failures = 0

def assert(condition, message)
  unless condition
    warn "FAIL: #{message}"
    return false
  end

  true
end

def check(condition, message)
  $failures += 1 unless assert(condition, message)
end

club = <<~YAML
  ---
  name: "Example Group"
  website: "https://example.test/home"
  meetup: ""
  aftergame: "https://aftergame.app/groups/example"
  facebook: "https://facebook.com/example"
  discord: "https://discord.gg/example"
  bgg: ""
  events:
    recurring:
      - signup: "https://example.test/book"
    adhoc:
      - signup: ""
  ---
YAML

Dir.mktmpdir do |dir|
  path = File.join(dir, "example.md")
  File.write(path, club)
  targets, error = LinkCheck.collect_file(path, "source/_clubs/example.md")

  check(error.nil?, "valid club should parse")
  fields = targets.map(&:field)
  check(fields == ["website", "aftergame", "events.recurring[0].signup"], "collects checkable links only, got #{fields.inspect}")
  check(targets.map(&:url) == [
    "https://example.test/home",
    "https://aftergame.app/groups/example",
    "https://example.test/book"
  ], "keeps URL text")
  check(targets.all? { |target| target.name == "Example Group" }, "uses the group name")
end

broken = <<~YAML
  ---
  name: "Broken
  website: "https://example.test"
  ---
YAML

Dir.mktmpdir do |dir|
  path = File.join(dir, "broken.md")
  File.write(path, broken)
  targets, error = LinkCheck.collect_file(path, "source/_clubs/broken.md")
  check(targets.empty?, "broken YAML yields no targets")
  check(error&.include?("source/_clubs/broken.md"), "broken YAML is reported, got #{error.inspect}")
end

today = Date.new(2026, 9, 28)
check(!LinkCheck.past_event?({ "startdate" => Date.new(2026, 9, 28) }, "adhoc", today: today), "an event today is still listed")
check(LinkCheck.past_event?({ "startdate" => Date.new(2026, 9, 27) }, "adhoc", today: today), "an event yesterday is past")
check(!LinkCheck.past_event?({ "startdate" => Date.new(2026, 9, 29) }, "adhoc", today: today), "an event tomorrow is listed")
check(
  LinkCheck.past_event?({ "rrule" => "FREQ=WEEKLY;BYDAY=TU;UNTIL=20260901T220000" }, "recurring", today: today),
  "a recurring series whose UNTIL date has passed is past"
)
check(
  !LinkCheck.past_event?({ "rrule" => "FREQ=WEEKLY;BYDAY=TU" }, "recurring", today: today),
  "an open-ended recurring series is listed"
)
check(
  !LinkCheck.past_event?({ "rrule" => "FREQ=WEEKLY;BYDAY=TU;UNTIL=20261231T220000" }, "recurring", today: today),
  "a recurring series that ends later is listed"
)
check(LinkCheck.british_summer_time?(Time.utc(2026, 7, 1, 12)), "July is British Summer Time")
check(!LinkCheck.british_summer_time?(Time.utc(2026, 1, 15, 12)), "January is GMT")
check(!LinkCheck.british_summer_time?(Time.utc(2026, 3, 29, 0, 30)), "the hour before the March clock change is GMT")
check(LinkCheck.british_summer_time?(Time.utc(2026, 3, 29, 1, 0)), "01:00 UTC on the March clock change is British Summer Time")

dated = <<~YAML
  ---
  name: "Dated Group"
  events:
    adhoc:
      - signup: "https://example.test/old"
        startdate: 2000-01-01
      - signup: "https://example.test/soon"
        startdate: 2999-01-01
    recurring:
      - signup: "https://example.test/ended"
        rrule: "FREQ=WEEKLY;BYDAY=TU;UNTIL=20000101T220000"
      - signup: "https://example.test/weekly"
        rrule: "FREQ=WEEKLY;BYDAY=TU"
  ---
YAML

Dir.mktmpdir do |dir|
  path = File.join(dir, "dated.md")
  File.write(path, dated)
  targets, error = LinkCheck.collect_file(path, "source/_clubs/dated.md")
  check(error.nil?, "dated club should parse")
  check(targets.map(&:url) == ["https://example.test/weekly", "https://example.test/soon"], "skips signup links for finished events, got #{targets.map(&:url).inspect}")
end

compact = LinkCheck.compact_targets([
  LinkCheck::Target.new(rel: "source/_clubs/example.md", name: "Example Group", field: "website", url: "https://example.test/book"),
  LinkCheck::Target.new(rel: "source/_clubs/example.md", name: "Example Group", field: "events.adhoc[0].signup", url: "https://example.test/book"),
  LinkCheck::Target.new(rel: "source/_clubs/example.md", name: "Example Group", field: "events.adhoc[1].signup", url: "https://example.test/book"),
  LinkCheck::Target.new(rel: "source/_clubs/example.md", name: "Example Group", field: "events.adhoc[0].signup", url: "https://example.test/other")
])
check(compact.length == 2, "same URL in one file collapses to one target, got #{compact.length}")
check(compact[0].field == "website, signup ×2", "collapsed field label, got #{compact[0].field.inspect}")
check(compact[1].field == "events.adhoc[0].signup", "a distinct signup stays specific, got #{compact[1].field.inspect}")

status, detail = LinkCheck.check_url("not a url")
check(status == :suspect && detail == "Unparseable URL", "unparseable URL is suspect, got #{status} #{detail}")

status, detail = LinkCheck.check_url("mailto:group@example.test")
check(status == :suspect && detail == "Not an http(s) URL", "non-http URL is suspect, got #{status} #{detail}")

status, detail = LinkCheck.check_url("http://")
check(status == :suspect && detail == "URL has no host", "hostless URL is suspect, got #{status} #{detail}")

server = TCPServer.new("127.0.0.1", 0)
port = server.addr[1]
thread = Thread.new do
  loop do
    client = nil
    client = server.accept
    request = +""
    while (line = client.gets)
      request << line
      break if line == "\r\n"
    end
    path = request[/\A\S+ (\S+)/, 1]
    status_line, body = case path
                        when "/ok" then ["200 OK", "ok"]
                        when "/gone" then ["404 Not Found", "missing"]
                        when "/nope" then ["410 Gone", "gone"]
                        else ["500 Internal Server Error", "no"]
                        end
    client.write(
      "HTTP/1.1 #{status_line}\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}"
    )
  rescue IOError, Errno::EBADF
    break
  ensure
    client&.close
  end
end

begin
  status, detail = LinkCheck.check_url("http://127.0.0.1:#{port}/ok")
  check(status == :ok && detail == "200", "200 is ok, got #{status} #{detail}")

  status, detail = LinkCheck.check_url("http://127.0.0.1:#{port}/gone")
  check(status == :dead && detail == "404 page gone", "404 is dead, got #{status} #{detail}")

  status, detail = LinkCheck.check_url("http://127.0.0.1:#{port}/nope")
  check(status == :dead && detail == "410 page gone", "410 is dead, got #{status} #{detail}")
ensure
  server.close
  thread.join
end

probe = TCPServer.new("127.0.0.1", 0)
closed_port = probe.addr[1]
probe.close
status, detail = LinkCheck.check_url("http://127.0.0.1:#{closed_port}/")
check(status == :dead && detail == "Connection refused", "refused connection is dead, got #{status} #{detail}")

if $failures.zero?
  puts "check_links tests passed"
  exit 0
else
  warn "#{$failures} check_links test(s) failed"
  exit 1
end

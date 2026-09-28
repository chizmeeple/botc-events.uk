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

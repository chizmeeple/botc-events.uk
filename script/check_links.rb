#!/usr/bin/env ruby
# frozen_string_literal: true

# Checks group and special-event links for signs of being dead and writes a
# maintainer-only report. It never appears on the site; it just helps spot
# stale listings in a community-maintained directory where links go bad.
#
# What it flags:
#   - DNS failure (domain no longer resolves)
#   - Connection refused / timeout (server gone)
#   - 404 / 410 (page removed)
#   - 5xx (server broken)
# What it skips (too noisy to check from a bot):
#   - facebook / discord links. These return 403/429 to non-browser clients
#     whether or not the group exists, so checking them tells us nothing.
#   - signup links for events that have already finished, because those are
#     not shown on the site. An adhoc or special event is finished when its
#     start date is before today in Europe/London. A recurring series is
#     finished when its RRULE UNTIL date is before today.
#
# Usage:
#   ruby script/check_links.rb              # check everything, write reports/dead_links.md
#   ruby script/check_links.rb --limit 50   # only first 50 files (quick smoke test)
#   ruby script/check_links.rb --json       # also write reports/dead_links.json
#
# Uses only the Ruby stdlib. Exit code is always 0 (it's a report, not a gate)
# unless something goes structurally wrong.

require "date"
require "json"
require "net/http"
require "thread"
require "uri"
require "yaml"

module LinkCheck
  # Links we actually check. facebook/discord deliberately excluded (see header).
  CHECKABLE = %w[website meetup aftergame bgg].freeze
  EVENT_LISTS = %w[recurring adhoc special].freeze

  TIMEOUT = 12        # seconds per request
  CONCURRENCY = 12    # parallel checker threads
  RETRIES = 1         # one retry on a transient network error before giving up

  Target = Struct.new(:rel, :name, :field, :url, keyword_init: true)

  module_function

  def collect_file(path, rel)
    content = File.read(path)
    parts = content.split(/^---\s*$/, 3)
    return [[], nil] if parts.length < 3

    data = YAML.safe_load(parts[1], permitted_classes: [Date])
    return [[], nil] unless data.is_a?(Hash)

    name = data["name"].is_a?(String) && !data["name"].strip.empty? ? data["name"] : rel
    targets = []

    CHECKABLE.each do |field|
      append_target(targets, rel, name, field, data[field])
    end

    events = data["events"]
    if events.is_a?(Hash)
      EVENT_LISTS.each do |kind|
        list = events[kind]
        next unless list.is_a?(Array)

        list.each_with_index do |event, index|
          next unless event.is_a?(Hash)
          next if past_event?(event, kind)

          append_target(targets, rel, name, "events.#{kind}[#{index}].signup", event["signup"])
        end
      end
    end

    [targets, nil]
  rescue Psych::SyntaxError => e
    [[], "#{rel}: #{e.message}"]
  end

  # UK civil time: BST from 01:00 UTC on the last Sunday of March until 01:00 UTC
  # on the last Sunday of October.
  def british_summer_time?(utc)
    year = utc.year
    start_t = Time.utc(year, 3, last_sunday(year, 3).day, 1, 0, 0)
    end_t = Time.utc(year, 10, last_sunday(year, 10).day, 1, 0, 0)
    utc >= start_t && utc < end_t
  end

  def last_sunday(year, month)
    date = Date.new(year, month, -1)
    date - date.wday
  end

  def london_today(now = Time.now)
    utc = now.utc
    offset = british_summer_time?(utc) ? 3600 : 0
    local = utc.getlocal(offset)
    Date.new(local.year, local.month, local.day)
  end

  def event_date(value)
    return value if value.is_a?(Date)
    return nil if value.nil? || value.to_s.strip.empty?

    Date.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def until_date(rrule)
    match = rrule.to_s.match(/UNTIL=(\d{8})/)
    return nil unless match

    Date.strptime(match[1], "%Y%m%d")
  rescue ArgumentError
    nil
  end

  # True when this event would not be listed. Compared by date in Europe/London,
  # so an event happening today is still checked.
  def past_event?(event, kind, today: london_today)
    case kind
    when "adhoc", "special"
      date = event_date(event["startdate"])
      date && date < today
    when "recurring"
      finished = until_date(event["rrule"])
      if finished
        finished < today
      else
        rrule = event["rrule"].to_s.strip
        date = event_date(event["startdate"])
        rrule.empty? && date && date < today
      end
    else
      false
    end
  end

  def append_target(targets, rel, name, field, url)
    return if url.nil?

    text = url.to_s.strip
    return if text.empty?

    targets << Target.new(rel: rel, name: name, field: field, url: text)
  end

  # One row per file and URL. Repeated event signup links collapse to "signup ×N".
  def compact_targets(targets)
    targets.group_by { |target| [target.rel, target.url] }.map do |_key, group|
      target = group.first.dup
      target.field = compact_field(group.map(&:field))
      target
    end
  end

  def compact_field(fields)
    signups, rest = fields.partition { |field| field.end_with?(".signup") }
    parts = rest.dup
    if signups.length == 1
      parts << signups.first
    elsif signups.length > 1
      parts << "signup ×#{signups.length}"
    end
    parts.join(", ")
  end

  # Returns [status_symbol, detail_string]. Symbols: :ok, :dead, :suspect
  def check_url(raw_url)
    uri = begin
      URI.parse(raw_url)
    rescue URI::InvalidURIError
      return [:suspect, "Unparseable URL"]
    end
    return [:suspect, "Not an http(s) URL"] unless uri.is_a?(URI::HTTP)
    return [:suspect, "URL has no host"] if uri.host.nil? || uri.host.empty?

    attempt = 0
    begin
      attempt += 1
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.is_a?(URI::HTTPS)
      http.open_timeout = TIMEOUT
      http.read_timeout = TIMEOUT
      # Many servers reject HEAD or bot user agents; use GET with a browser-ish
      # user agent. A redirect counts as alive: net/http does not follow it.
      req = Net::HTTP::Get.new(uri.request_uri.empty? ? "/" : uri.request_uri)
      req["User-Agent"] = "Mozilla/5.0 (compatible; botc-events-linkcheck/1.0; +https://botc-events.uk)"
      req["Accept"] = "text/html,*/*"

      res = http.request(req)
      code = res.code.to_i

      case code
      when 200..299 then [:ok, code.to_s]
      when 300..399 then [:ok, "#{code} redirect"]
      when 401, 403, 429 then [:ok, "#{code} (blocked bot, host alive)"]
      when 404, 410 then [:dead, "#{code} page gone"]
      when 500..599 then [:suspect, "#{code} server error"]
      else [:suspect, "HTTP #{code}"]
      end
    rescue SocketError
      # DNS / host resolution failure: the strongest signal of a dead domain.
      [:dead, "Domain does not resolve (DNS)"]
    rescue Net::OpenTimeout, Net::ReadTimeout
      retry if attempt <= RETRIES
      [:suspect, "Timeout after #{TIMEOUT}s"]
    rescue Errno::ECONNREFUSED
      [:dead, "Connection refused"]
    rescue OpenSSL::SSL::SSLError => e
      [:suspect, "SSL error: #{e.message.split("\n").first}"]
    rescue StandardError => e
      retry if attempt <= RETRIES
      [:suspect, "#{e.class}: #{e.message.split("\n").first}"]
    end
  end

  def listing_files(root_dir, limit: nil)
    clubs_dir = File.join(root_dir, "source", "_clubs")
    special_dir = File.join(root_dir, "source", "_special_events")
    unless Dir.exist?(clubs_dir)
      warn "ERROR: source/_clubs/ not found at #{clubs_dir}"
      return nil
    end

    files = Dir.glob(File.join(clubs_dir, "*.md"))
    files.concat(Dir.glob(File.join(special_dir, "*.md"))) if Dir.exist?(special_dir)
    files.sort!
    files = files.first(limit) if limit
    files
  end

  def check_files(files, root_dir)
    targets = []
    parse_errors = []

    files.each do |file|
      rel = file.sub("#{root_dir}/", "")
      found, error = collect_file(file, rel)
      parse_errors << error if error
      targets.concat(found)
    end

    targets = compact_targets(targets)
    warn "Checking #{targets.map(&:url).uniq.length} unique links across #{files.length} files (#{CONCURRENCY} at a time)..."

    results = run_checks(targets)
    order = { dead: 0, suspect: 1 }
    results.sort_by! { |row| [order[row[:status]], row[:rel], row[:field]] }

    {
      targets: targets,
      files: files,
      dead: results.select { |row| row[:status] == :dead },
      suspect: results.select { |row| row[:status] == :suspect },
      parse_errors: parse_errors
    }
  end

  def run_checks(targets)
    urls = targets.map(&:url).uniq
    queue = Queue.new
    urls.each { |url| queue << url }
    statuses = {}
    statuses_mutex = Mutex.new
    done = 0
    done_mutex = Mutex.new

    workers = Array.new([CONCURRENCY, 1].max) do
      Thread.new do
        loop do
          url = begin
            queue.pop(true)
          rescue ThreadError
            break
          end
          status, detail = check_url(url)
          done_mutex.synchronize do
            done += 1
            warn "  [#{done}/#{urls.length}] checked" if (done % 50).zero?
          end
          next if status == :ok

          statuses_mutex.synchronize { statuses[url] = [status, detail] }
        end
      end
    end
    workers.each(&:join)

    targets.filter_map do |target|
      status, detail = statuses[target.url]
      next unless status

      {
        rel: target.rel,
        name: target.name,
        field: target.field,
        url: target.url,
        status: status,
        detail: detail
      }
    end
  end

  def render_report(summary, generated:)
    dead = summary[:dead]
    suspect = summary[:suspect]
    lines = []
    lines << "# Potentially dead links"
    lines << ""
    lines << "_Generated #{generated} by `script/check_links.rb`._"
    lines << ""
    lines << "Checked **#{summary[:targets].map { |target| target.url }.uniq.length}** unique links (`website`, `meetup`, `aftergame`, `bgg`, event `signup`) across **#{summary[:files].length}** group and special-event files."
    lines << "Facebook/Discord links are not auto-checked (they block bots). Signup links for events that have already finished are not checked."
    lines << ""
    lines << "- 🔴 **#{dead.length}** likely dead (DNS failure, connection refused, 404/410)"
    lines << "- 🟡 **#{suspect.length}** suspect (timeout, server error, SSL — may be transient, re-check before acting)"
    lines << ""

    append_table(lines, dead, "🔴 Likely dead")
    append_table(lines, suspect, "🟡 Suspect (verify before acting)")

    unless summary[:parse_errors].empty?
      lines << "## ⚠️ Files that couldn't be parsed"
      lines << ""
      summary[:parse_errors].each { |error| lines << "- #{error}" }
      lines << ""
    end

    lines.join("\n") + "\n"
  end

  def append_table(lines, rows, heading)
    lines << "## #{heading}"
    lines << ""
    if rows.empty?
      lines << "_None._"
      lines << ""
      return
    end

    lines << "| Group | Field | URL | Reason | File |"
    lines << "|-------|-------|-----|--------|------|"
    rows.each do |row|
      safe_url = row[:url].gsub("|", "%7C")
      lines << "| #{row[:name]} | `#{row[:field]}` | #{safe_url} | #{row[:detail]} | `#{row[:rel]}` |"
    end
    lines << ""
  end

  def write_reports(root_dir, summary, json:)
    report_dir = File.join(root_dir, "reports")
    Dir.mkdir(report_dir) unless Dir.exist?(report_dir)

    generated = ENV["LINKCHECK_DATE"] || Time.now.utc.strftime("%Y-%m-%d %H:%M UTC")
    report_path = File.join(report_dir, "dead_links.md")
    File.write(report_path, render_report(summary, generated: generated))
    warn "Wrote #{report_path}"

    if json
      json_path = File.join(report_dir, "dead_links.json")
      File.write(json_path, JSON.pretty_generate(
        generated: generated,
        checked: summary[:targets].map { |target| target.url }.uniq.length,
        files: summary[:files].length,
        dead: summary[:dead],
        suspect: summary[:suspect]
      ) + "\n")
      warn "Wrote #{json_path}"
    end

    generated
  end

  def run(argv, root_dir: File.expand_path("..", __dir__))
    limit = nil
    want_json = false
    args = argv.dup
    until args.empty?
      arg = args.shift
      case arg
      when "--limit" then limit = args.shift.to_i
      when "--json" then want_json = true
      else
        warn "ERROR: unknown argument #{arg}"
        return 1
      end
    end

    files = listing_files(root_dir, limit: limit)
    return 1 if files.nil?
    if files.empty?
      warn "No listing files matched."
      return 1
    end

    summary = check_files(files, root_dir)
    write_reports(root_dir, summary, json: want_json)

    checked = summary[:targets].map { |target| target.url }.uniq.length
    puts "LINKCHECK_RESULT dead=#{summary[:dead].length} suspect=#{summary[:suspect].length} checked=#{checked}"
    0
  end
end

if $PROGRAM_NAME == __FILE__
  exit LinkCheck.run(ARGV)
end

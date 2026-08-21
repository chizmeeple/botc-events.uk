#!/usr/bin/env ruby
# frozen_string_literal: true

# Lists group and special-event pages that change between two git refs.
# Usage: ruby script/changed_group_pages.rb [base_sha] [head_sha]
#        ruby script/changed_group_pages.rb --repo PATH [base_sha] [head_sha]
#
# Defaults: origin/main (or main) ... HEAD
# Requires only Ruby stdlib — no gems needed.

require "date"
require "open3"
require "yaml"

module ChangedGroupPages
  SITE_URL = "https://botc-events.uk"
  CLUBS_PREFIX = "source/_clubs/"
  SPECIAL_PREFIX = "source/_special_events/"
  EMPTY_MESSAGE = "No groups or events were modified in this PR."
  DEFAULT_BASE_REFS = %w[origin/main main origin/master master].freeze

  Change = Struct.new(:kind, :collection, :slug, :name, :old_slug, keyword_init: true)

  module_function

  def parse_args(argv)
    args = argv.dup
    repo = File.expand_path("..", __dir__)
    if args[0] == "--repo"
      abort("Usage: ruby script/changed_group_pages.rb [--repo PATH] [base_sha] [head_sha]") if args.length < 2

      args.shift
      repo = args.shift
    end
    [repo, args[0], args[1]]
  end

  def default_base(repo)
    DEFAULT_BASE_REFS.find { |ref| git_success?(repo, "rev-parse", "--verify", "--quiet", "#{ref}^{commit}") } ||
      abort("Could not determine a base ref. Pass base and head SHAs.")
  end

  def git(repo, *args)
    stdout, stderr, status = Open3.capture3("git", "-C", repo, *args)
    abort("git #{args.join(' ')} failed: #{stderr.strip}") unless status.success?

    stdout
  end

  def git_success?(repo, *args)
    _stdout, _stderr, status = Open3.capture3("git", "-C", repo, *args)
    status.success?
  end

  def git_show(repo, ref, path)
    stdout, _stderr, status = Open3.capture3("git", "-C", repo, "show", "#{ref}:#{path}")
    status.success? ? stdout : nil
  end

  def parse_name_status(output)
    output.each_line.filter_map do |line|
      line = line.chomp
      next if line.empty?

      status, first, second = line.split("\t", 3)
      code = status[0]
      case code
      when "R", "C"
        { status: code, old_path: first, path: second }
      else
        { status: code, path: first }
      end
    end
  end

  def classify(path)
    return unless path.is_a?(String) && path.end_with?(".md")

    if path.start_with?(CLUBS_PREFIX) && path.delete_prefix(CLUBS_PREFIX).count("/") == 0
      [:clubs, File.basename(path, ".md")]
    elsif path.start_with?(SPECIAL_PREFIX) && path.delete_prefix(SPECIAL_PREFIX).count("/") == 0
      [:special_events, File.basename(path, ".md")]
    end
  end

  def display_name(name, location:, fallback:)
    base = name.is_a?(String) && !name.strip.empty? ? name.strip : fallback
    loc = location.is_a?(String) ? location.strip : ""
    loc.empty? ? base : "#{base} (#{loc})"
  end

  def name_from_content(content, fallback:)
    return fallback if content.nil? || content.empty?
    return fallback unless content.match?(/\A---\s*\n/)

    parts = content.split(/^---\s*$/, 3)
    return fallback if parts.length < 3

    data = YAML.safe_load(parts[1], permitted_classes: [Date])
    return fallback unless data.is_a?(Hash)

    display_name(data["name"], location: data["based_in"], fallback: fallback)
  rescue Psych::SyntaxError, Psych::DisallowedClass
    fallback
  end

  def changes_from_entries(entries)
    entries.filter_map do |entry|
      new_class = classify(entry[:path])
      old_class = classify(entry[:old_path])

      case entry[:status]
      when "A", "C"
        next unless new_class

        collection, slug = new_class
        Change.new(kind: :added, collection: collection, slug: slug, name: slug)
      when "D"
        next unless new_class || old_class

        collection, slug = new_class || old_class
        Change.new(kind: :deleted, collection: collection, slug: slug, name: slug)
      when "R"
        if new_class && old_class && new_class[0] == old_class[0]
          collection, slug = new_class
          Change.new(kind: :renamed, collection: collection, slug: slug, name: slug, old_slug: old_class[1])
        elsif new_class
          collection, slug = new_class
          Change.new(kind: :added, collection: collection, slug: slug, name: slug)
        elsif old_class
          collection, slug = old_class
          Change.new(kind: :deleted, collection: collection, slug: slug, name: slug)
        end
      when "M", "T"
        next unless new_class

        collection, slug = new_class
        Change.new(kind: :modified, collection: collection, slug: slug, name: slug)
      end
    end
  end

  def fill_names(changes, repo:, base:, head:)
    changes.each do |change|
      prefix = change.collection == :clubs ? CLUBS_PREFIX : SPECIAL_PREFIX
      path = "#{prefix}#{change.slug}.md"
      ref = change.kind == :deleted ? base : head
      fallback = change.slug
      change.name = name_from_content(git_show(repo, ref, path), fallback: fallback)
    end
  end

  def url_for(collection, slug)
    if collection == :clubs
      "#{SITE_URL}/clubs/#{slug}/"
    else
      "#{SITE_URL}/special/#{slug}/"
    end
  end

  def markdown_label(text)
    text.gsub("[", "\\[").gsub("]", "\\]")
  end

  def list_item(change)
    label = markdown_label(change.name)
    url = url_for(change.collection, change.slug)
    item = "- [#{label}](#{url})"
    if change.kind == :renamed && change.old_slug && change.old_slug != change.slug
      old_url = url_for(change.collection, change.old_slug)
      item += " (was [#{markdown_label(change.old_slug)}](#{old_url}))"
    end
    item
  end

  def section(title, items)
    return if items.empty?

    sorted = items.sort_by { |change| [change.name.downcase, change.slug] }
    ["## #{title}", "", *sorted.map { |change| list_item(change) }].join("\n")
  end

  def render(changes)
    return EMPTY_MESSAGE if changes.empty?

    clubs = changes.select { |change| change.collection == :clubs }
    specials = changes.select { |change| change.collection == :special_events }

    parts = [
      section("New Groups", clubs.select { |change| change.kind == :added }),
      section("Updated Groups / Events", clubs.select { |change| %i[modified renamed].include?(change.kind) }),
      section("Removed Groups", clubs.select { |change| change.kind == :deleted }),
      section("New Special Events", specials.select { |change| change.kind == :added }),
      section("Updated Special Events", specials.select { |change| %i[modified renamed].include?(change.kind) }),
      section("Removed Special Events", specials.select { |change| change.kind == :deleted })
    ].compact

    parts.empty? ? EMPTY_MESSAGE : parts.join("\n\n")
  end

  def run(repo:, base:, head:)
    diff = git(
      repo,
      "diff",
      "--name-status",
      "--find-renames",
      "--diff-filter=ACDMRT",
      "#{base}...#{head}",
      "--",
      "source/_clubs/",
      "source/_special_events/"
    )
    changes = changes_from_entries(parse_name_status(diff))
    fill_names(changes, repo: repo, base: base, head: head)
    render(changes)
  end
end

if $PROGRAM_NAME == __FILE__
  repo, base_arg, head_arg = ChangedGroupPages.parse_args(ARGV)
  base = base_arg || ChangedGroupPages.default_base(repo)
  head = head_arg || "HEAD"
  puts ChangedGroupPages.run(repo: repo, base: base, head: head)
end

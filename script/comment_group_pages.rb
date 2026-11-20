#!/usr/bin/env ruby
# frozen_string_literal: true

# Posts the group-page summary produced by the Validate PR workflow.
#
# The artifact is untrusted: a fork controls its contents. This script reads
# two data files, checks the pull request against the triggering workflow run,
# and sends the summary to the GitHub API as a comment body. It never executes
# artifact contents or interpolates them into a shell command.

require "json"
require "open3"
require "tempfile"

class CommentGroupPages
  MARKER = "<!-- group-pages-preview -->"
  WORKFLOW_PATH = ".github/workflows/validate-pr.yml"
  # User id of the GitHub Actions app (github-actions[bot]).
  BOT_ID = 41_898_282
  BOT_LOGIN = "github-actions[bot]"
  MAX_ID = 10**18
  MAX_METADATA_BYTES = 1024
  MAX_SUMMARY_BYTES = 60_000
  MAX_COMMENT_LENGTH = 65_536
  REPOSITORY_NAME = /\A[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\z/
  COMMIT_SHA = /\A[0-9a-f]{40}\z|\A[0-9a-f]{64}\z/
  TIMESTAMP = /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z\z/
  RUN_STAMP = /\A<!-- group-pages-run-id:(\d{1,18}) created-at:(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z) -->\z/
  ARTIFACT_FILES = %w[group-pages-meta.json group-pages.md].freeze

  Error = Class.new(StandardError)
  Result = Struct.new(:action, :pull_request, keyword_init: true) do
    def message
      case action
      when :created
        "Created the group pages comment on pull request #{pull_request}."
      when :updated
        "Updated the group pages comment on pull request #{pull_request}."
      when :skipped
        "Left the group pages comment on pull request #{pull_request}; a newer summary is already posted."
      else
        "Recorded the group pages comment on pull request #{pull_request}."
      end
    end
  end

  def self.apply(env:, gh: nil)
    new(env: env, gh: gh || method(:invoke_gh)).apply
  end

  def self.invoke_gh(args)
    unless args.is_a?(Array) && args.all? { |arg| arg.is_a?(String) && !arg.include?("\0") }
      raise Error, "invalid gh arguments"
    end

    stdout, stderr, status = Open3.capture3("gh", *args)
    return stdout if status.success?

    detail = stderr.to_s.lines.first.to_s.strip
    detail = "gh api request failed" if detail.empty?
    raise Error, detail
  rescue SystemCallError => e
    raise Error, "could not run gh: #{e.message}"
  end

  def initialize(env:, gh:)
    @env = env
    @gh = gh
  end

  def apply
    repository = repository_name(fetch_env("GITHUB_REPOSITORY"), "repository")
    run_id = positive_integer(fetch_env("WORKFLOW_RUN_ID"), "workflow run id")
    artifact_dir = artifact_directory(fetch_env("ARTIFACT_DIR"))
    pr_number, summary = read_artifact(artifact_dir)

    run = get_json("repos/#{repository}/actions/runs/#{run_id}")
    created_at = verify_run!(run, repository, run_id, pr_number)
    pull = get_json("repos/#{repository}/pulls/#{pr_number}")
    verify_pull!(pull, repository, pr_number, run)

    body = comment_body(summary, run_id, created_at)
    sync_comment(repository, pr_number, body, run_id, created_at)
  end

  private

  def fetch_env(key)
    value = @env[key]
    raise Error, "missing #{key}" if !value.is_a?(String) || value.empty?

    value
  end

  def repository_name(value, label)
    raise Error, "invalid #{label}" unless value.is_a?(String) && value.match?(REPOSITORY_NAME)
    raise Error, "invalid #{label}" if value.bytesize > 140

    owner, repo = value.split("/", 2)
    if [owner, repo].any? { |part| part == "." || part == ".." || part.start_with?(".") }
      raise Error, "invalid #{label}"
    end

    value
  end

  def positive_integer(value, label)
    raise Error, "invalid #{label}" unless value.is_a?(String) && value.match?(/\A[1-9][0-9]{0,17}\z/)

    number = Integer(value, 10)
    raise Error, "invalid #{label}" if number > MAX_ID

    number
  end

  def artifact_directory(path)
    raise Error, "artifact directory is invalid" if !path.is_a?(String) || path.empty? || path.include?("\0")

    stat = File.lstat(path)
    raise Error, "artifact directory is invalid" unless stat.directory?

    candidate = artifact_root(path)
    raise Error, "artifact contents are invalid" unless candidate

    candidate
  rescue SystemCallError
    raise Error, "artifact directory is missing"
  end

  def artifact_root(path)
    return path if artifact_files?(path)

    names = Dir.children(path)
    return nil unless names.size == 1

    nested = File.join(path, names.first)
    return nested if File.lstat(nested).directory? && artifact_files?(nested)

    nil
  end

  def artifact_files?(path)
    Dir.children(path).sort == ARTIFACT_FILES.sort
  end

  def read_artifact(dir)
    [read_pr_number(File.join(dir, "group-pages-meta.json")), read_summary(File.join(dir, "group-pages.md"))]
  end

  def read_regular_file(path, limit)
    stat = File.lstat(path)
    raise Error, "artifact file is invalid" unless stat.file?
    raise Error, "artifact file is too large" if stat.size > limit

    File.binread(path)
  rescue SystemCallError
    raise Error, "artifact file is missing"
  end

  def read_pr_number(path)
    raw = read_regular_file(path, MAX_METADATA_BYTES)
    begin
      data = JSON.parse(raw)
    rescue JSON::ParserError
      raise Error, "pull request metadata is not valid JSON"
    end
    raise Error, "pull request metadata must be an object" unless data.is_a?(Hash)

    number = data["pr_number"]
    unless number.is_a?(Integer) && number.positive? && number <= MAX_ID
      raise Error, "pull request metadata pr_number must be a positive integer"
    end

    number
  end

  def read_summary(path)
    raw = read_regular_file(path, MAX_SUMMARY_BYTES)
    raise Error, "group pages summary is empty" if raw.empty?
    raise Error, "group pages summary contains null bytes" if raw.include?("\0".b)

    summary = raw.force_encoding(Encoding::UTF_8)
    raise Error, "group pages summary must be UTF-8 text" unless summary.valid_encoding?

    summary
  end

  def get_json(path)
    parse_json(@gh.call(["api", path]))
  end

  def parse_json(raw)
    JSON.parse(raw)
  rescue JSON::ParserError
    raise Error, "GitHub API returned invalid JSON"
  end

  def verify_run!(run, repository, run_id, pr_number)
    raise Error, "workflow run response was not an object" unless run.is_a?(Hash)
    raise Error, "workflow run id does not match" unless run["id"] == run_id
    raise Error, "workflow run was not triggered by pull_request" unless run["event"] == "pull_request"
    raise Error, "workflow run did not succeed" unless run["conclusion"] == "success"
    raise Error, "workflow run is not #{WORKFLOW_PATH}" unless run["path"] == WORKFLOW_PATH

    url = run["url"]
    unless url.is_a?(String) && url.include?("/repos/#{repository}/actions/runs/#{run_id}")
      raise Error, "workflow run does not belong to #{repository}"
    end

    head_sha = run["head_sha"]
    raise Error, "workflow run head SHA is invalid" unless head_sha.is_a?(String) && head_sha.match?(COMMIT_SHA)

    head_branch = run["head_branch"]
    raise Error, "workflow run head branch is invalid" unless valid_branch?(head_branch)

    head_repo = run["head_repository"]
    raise Error, "workflow run has no head repository" unless head_repo.is_a?(Hash)
    repository_name(head_repo["full_name"], "head repository")
    head_repo_id = head_repo["id"]
    raise Error, "workflow run head repository is invalid" unless head_repo_id.is_a?(Integer) && head_repo_id.positive? && head_repo_id <= MAX_ID

    numbers = associated_pull_requests(run["pull_requests"])
    if numbers.any? && !numbers.include?(pr_number)
      raise Error, "pull request is not associated with the workflow run"
    end

    normalize_timestamp(run["created_at"])
  end

  def associated_pull_requests(value)
    value = [] if value.nil?
    raise Error, "workflow run pull request list is invalid" unless value.is_a?(Array)

    value.map do |item|
      raise Error, "workflow run pull request list is invalid" unless item.is_a?(Hash)

      number = item["number"]
      unless number.is_a?(Integer) && number.positive? && number <= MAX_ID
        raise Error, "workflow run pull request list is invalid"
      end

      number
    end
  end

  def valid_branch?(value)
    value.is_a?(String) && !value.empty? && value.bytesize <= 255 && !value.match?(/[[:cntrl:]]/)
  end

  def normalize_timestamp(value)
    raise Error, "workflow run timestamp is invalid" unless value.is_a?(String) && value.match?(TIMESTAMP)

    value.sub(/\.\d+Z\z/, "Z")
  end

  def verify_pull!(pull, repository, pr_number, run)
    raise Error, "pull request response was not an object" unless pull.is_a?(Hash)
    raise Error, "pull request number does not match the artifact" unless pull["number"] == pr_number

    url = pull["url"]
    unless url.is_a?(String) && url.include?("/repos/#{repository}/pulls/#{pr_number}")
      raise Error, "pull request does not belong to #{repository}"
    end
    raise Error, "pull request is not in #{repository}" unless pull.dig("base", "repo", "full_name") == repository
    unless pull.dig("head", "sha") == run["head_sha"]
      raise Error, "pull request head does not match the workflow run"
    end
    unless pull.dig("head", "ref") == run["head_branch"]
      raise Error, "pull request branch does not match the workflow run"
    end
    raise Error, "pull request head repository does not match the workflow run" unless pull.dig("head", "repo", "id") == run.dig("head_repository", "id")
    raise Error, "pull request head repository does not match the workflow run" unless pull.dig("head", "repo", "full_name") == run.dig("head_repository", "full_name")
  end

  def comment_body(summary, run_id, created_at)
    body = "#{MARKER}\n<!-- group-pages-run-id:#{run_id} created-at:#{created_at} -->\n\n#{summary}"
    raise Error, "comment is too long to post" if body.length > MAX_COMMENT_LENGTH

    body
  end

  def sync_comment(repository, pr_number, body, run_id, created_at)
    existing = bot_comments(repository, pr_number)
    if existing.any? { |comment| newer_comment?(comment, created_at, run_id) }
      return Result.new(action: :skipped, pull_request: pr_number)
    end

    keeper = existing.max_by { |comment| comment["id"] }
    action = :updated
    keep_id = keeper && keeper["id"]
    if keeper
      write_comment("PATCH", "repos/#{repository}/issues/comments/#{keeper["id"]}", body) if keeper["body"] != body
    else
      action = :created
      created = write_comment("POST", "repos/#{repository}/issues/#{pr_number}/comments", body)
      keep_id = created["id"]
      raise Error, "GitHub API did not return a comment id" unless keep_id.is_a?(Integer) && keep_id.positive?
    end

    current = bot_comments(repository, pr_number)
    winner = current.max_by { |comment| comment_rank(comment) }
    current.each do |comment|
      next if winner && comment["id"] == winner["id"]

      @gh.call(["api", "--method", "DELETE", "repos/#{repository}/issues/comments/#{comment["id"]}"])
    end

    action = :skipped if winner && winner["id"] != keep_id
    Result.new(action: action, pull_request: pr_number)
  end

  def bot_comments(repository, pr_number)
    raw = @gh.call([
      "api",
      "--paginate",
      "--slurp",
      "repos/#{repository}/issues/#{pr_number}/comments?per_page=100"
    ])
    pages = parse_json(raw)
    raise Error, "comment list is invalid" unless pages.is_a?(Array) && pages.all? { |page| page.is_a?(Array) }

    pages.flatten(1).select { |comment| bot_marker_comment?(comment) }
  end

  def bot_marker_comment?(comment)
    comment.is_a?(Hash) &&
      comment["id"].is_a?(Integer) &&
      comment["id"].positive? &&
      comment["id"] <= MAX_ID &&
      comment["body"].is_a?(String) &&
      comment["body"].include?(MARKER) &&
      bot_user?(comment["user"])
  end

  def bot_user?(user)
    user.is_a?(Hash) && user["id"] == BOT_ID && user["login"] == BOT_LOGIN
  end

  def newer_comment?(comment, created_at, run_id)
    stamp = run_stamp(comment["body"])
    return false unless stamp
    return true if stamp[:created_at] > created_at
    return false if stamp[:created_at] < created_at

    stamp[:run_id] > run_id
  end

  def run_stamp(body)
    line = body.to_s.lines[1]
    return nil unless line

    match = line.strip.match(RUN_STAMP)
    return nil unless match

    { run_id: Integer(match[1], 10), created_at: match[2] }
  end

  def comment_rank(comment)
    stamp = run_stamp(comment["body"])
    if stamp
      [stamp[:created_at], stamp[:run_id], comment["id"]]
    else
      ["", 0, comment["id"]]
    end
  end

  def write_comment(method, path, body)
    response = nil
    Tempfile.create(["group-pages-comment", ".json"]) do |file|
      file.binmode
      file.write(JSON.generate({ "body" => body }))
      file.flush
      response = @gh.call(["api", "--method", method, path, "--input", file.path])
    end
    parsed = parse_json(response)
    raise Error, "GitHub API comment response was not an object" unless parsed.is_a?(Hash)

    parsed
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    puts CommentGroupPages.apply(env: ENV).message
  rescue CommentGroupPages::Error => e
    warn "error: #{e.message}"
    exit 1
  end
end

#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "tempfile"
require "tmpdir"
require "yaml"

require_relative "changed_group_pages"
require_relative "comment_group_pages"

ROOT = File.expand_path("..", __dir__)
REPOSITORY = "chizmeeple/botc-events.uk"
FORK_REPOSITORY = "contributor/botc-events.uk"
HEAD_SHA = "a" * 40
BRANCH = "add-group"
RUN_ID = 4242
CREATED_AT = "2026-11-20T08:30:00Z"
PR_NUMBER = 17
SUMMARY = "No groups or events were modified in this PR.\n"
BOT = { "id" => CommentGroupPages::BOT_ID, "login" => CommentGroupPages::BOT_LOGIN, "type" => "Bot" }.freeze
HUMAN = { "id" => 42, "login" => "contributor", "type" => "User" }.freeze

failures = 0
check = lambda do |condition, message|
  return if condition

  warn "FAIL: #{message}"
  failures += 1
end

def expected_body(summary, run_id: RUN_ID, created_at: CREATED_AT)
  "#{CommentGroupPages::MARKER}\n<!-- group-pages-run-id:#{run_id} created-at:#{created_at} -->\n\n#{summary}"
end

def run_fixture(head_repository: FORK_REPOSITORY, head_repository_id: 55, pull_requests: [], created_at: CREATED_AT)
  {
    "id" => RUN_ID,
    "event" => "pull_request",
    "conclusion" => "success",
    "path" => CommentGroupPages::WORKFLOW_PATH,
    "head_sha" => HEAD_SHA,
    "head_branch" => BRANCH,
    "created_at" => created_at,
    "url" => "https://api.github.com/repos/#{REPOSITORY}/actions/runs/#{RUN_ID}",
    "head_repository" => { "id" => head_repository_id, "full_name" => head_repository },
    "pull_requests" => pull_requests
  }
end

def pull_fixture(head_repository: FORK_REPOSITORY, head_repository_id: 55)
  {
    "number" => PR_NUMBER,
    "url" => "https://api.github.com/repos/#{REPOSITORY}/pulls/#{PR_NUMBER}",
    "head" => {
      "sha" => HEAD_SHA,
      "ref" => BRANCH,
      "repo" => { "id" => head_repository_id, "full_name" => head_repository }
    },
    "base" => { "repo" => { "full_name" => REPOSITORY } }
  }
end

def base_env(dir, repository: REPOSITORY, run_id: RUN_ID)
  {
    "GITHUB_REPOSITORY" => repository,
    "WORKFLOW_RUN_ID" => run_id.to_s,
    "ARTIFACT_DIR" => dir
  }
end

def write_artifact(dir, pr: PR_NUMBER, summary: SUMMARY, extra_meta: {}, nest: false)
  root = nest ? File.join(dir, "nested") : dir
  FileUtils.mkdir_p(root)
  meta = extra_meta.merge("pr_number" => pr)
  File.write(File.join(root, "group-pages-meta.json"), JSON.generate(meta) + "\n")
  File.binwrite(File.join(root, "group-pages.md"), summary)
end

# In-memory stand-in for `gh api`. Each comment is returned on its own page so
# pagination has to be handled.
class MemoryGitHub
  attr_reader :calls, :comments

  def initialize(run:, pull:)
    @run = run
    @pull = pull
    @comments = []
    @next_id = 100
    @calls = []
  end

  def add_comment(id:, body:, user:)
    @comments << { "id" => id, "body" => body, "user" => user }
    @next_id = id + 1 if id >= @next_id
  end

  def call(args)
    @calls << args.dup
    method = args.include?("--method") ? args[args.index("--method") + 1] : "GET"
    endpoint = args.find { |arg| arg.is_a?(String) && arg.start_with?("repos/") }
    raise "missing endpoint in #{args.inspect}" unless endpoint

    case [method, endpoint_kind(endpoint)]
    when ["GET", :run]
      JSON.generate(@run)
    when ["GET", :pull]
      JSON.generate(@pull)
    when ["GET", :comments]
      pages = @comments.map { |comment| [comment.dup] }
      pages = [[]] if pages.empty?
      JSON.generate(pages)
    when ["POST", :comments]
      id = @next_id
      @next_id += 1
      @comments << { "id" => id, "body" => read_body(args), "user" => BOT.dup }
      JSON.generate({ "id" => id })
    when ["PATCH", :comment]
      comment = find_comment(endpoint)
      comment["body"] = read_body(args)
      JSON.generate({ "id" => comment["id"] })
    when ["DELETE", :comment]
      id = endpoint_id(endpoint)
      deleted = @comments.reject! { |comment| comment["id"] == id }
      raise "comment #{id} was not deleted" unless deleted
      ""
    else
      raise "unexpected gh call #{method} #{endpoint}"
    end
  end

  def methods_used
    @calls.map { |args| args.include?("--method") ? args[args.index("--method") + 1] : "GET" }
  end

  private

  def endpoint_kind(endpoint)
    return :run if endpoint.include?("/actions/runs/")
    return :pull if endpoint.include?("/pulls/")
    return :comment if endpoint.match?(%r{/issues/comments/\d+\z})

    :comments if endpoint.include?("/comments")
  end

  def endpoint_id(endpoint)
    Integer(endpoint[%r{/(\d+)\z}, 1], 10)
  end

  def find_comment(endpoint)
    id = endpoint_id(endpoint)
    comment = @comments.find { |item| item["id"] == id }
    raise "missing comment #{id}" unless comment

    comment
  end

  def read_body(args)
    input = args[args.index("--input") + 1]
    parsed = JSON.parse(File.read(input))
    body = parsed["body"]
    raise "comment body was not a JSON string" unless body.is_a?(String)

    body
  end
end

def apply_case(dir, github, summary: SUMMARY, pr: PR_NUMBER, extra_meta: {}, nest: false, env: nil)
  write_artifact(dir, pr: pr, summary: summary, extra_meta: extra_meta, nest: nest)
  CommentGroupPages.apply(env: env || base_env(dir), gh: github)
end

def assert_safe_calls(calls, summary, check)
  check.call(calls.any?, "expected at least one gh call")
  calls.each do |args|
    check.call(args[0] == "api", "gh is invoked as api, got #{args.inspect}")
    check.call(!args.include?("-F") && !args.include?("-f"), "comment body is not a typed gh field")
    check.call(args.none? { |arg| !arg.is_a?(String) || arg.include?("\n") || arg.include?("$(") || arg.include?("`") },
               "gh arguments are single safe strings")
    check.call(args.none? { |arg| arg.include?(summary) }, "summary is not passed as a gh argument") if summary
  end
  listed = calls.select { |args| args.include?("--paginate") }
  check.call(listed.any? && listed.all? { |args| args.include?("--slurp") }, "comment lookup is paginated")
end

# --- posting behaviour ---

Dir.mktmpdir("group-pages-comment-") do |dir|
  summary = ChangedGroupPages.render([
    ChangedGroupPages::Change.new(kind: :added, collection: :clubs, slug: "ipswich-v4gcl", name: "V4GCL (Testville)")
  ])
  summary += "\n$(rm -rf /) `whoami` \"; cat /etc/passwd"
  github = MemoryGitHub.new(run: run_fixture, pull: pull_fixture)
  result = apply_case(dir, github, summary: summary)

  check.call(result.action == :created, "fork pull request creates a comment (#{result.action})")
  check.call(github.comments.size == 1, "one comment is stored")
  body = github.comments.first["body"]
  check.call(body == expected_body(summary), "comment preserves the generated summary and marker\n#{body}")
  check.call(body.include?("[V4GCL (Testville)](https://botc-events.uk/clubs/ipswich-v4gcl/)"), "generated link is preserved")
  check.call(github.calls.any? { |args| args.include?("POST") && args.any? { |arg| arg == "repos/#{REPOSITORY}/issues/#{PR_NUMBER}/comments" } },
             "comment is posted to the base repository")
  assert_safe_calls(github.calls, summary, check)
end

Dir.mktmpdir("group-pages-comment-") do |dir|
  run = run_fixture(
    head_repository: REPOSITORY,
    head_repository_id: 7,
    pull_requests: [{ "number" => PR_NUMBER }]
  )
  pull = pull_fixture(head_repository: REPOSITORY, head_repository_id: 7)
  github = MemoryGitHub.new(run: run, pull: pull)
  result = apply_case(dir, github)

  check.call(result.action == :created, "same-repository pull request uses the same comment path")
  check.call(github.comments.first["body"] == expected_body(SUMMARY), "internal pull request body matches")
end

Dir.mktmpdir("group-pages-comment-") do |dir|
  github = MemoryGitHub.new(run: run_fixture, pull: pull_fixture)
  github.add_comment(id: 5, body: "#{CommentGroupPages::MARKER}\n\n#{SUMMARY}", user: BOT)
  result = apply_case(dir, github, summary: "Updated summary.\n")

  check.call(result.action == :updated, "existing bot comment is updated")
  check.call(github.comments.size == 1, "update does not add a comment")
  check.call(github.comments.first["id"] == 5, "the bot comment is patched in place")
  check.call(github.comments.first["body"] == expected_body("Updated summary.\n"), "patched body replaces the summary")
  check.call(!github.methods_used.include?("POST"), "update does not create a second comment")
end

Dir.mktmpdir("group-pages-comment-") do |dir|
  github = MemoryGitHub.new(run: run_fixture, pull: pull_fixture)
  original = "#{CommentGroupPages::MARKER}\n\nPlease ignore."
  github.add_comment(id: 8, body: original, user: HUMAN)
  result = apply_case(dir, github)

  check.call(result.action == :created, "a person's comment is left alone and a bot comment is created")
  check.call(github.comments.first["body"] == original, "a person's comment body is unchanged")
  check.call(github.comments.count { |comment| comment["user"]["id"] == BOT["id"] } == 1, "the bot comment is separate")
  check.call(!github.methods_used.include?("PATCH"), "a person's comment is not patched")
  check.call(!github.methods_used.include?("DELETE"), "a person's comment is not deleted")
end

Dir.mktmpdir("group-pages-comment-") do |dir|
  github = MemoryGitHub.new(run: run_fixture, pull: pull_fixture)
  impersonated = { "id" => 99, "login" => CommentGroupPages::BOT_LOGIN, "type" => "Bot" }
  github.add_comment(id: 4, body: "#{CommentGroupPages::MARKER}\n\nstay", user: impersonated)
  github.add_comment(id: 6, body: "Ordinary bot note", user: BOT)
  apply_case(dir, github)

  check.call(github.comments.find { |comment| comment["id"] == 4 }["body"].end_with?("stay"),
             "a comment with the bot login but a different user id is not modified")
  check.call(github.comments.find { |comment| comment["id"] == 6 }["body"] == "Ordinary bot note",
             "a bot comment without the marker is not modified")
  check.call(github.comments.count { |comment| comment["body"].include?(CommentGroupPages::MARKER) } == 2,
             "the real preview comment is added beside the untouched comments")
end

Dir.mktmpdir("group-pages-comment-") do |dir|
  github = MemoryGitHub.new(run: run_fixture, pull: pull_fixture)
  newer = expected_body("Newer summary.\n", run_id: RUN_ID + 1, created_at: "2026-11-20T09:00:00Z")
  github.add_comment(id: 11, body: newer, user: BOT)
  result = apply_case(dir, github, summary: "Stale summary.\n")

  check.call(result.action == :skipped, "a newer bot comment is kept")
  check.call(github.comments.map { |comment| comment["body"] } == [newer], "a stale run does not overwrite or duplicate")
  check.call(!github.methods_used.intersect?(["POST", "PATCH", "DELETE"]), "a stale run does not write")
end

Dir.mktmpdir("group-pages-comment-") do |dir|
  github = MemoryGitHub.new(run: run_fixture, pull: pull_fixture)
  same_time = expected_body("Other attempt.\n", run_id: RUN_ID + 5, created_at: CREATED_AT)
  github.add_comment(id: 12, body: same_time, user: BOT)
  result = apply_case(dir, github)

  check.call(result.action == :skipped, "a later run id with the same timestamp wins")
  check.call(github.comments.first["body"] == same_time, "the later run's comment stays")
end

Dir.mktmpdir("group-pages-comment-") do |dir|
  github = MemoryGitHub.new(run: run_fixture, pull: pull_fixture)
  older = expected_body("Older summary.\n", run_id: RUN_ID - 1, created_at: CREATED_AT)
  github.add_comment(id: 9, body: older, user: BOT)
  github.add_comment(id: 3, body: "#{CommentGroupPages::MARKER}\n\nDuplicate.\n", user: BOT)
  result = apply_case(dir, github, summary: "Current summary.\n")

  check.call(result.action == :updated, "the newest existing bot comment is updated")
  check.call(github.comments.size == 1, "duplicate bot comments are removed")
  check.call(github.comments.first["body"] == expected_body("Current summary.\n"), "the remaining comment is the current summary")
  check.call(github.methods_used.include?("DELETE"), "the extra bot comment is deleted")
end

Dir.mktmpdir("group-pages-comment-") do |dir|
  github = MemoryGitHub.new(run: run_fixture, pull: pull_fixture)
  disguised = "#{CommentGroupPages::MARKER}\n<!-- group-pages-run-id:1 created-at:2020-01-01T00:00:00Z -->\n\n<!-- group-pages-run-id:999999 created-at:2099-01-01T00:00:00Z -->\nignored\n"
  github.add_comment(id: 15, body: disguised, user: BOT)
  result = apply_case(dir, github, summary: "Current summary.\n")

  check.call(result.action == :updated, "a fake newer stamp inside the summary does not suppress the update")
  check.call(github.comments.first["body"] == expected_body("Current summary.\n"), "the posted body keeps the trusted run stamp on its own line")
end

Dir.mktmpdir("group-pages-comment-") do |dir|
  github = MemoryGitHub.new(run: run_fixture(created_at: "2026-11-20T08:30:00.250Z"), pull: pull_fixture)
  result = apply_case(dir, github)

  check.call(result.action == :created, "fractional workflow timestamps are accepted")
  check.call(github.comments.first["body"].include?("created-at:#{CREATED_AT}"), "timestamp is normalised to seconds")
end

Dir.mktmpdir("group-pages-comment-") do |dir|
  github = MemoryGitHub.new(run: run_fixture, pull: pull_fixture)
  apply_case(dir, github, extra_meta: { "body" => "pwned", "run_id" => 1 }, nest: true)

  check.call(github.comments.first["body"] == expected_body(SUMMARY), "metadata fields other than the pull request number are ignored")
end

# --- rejected artifacts and mismatched pull requests ---

expect_error = lambda do |message, &block|
  error = nil
  calls = []
  gh = lambda do |args|
    calls << args
    raise "gh should not have been called"
  end
  begin
    block.call(gh)
  rescue CommentGroupPages::Error => e
    error = e
  end
  check.call(error.is_a?(CommentGroupPages::Error) && error.message.include?(message),
             "expected #{message.inspect}, got #{error&.class}: #{error&.message.inspect}")
  check.call(calls.empty?, "invalid input called gh: #{calls.inspect}")
end

Dir.mktmpdir("group-pages-comment-") do |dir|
  expect_error.call("positive integer") do |gh|
    File.write(File.join(dir, "group-pages-meta.json"), %({"pr_number":"17; rm -rf /"}\n))
    File.write(File.join(dir, "group-pages.md"), SUMMARY)
    CommentGroupPages.apply(env: base_env(dir), gh: gh)
  end

  File.write(File.join(dir, "group-pages-meta.json"), "[]\n")
  expect_error.call("must be an object") do |gh|
    CommentGroupPages.apply(env: base_env(dir), gh: gh)
  end

  File.write(File.join(dir, "group-pages-meta.json"), "{not json")
  expect_error.call("not valid JSON") do |gh|
    CommentGroupPages.apply(env: base_env(dir), gh: gh)
  end

  File.write(File.join(dir, "evil.sh"), "echo pwned\n")
  File.write(File.join(dir, "group-pages-meta.json"), %({"pr_number":17}\n))
  expect_error.call("artifact contents are invalid") do |gh|
    CommentGroupPages.apply(env: base_env(dir), gh: gh)
  end
end

Dir.mktmpdir("group-pages-comment-") do |dir|
  write_artifact(dir)
  File.unlink(File.join(dir, "group-pages.md"))
  File.symlink("/etc/passwd", File.join(dir, "group-pages.md"))
  calls = []
  gh = lambda do |args|
    calls << args
    raise "gh should not have been called"
  end
  error = nil
  begin
    CommentGroupPages.apply(env: base_env(dir), gh: gh)
  rescue CommentGroupPages::Error => e
    error = e
  end
  check.call(error && error.message.include?("artifact file is invalid"), "symlink artifact is rejected (#{error&.message})")
  check.call(calls.empty?, "symlink artifact is not read as a command")
end

Dir.mktmpdir("group-pages-comment-") do |dir|
  write_artifact(dir, summary: "\xff".b)
  error = nil
  begin
    CommentGroupPages.apply(env: base_env(dir), gh: ->(*) { raise "gh should not have been called" })
  rescue CommentGroupPages::Error => e
    error = e
  end
  check.call(error && error.message.include?("UTF-8"), "invalid encoding is rejected")
end

[
  ["../evil", "invalid repository"],
  ["owner/../../etc", "invalid repository"],
  ["", "missing GITHUB_REPOSITORY"]
].each do |repository, message|
  Dir.mktmpdir("group-pages-comment-") do |dir|
    write_artifact(dir)
    env = base_env(dir)
    env["GITHUB_REPOSITORY"] = repository
    env.delete("GITHUB_REPOSITORY") if repository.empty?
    error = nil
    calls = []
    begin
      CommentGroupPages.apply(env: env, gh: lambda { |args|
        calls << args
        raise "gh should not have been called"
      })
    rescue CommentGroupPages::Error => e
      error = e
    end
    check.call(error && error.message.include?(message), "#{repository.inspect} -> #{error&.message}")
    check.call(calls.empty?, "rejected repository was used in an API call")
  end
end

expect_api_error = lambda do |message, &block|
  Dir.mktmpdir("group-pages-comment-") do |dir|
    run = run_fixture(pull_requests: [{ "number" => PR_NUMBER }])
    pull = pull_fixture
    block.call(run, pull)
    github = MemoryGitHub.new(run: run, pull: pull)
    error = nil
    begin
      apply_case(dir, github)
    rescue CommentGroupPages::Error => e
      error = e
    end
    check.call(error && error.message.include?(message), "expected #{message.inspect}, got #{error&.message.inspect}")
    check.call(github.comments.empty?, "#{message} still posted a comment")
    check.call(!github.methods_used.intersect?(["POST", "PATCH", "DELETE"]), "#{message} wrote to the API")
  end
end

expect_api_error.call("not associated with the workflow run") do |run, _pull|
  run["pull_requests"] = [{ "number" => PR_NUMBER + 1 }]
end

expect_api_error.call("head does not match") do |_run, pull|
  pull["head"]["sha"] = "b" * 40
end

expect_api_error.call("branch does not match") do |_run, pull|
  pull["head"]["ref"] = "different"
end

expect_api_error.call("head repository does not match") do |_run, pull|
  pull["head"]["repo"]["id"] = 999
end

expect_api_error.call("not in #{REPOSITORY}") do |_run, pull|
  pull["base"]["repo"]["full_name"] = FORK_REPOSITORY
end

expect_api_error.call("does not belong to #{REPOSITORY}") do |_run, pull|
  pull["url"] = "https://api.github.com/repos/#{FORK_REPOSITORY}/pulls/#{PR_NUMBER}"
end

expect_api_error.call("did not succeed") do |run, _pull|
  run["conclusion"] = "failure"
end

expect_api_error.call("not triggered by pull_request") do |run, _pull|
  run["event"] = "push"
end

expect_api_error.call("workflow run is not") do |run, _pull|
  run["path"] = ".github/workflows/other.yml"
end

# --- command invocation ---

Dir.mktmpdir("group-pages-comment-cli-") do |dir|
  write_artifact(dir, summary: "Hello $(rm -rf /)\n")
  bin = File.join(dir, "bin")
  FileUtils.mkdir_p(bin)
  fake_gh = File.join(bin, "gh")
  File.write(fake_gh, <<~RUBY)
    #!#{RbConfig.ruby}
    # frozen_string_literal: true
    require "json"
    File.open(ENV.fetch("GH_LOG"), "a") { |file| file.puts(JSON.generate(ARGV)) }
    endpoint = ARGV.find { |arg| arg.start_with?("repos/") }.to_s
    if endpoint.include?("/actions/runs/")
      print ENV.fetch("GH_RUN_JSON")
    elsif endpoint.include?("/pulls/")
      print ENV.fetch("GH_PULL_JSON")
    elsif ARGV.include?("--paginate")
      print "[[]]"
    elsif ARGV.include?("POST")
      parsed = JSON.parse(File.read(ARGV[ARGV.index("--input") + 1]))
      abort "body was not a string" unless parsed["body"].is_a?(String)
      File.write(ENV.fetch("GH_BODY"), parsed["body"])
      print '{"id":77}'
    else
      warn ARGV.inspect
      exit 1
    end
  RUBY
  File.chmod(0o755, fake_gh)

  log = File.join(dir, "gh.log")
  body_path = File.join(dir, "body.txt")
  artifact = File.join(dir, "artifact")
  FileUtils.mkdir_p(artifact)
  write_artifact(artifact, summary: "Hello $(rm -rf /)\n")
  stdout, stderr, status = Open3.capture3(
    base_env(artifact).merge(
      "GH_TOKEN" => "test-token",
      "GH_LOG" => log,
      "GH_BODY" => body_path,
      "GH_RUN_JSON" => JSON.generate(run_fixture),
      "GH_PULL_JSON" => JSON.generate(pull_fixture),
      "PATH" => bin
    ),
    RbConfig.ruby,
    File.join(ROOT, "script/comment_group_pages.rb")
  )
  check.call(status.success?, "cli posts through gh (#{status.exitstatus}): #{stderr}")
  check.call(stdout.include?("Created the group pages comment on pull request #{PR_NUMBER}"), "cli reports the created comment")
  check.call(File.read(body_path) == expected_body("Hello $(rm -rf /)\n"), "cli sends the summary as data")
  logged = File.readlines(log, chomp: true).map { |line| JSON.parse(line) }
  check.call(logged.all? { |args| args[0] == "api" && args.none? { |arg| arg.include?("$(rm") } },
             "cli does not pass the summary to a shell: #{logged.inspect}")

  bad = File.join(dir, "bad-artifact")
  FileUtils.mkdir_p(bad)
  File.write(File.join(bad, "group-pages-meta.json"), %({"pr_number":0}\n))
  File.write(File.join(bad, "group-pages.md"), SUMMARY)
  bad_log = File.join(dir, "bad.log")
  _stdout, bad_err, bad_status = Open3.capture3(
    base_env(bad).merge("GH_LOG" => bad_log, "PATH" => bin),
    RbConfig.ruby,
    File.join(ROOT, "script/comment_group_pages.rb")
  )
  check.call(bad_status.exitstatus == 1, "cli rejects an invalid artifact")
  check.call(bad_err.include?("positive integer"), "cli explains the invalid artifact (#{bad_err.strip})")
  check.call(!File.exist?(bad_log), "invalid artifact does not invoke gh")
end

source = File.read(File.join(ROOT, "script/comment_group_pages.rb"))
check.call(source.scan("capture3").size == 1 && source.include?('Open3.capture3("gh", *args)'),
           "gh is executed without a shell")
check.call(!source.match?(/\beval\b|\bsystem\b|\bexec\b/), "artifact contents are not evaluated")
check.call(!source.include?("`"), "the script does not use shell backticks")
check.call(!source.include?("body=@"), "the comment body is not a gh field")
check.call(source.include?(CommentGroupPages::MARKER), "the preview marker is preserved")

# --- workflow files ---

def load_workflow(filename)
  YAML.safe_load(File.read(File.join(ROOT, ".github/workflows", filename)), aliases: true)
end

def workflow_trigger(data)
  data["on"] || data[true]
end

assert_expressions = lambda do |text, label|
  index = 0
  count = 0
  while (start = text.index("${{", index))
    finish = text.index("}}", start + 3)
    check.call(!finish.nil?, "unclosed expression in #{label}")
    break unless finish

    expression = text[(start + 3)...finish]
    check.call(!expression.include?("${{"), "nested expression in #{label}")
    check.call(!expression.strip.empty?, "empty expression in #{label}")
    index = finish + 2
    count += 1
  end
  check.call(count == text.scan("${{").size, "expression scanner missed one in #{label}")
  check.call(text.scan("${{").size == text.scan("}}").size, "unbalanced expressions in #{label}")
end

validate_text = File.read(File.join(ROOT, ".github/workflows/validate-pr.yml"))
comment_text = File.read(File.join(ROOT, ".github/workflows/comment-group-pages.yml"))
validate = load_workflow("validate-pr.yml")
comment = load_workflow("comment-group-pages.yml")

check.call(workflow_trigger(validate).dig("pull_request", "branches") == ["main"], "validation stays on pull_request")
check.call(!validate_text.include?("pull_request_target"), "validation does not use pull_request_target")
check.call(!validate_text.include?("gh api"), "validation no longer posts comments")
check.call(!validate_text.include?("secrets."), "validation does not use a secret")
assert_expressions.call(validate_text, "validate-pr.yml")

club_steps = validate.dig("jobs", "validate-clubs", "steps").map { |step| step["run"] }.compact
check.call(club_steps == ["ruby script/validate_clubs.rb"], "club validation is unchanged")
build_steps = validate.dig("jobs", "build", "steps").map { |step| step["run"] }.compact
check.call(build_steps == [
  "bundle exec ruby script/generate_events.rb",
  "bundle exec ruby script/generate_special_events.rb",
  "bundle exec ruby script/generate_calendar_ics.rb",
  "ruby script/validate_events.rb",
  "ruby script/validate_special_events.rb",
  "bundle exec jekyll build",
  "ruby script/validate_clubs_json.rb"
], "build job is unchanged (#{build_steps.inspect})")

summary_job = validate.dig("jobs", "summarise-group-pages")
check.call(summary_job["permissions"] == { "contents" => "read" }, "summary job is read-only")
summary_names = summary_job["steps"].map { |step| step["name"] }
check.call(summary_names.include?("Test changed group pages script"), "group page tests still run")
check.call(summary_names.include?("Test group page comment script"), "comment logic is tested in CI")
check.call(summary_names.include?("Write job summary"), "job summary is preserved")
check.call(!summary_names.include?("Comment on pull request"), "summary job does not comment")
upload = summary_job["steps"].find { |step| step["name"] == "Upload group pages summary" }
check.call(upload["if"] == "success()", "artifact upload follows a successful summary")
check.call(upload["uses"] == "actions/upload-artifact@v7", "artifact upload uses the repository action")
check.call(upload.dig("with", "name") == "group-pages", "artifact name is group-pages")
check.call(upload.dig("with", "if-no-files-found") == "error", "missing summary fails the upload")

check.call(workflow_trigger(comment).dig("workflow_run", "workflows") == ["Validate PR"], "comment workflow follows Validate PR")
check.call(workflow_trigger(comment).dig("workflow_run", "types") == ["completed"], "comment workflow waits for completion")
check.call(comment["permissions"] == { "actions" => "read", "contents" => "read", "pull-requests" => "write" },
           "comment workflow permissions are limited")
check.call(comment.dig("concurrency", "cancel-in-progress") == false, "a later comment run is not cancelled")
comment_job = comment.dig("jobs", "comment")
check.call(comment_job["if"].include?("conclusion == 'success'"), "comments are posted only after success")
check.call(comment_job["if"].include?("event == 'pull_request'"), "comments are posted only for pull requests")
check.call(!comment_text.include?("pull_request_target"), "comment workflow does not use pull_request_target")
check.call(!comment_text.include?("github.event.pull_request"), "comment workflow does not read the untrusted pull_request event")
check.call(!comment_text.include?("secrets."), "comment workflow does not use a personal token")
check.call(!comment_text.include?("head.repo.fork"), "fork and internal pull requests share one path")
assert_expressions.call(comment_text, "comment-group-pages.yml")

steps = comment_job["steps"]
checkout = steps.find { |step| step["uses"].to_s.start_with?("actions/checkout@") }
check.call(steps.count { |step| step["uses"].to_s.include?("checkout") } == 1, "comment workflow checks out once")
check.call(checkout.dig("with", "repository") == "${{ github.repository }}", "checkout stays on the base repository")
check.call(checkout.dig("with", "ref") == "${{ github.event.repository.default_branch }}", "checkout uses the default branch")
check.call(checkout.dig("with", "persist-credentials") == false, "checkout does not keep credentials")
download = steps.find { |step| step["uses"].to_s.start_with?("actions/download-artifact@") }
check.call(download.dig("with", "name") == upload.dig("with", "name"), "download uses the uploaded artifact name")
check.call(download.dig("with", "run-id") == "${{ github.event.workflow_run.id }}", "artifact is taken from the triggering run")
check.call(download.dig("with", "github-token") == "${{ github.token }}", "artifact download uses the workflow token")
post = steps.find { |step| step["name"] == "Post or update pull request comment" }
check.call(post["run"] == "ruby script/comment_group_pages.rb", "comment step runs the trusted script")
check.call(post.dig("env", "WORKFLOW_RUN_ID") == "${{ github.event.workflow_run.id }}", "script receives the triggering run id")
check.call(post.dig("env", "GITHUB_REPOSITORY") == "${{ github.repository }}", "script receives the base repository")

if failures.positive?
  warn "\n#{failures} failure(s)."
  exit 1
end

puts "All comment_group_pages tests passed."

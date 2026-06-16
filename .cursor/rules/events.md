Never update existing events to create new ones! Always create a new recurring
or adhoc event unless we're fixing something explicitly.

After Discord or other event updates to `source/_clubs/*.md`, always finish with
a ready-to-run commit command (do not commit unless the user asks). Use:

```bash
git add <changed files only>

git commit -m "$(cat <<'EOF'
Commit message here.

EOF
)"
```

- Stage only files changed for the update (never `python/` or credential files).
- One or two sentences; British spelling; focus on why.
- Match recent style, e.g. "Add Worthing Blood on the Clocktower July dates from Discord."

#!/usr/bin/env bash
set -euo pipefail

out="${1:-mcp-secrets.env}"
tmp="${out}.tmp.$$"
trap 'rm -f "$tmp"' EXIT

umask 077
: > "$tmp"

if [ -f .env ]; then
  awk '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    function unquote(s) {
      if (length(s) >= 2) {
        first = substr(s, 1, 1)
        last = substr(s, length(s), 1)
        if ((first == "\"" && last == "\"") || (first == "'\''" && last == "'\''")) {
          return substr(s, 2, length(s) - 2)
        }
      }
      return s
    }

    /^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=/ {
      line = $0
      sub(/^[[:space:]]*export[[:space:]]+/, "", line)
      key = line
      sub(/[[:space:]]*=.*/, "", key)
      key = trim(key)

      value = line
      sub(/^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=/, "", value)
      value = trim(value)
      if (substr(value, 1, 1) == "\"") {
        if (match(value, /^"[^"]*"/)) value = substr(value, 2, RLENGTH - 2)
      } else if (substr(value, 1, 1) == "'\''") {
        if (match(value, /^'\''[^'\'']*'\''/)) value = substr(value, 2, RLENGTH - 2)
      } else {
        sub(/[[:space:]]+#.*$/, "", value)
        value = trim(value)
      }
      value = unquote(value)

      values[key] = value
    }

    END {
      github = values["GITHUB_PERSONAL_ACCESS_TOKEN"]
      if (length(github) == 0) github = values["GH_TOKEN"]
      if (length(github) > 0) print "github.personal_access_token=" github

      context7 = values["CONTEXT7_API_KEY"]
      if (length(context7) > 0) print "context7.api_key=" context7
    }
  ' .env >> "$tmp"
fi

chmod 0600 "$tmp"
mv "$tmp" "$out"
trap - EXIT

if [ -f "$out" ]; then
  printf '[mcp-secrets] generated %s from .env\n' "$out"
fi

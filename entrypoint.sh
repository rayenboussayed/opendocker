#!/usr/bin/env bash
set -euo pipefail

H=/home/opencode
CFG="$H/.config/git/config"
UID_N="$(id -u opencode)"
GID_N="$(id -g opencode)"
SSH_HOST_KEYS=(id_ed25519 id_rsa id_ecdsa identity)

log() { printf '[entrypoint] %s\n' "$*" >&2; }
gcfg() { git config --file "$CFG" "$@"; }

stage_public_ssh_files() {
  local dir="$H/.ssh" f n
  mkdir -p "$dir" && chmod 700 "$dir"
  [ -d "$H/.ssh-host" ] || return 0
  for f in "$H/.ssh-host"/* "$H/.ssh-host"/.[!.]*; do
    [ -f "$f" ] || continue
    n="$(basename "$f")"
    case "$n" in
      authorized_keys|environment) continue ;;
      *.pub|known_hosts*|allowed_signers|config) ;;
      *) continue ;;
    esac
    cp -fL "$f" "$dir/$n"
    chmod 644 "$dir/$n"
  done
  log "staged public SSH files"
}

load_env_key() {
  local key="${SSH_PRIVATE_KEY:-}" pub name=id_ed25519
  unset SSH_PRIVATE_KEY
  [ -n "$key" ] || return 0
  key="$(printf '%s\n' "$key" | tr -d '\r')"
  pub="$(printf '%s\n' "$key" | ssh-keygen -y -f /dev/stdin 2>/dev/null || true)"
  [ -n "$pub" ] || { log "WARNING: SSH_PRIVATE_KEY could not be parsed"; return 0; }
  case "$pub" in ssh-rsa*) name=id_rsa ;; ecdsa-*) name=id_ecdsa ;; esac
  printf '%s\n' "$pub" > "$H/.ssh/$name.pub"
  chmod 644 "$H/.ssh/$name.pub"
  if printf '%s\n' "$key" | ssh-add - >/dev/null 2>&1; then
    log "loaded SSH_PRIVATE_KEY into ssh-agent"
  else
    log "WARNING: SSH_PRIVATE_KEY could not be loaded into ssh-agent"
  fi
}

start_ssh_agent() {
  local sockdir="$H/.ssh/agent"
  local sock="$sockdir/agent.sock"
  local key
  mkdir -p "$sockdir" && chmod 700 "$sockdir"
  rm -f "$sock"
  if ! eval "$(ssh-agent -s -a "$sock")" >/dev/null 2>&1 || [ ! -S "$sock" ]; then
    log "WARNING: could not start ssh-agent at $sock"
    return 0
  fi
  export SSH_AUTH_SOCK="$sock"
  for key in "${SSH_HOST_KEYS[@]/#/$H/.ssh-host/}"; do
    [ -f "$key" ] && ssh-add "$key" >/dev/null 2>&1 && log "loaded $(basename "$key") into ssh-agent"
  done
  load_env_key
  rm -f "${SSH_HOST_KEYS[@]/#/$H/.ssh/}" "$H/.ssh/.key" "$H/.ssh/.agent-key"
  if ! ssh-add -l >/dev/null 2>&1; then
    log "WARNING: ssh-agent has no keys - git push/signing may fail"
  fi
}

seed_base_skill() {
  local src=/opt/opencode-base-skills/find-skills/SKILL.md
  local dir="$H/.config/opencode/skills/find-skills"
  [ -f "$src" ] || return 0
  [ -f "$dir/SKILL.md" ] && return 0
  mkdir -p "$dir"
  cp -f "$src" "$dir/SKILL.md"
  chown -R "$UID_N:$GID_N" "$dir"
  log "seeded find-skills"
}

configure_signing() {
  local k="$GIT_SIGNING_KEY" signing="" pub="" agent_keys="" p email
  [ -n "${SSH_AUTH_SOCK:-}" ] && agent_keys="$(ssh-add -L 2>/dev/null | grep -v '^The agent' || true)"
  case "$k" in
    agent) pub="$(head -n1 <<<"$agent_keys")"; [ -n "$pub" ] && signing="key::$pub" ;;
    key::*) pub="${k#key::}"; signing="$k" ;;
    ssh-*|ecdsa-*|sk-*) pub="$k"; signing="key::$k" ;;
    *)
      p="${k/#\~/$H}"
      [ "${p:0:1}" = / ] || p="$H/.ssh/$p"
      if [ "${p%.pub}" != "$p" ]; then
        pub="$(cat "$p" 2>/dev/null || true)"
        signing="$p"
        if [ -n "$pub" ] && ! grep -qF "$(awk '{print $2}' <<<"$pub")" <<<"$agent_keys" && [ -f "${p%.pub}" ]; then
          signing="${p%.pub}"
        fi
      elif [ -f "$p" ]; then
        signing="$p"
        pub="$(cat "$p.pub" 2>/dev/null || ssh-keygen -y -P '' -f "$p" 2>/dev/null || true)"
      fi ;;
  esac
  if [ -z "$signing" ] || [ -z "$pub" ]; then
    log "WARNING: GIT_SIGNING_KEY could not be resolved - commits will not be signed"
    return 0
  fi
  gcfg gpg.format ssh
  gcfg user.signingkey "$signing"
  gcfg commit.gpgsign true
  gcfg tag.gpgsign true
  email="$(git config --get user.email || echo '*')"
  printf '%s namespaces="git" %s\n' "$email" "$(awk '{print $1" "$2}' <<<"$pub")" > "$H/.config/git/allowed_signers"
  gcfg gpg.ssh.allowedSignersFile "$H/.config/git/allowed_signers"
  log "commit signing enabled ($(awk '{print $1}' <<<"$pub") key)"
}

configure_git() {
  local hostcfg="$H/.gitconfig-host" from_host=""
  mkdir -p "$(dirname "$CFG")"
  gcfg init.defaultBranch main
  gcfg safe.directory '*'
  if [ -f "$hostcfg" ]; then
    if [ -z "${GIT_USER_NAME:-}" ]; then GIT_USER_NAME="$(git config --file "$hostcfg" user.name 2>/dev/null || true)"; from_host=1; fi
    if [ -z "${GIT_USER_EMAIL:-}" ]; then GIT_USER_EMAIL="$(git config --file "$hostcfg" user.email 2>/dev/null || true)"; from_host=1; fi
    if [ -z "${GIT_SIGNING_KEY:-}" ]; then GIT_SIGNING_KEY="$(git config --file "$hostcfg" user.signingkey 2>/dev/null || true)"; from_host=1; fi
    case "${GIT_SIGNING_KEY:-}" in
      '~/'*) [ -n "${HOST_HOME:-}" ] && GIT_SIGNING_KEY="${HOST_HOME}${GIT_SIGNING_KEY#'~'}" ;;
    esac
  fi
  if [ -n "${GIT_USER_NAME:-}" ]; then gcfg user.name "$GIT_USER_NAME"; fi
  if [ -n "${GIT_USER_EMAIL:-}" ]; then gcfg user.email "$GIT_USER_EMAIL"; fi
  if [ -n "$from_host" ]; then log "git identity read from host ~/.gitconfig"; fi
  if [ -n "${GH_TOKEN:-${GITHUB_TOKEN:-}}" ]; then
    gcfg credential.https://github.com.helper '!gh auth git-credential'
  fi
  if [ -n "${GIT_SIGNING_KEY:-}" ]; then configure_signing; fi
}

refresh_skills_snapshot() {
  local repo="$H/.agents" msg
  env -u GH_TOKEN -u GITHUB_TOKEN -u OPENCODE_API_KEY -u OPENCODE_PASSWORD \
    -u POSTHOG_PERSONAL_API_KEY npx -y skills update -g -y \
    || { log "WARNING: skills update failed - keeping the previous snapshot"; return 0; }
  mkdir -p "$repo" || { log "WARNING: cannot create $repo"; return 0; }
  [ -d "$repo/.git" ] || git -C "$repo" init -q || { log "WARNING: could not init skills git repo"; return 0; }
  git -C "$repo" add -A || { log "WARNING: could not stage skills changes"; return 0; }
  git -C "$repo" diff --cached --quiet && return 0
  msg="skills: auto-update $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if git -C "$repo" commit -q -m "$msg"; then
    log "committed skills snapshot: $msg"
  else
    log "WARNING: skills snapshot commit failed"
  fi
}

if [ "$(id -u)" = 0 ]; then
  for d in .agents .config .config/opencode .local .local/share .local/share/opencode .local/state .cache workspace; do
    [ -d "$H/$d" ] || continue
    [ "$(stat -c %u "$H/$d")" = "$UID_N" ] || chown -R "$UID_N:$GID_N" "$H/$d"
  done
  stage_public_ssh_files
  chown -R "$UID_N:$GID_N" "$H/.ssh"
  seed_base_skill
  case "${HOST_HOME:-}" in
    ""|/|"$H") ;;
    /*)
      if mkdir -p "$HOST_HOME" && ln -sfn "$H/.ssh" "$HOST_HOME/.ssh"; then
        log "linked $HOST_HOME/.ssh -> $H/.ssh"
      else
        log "WARNING: could not link $HOST_HOME/.ssh - host signingKey paths will not resolve"
      fi ;;
    *) log "WARNING: HOST_HOME=$HOST_HOME is not an absolute path - ignoring" ;;
  esac
  export HOME="$H" USER=opencode LOGNAME=opencode SHELL=/bin/bash
  exec setpriv --reuid="$UID_N" --regid="$GID_N" --init-groups "$0" "$@"
fi

export HOME="$H"
start_ssh_agent
configure_git
( refresh_skills_snapshot ) > "$H/.local/share/opencode/skills-update.log" 2>&1 &
log "skills refresh started in background (~/.local/share/opencode/skills-update.log)"
exec "$@"

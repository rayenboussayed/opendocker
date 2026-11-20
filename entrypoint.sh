#!/usr/bin/env bash
set -Eeuo pipefail

H=/home/opencode
log() { printf '[entrypoint] %s\n' "$*" >&2; }

stage_public_ssh_files() {
  local dir="$H/.ssh" f n
  mkdir -p "$dir" && chmod 700 "$dir"
  if [ -d "$H/.ssh-host" ]; then
    for f in "$H/.ssh-host"/* "$H/.ssh-host"/.[!.]*; do
      [ -f "$f" ] || continue
      n="$(basename "$f")"
      # Private keys stay on the host and are loaded straight into ssh-agent below.
      case "$n" in
        authorized_keys|environment) continue ;;
        *.pub|known_hosts*|allowed_signers|config) ;;
        *) continue ;;
      esac
      cp -fL "$f" "$dir/$n"
      chmod 644 "$dir/$n"
    done
    log "staged public SSH files from ~/.ssh-host"
  fi
  if [ -n "${SSH_PRIVATE_KEY:-}" ]; then
    local tmp="$dir/.agent-key" pub name=id_ed25519
    printf '%s\n' "$SSH_PRIVATE_KEY" | tr -d '\r' > "$tmp"; chmod 600 "$tmp"
    if pub="$(ssh-keygen -y -P '' -f "$tmp" 2>/dev/null)"; then
      case "$pub" in ssh-rsa*) name=id_rsa ;; ecdsa-*) name=id_ecdsa ;; esac
      printf '%s\n' "$pub" > "$dir/$name.pub"
      chmod 644 "$dir/$name.pub"
    fi
    chown 1000:1000 "$tmp"
    log "staged SSH_PRIVATE_KEY for ssh-agent"
  fi
}

start_ssh_agent() {
  local sockdir="$H/.ssh/agent"
  local sock="$sockdir/agent.sock"
  local key
  mkdir -p "$sockdir" && chmod 700 "$sockdir"
  rm -f "$sock"
  eval "$(ssh-agent -s -a "$sock")" >/dev/null 2>&1
  export SSH_AUTH_SOCK="$sock"

  # Read private keys directly from the read-only host mount; no private key is
  # ever written into the container's writable filesystem.
  for key in "$H/.ssh-host"/id_ed25519 "$H/.ssh-host"/id_rsa "$H/.ssh-host"/id_ecdsa "$H/.ssh-host"/identity; do
    [ -f "$key" ] || continue
    if ssh-add "$key" >/dev/null 2>&1; then
      log "loaded $(basename "$key") into ssh-agent"
    fi
  done
  if [ -f "$H/.ssh/.agent-key" ]; then
    if ssh-add "$H/.ssh/.agent-key" >/dev/null 2>&1; then
      log "loaded SSH_PRIVATE_KEY into ssh-agent"
    fi
    rm -f "$H/.ssh/.agent-key"
  fi
  # Remove any private-key remnants from older setups in the writable key dir.
  for key in "$H/.ssh"/id_ed25519 "$H/.ssh"/id_rsa "$H/.ssh"/id_ecdsa "$H/.ssh"/identity "$H/.ssh"/.key; do
    if [ -f "$key" ]; then rm -f "$key"; fi
  done
  if ! ssh-add -l >/dev/null 2>&1; then
    log "WARNING: ssh-agent has no keys - git push/signing may fail"
  fi
}

seed_base_skill() {
  local src=/opt/opencode-base-skills/find-skills/SKILL.md
  local dir="$H/.config/opencode/skills/find-skills"
  [ -f "$src" ] || return 0
  if [ ! -f "$dir/SKILL.md" ]; then
    mkdir -p "$dir"
    cp -f "$src" "$dir/SKILL.md"
    chown -R 1000:1000 "$dir"
    log "seeded find-skills into ~/.config/opencode/skills"
  fi
}

if [ "$(id -u)" = 0 ]; then
  for d in .agents .config .config/opencode .local .local/share .local/share/opencode .local/state .cache workspace; do
    if [ -d "$H/$d" ] && [ "$(stat -c %u "$H/$d")" = 0 ]; then chown -R 1000:1000 "$H/$d"; log "fixed ownership of ~/$d"; fi
  done
  stage_public_ssh_files
  chown -R 1000:1000 "$H/.ssh"
  seed_base_skill
  # Expose the staged public keys at the host's real path, so git (and the host's
  # ~/.gitconfig signingkey, absolute or ~) finds them where the host config expects.
  case "${HOST_HOME:-}" in
    ""|/) ;;
    /*) if mkdir -p "$HOST_HOME" && ln -sfn "$H/.ssh" "$HOST_HOME/.ssh"; then
          log "linked $HOST_HOME/.ssh -> $H/.ssh"
        else
          log "WARNING: could not link $HOST_HOME/.ssh - host signingKey paths will not resolve"
        fi ;;
    *) log "WARNING: HOST_HOME=$HOST_HOME is not an absolute path - ignoring" ;;
  esac
  export HOME="$H" USER=opencode LOGNAME=opencode SHELL=/bin/bash
  exec setpriv --reuid=1000 --regid=1000 --init-groups "$0" "$@"
fi

export HOME="$H"
[ "${USER:-}" = opencode ] || stage_public_ssh_files
start_ssh_agent

cfg="$H/.config/git/config"
mkdir -p "$(dirname "$cfg")"
printf '[init]\n\tdefaultBranch = main\n[safe]\n\tdirectory = *\n' > "$cfg"

# Fall back to the host's ~/.gitconfig (mounted read-only at .gitconfig-host) for the
# identity and signing key when .env doesn't provide them. Explicit env values win.
hostcfg="$H/.gitconfig-host"
from_host=""
if [ -f "$hostcfg" ]; then
  if [ -z "${GIT_USER_NAME:-}" ];  then GIT_USER_NAME="$(git config --file "$hostcfg" user.name      2>/dev/null || true)";  from_host=1; fi
  if [ -z "${GIT_USER_EMAIL:-}" ]; then GIT_USER_EMAIL="$(git config --file "$hostcfg" user.email    2>/dev/null || true)"; from_host=1; fi
  if [ -z "${GIT_SIGNING_KEY:-}" ]; then GIT_SIGNING_KEY="$(git config --file "$hostcfg" user.signingkey 2>/dev/null || true)"; from_host=1; fi
  # Host ~/.gitconfig may use ~ for the signing key; the entrypoint links $HOST_HOME/.ssh to $H/.ssh,
  # so both absolute host paths and this expansion resolve to the container's copy verbatim.
  case "${GIT_SIGNING_KEY:-}" in
    '~/'*) if [ -n "${HOST_HOME:-}" ]; then GIT_SIGNING_KEY="${HOST_HOME}${GIT_SIGNING_KEY#'~'}"; fi ;;
  esac
fi
[ -n "${GIT_USER_NAME:-}" ]  && git config --file "$cfg" user.name "$GIT_USER_NAME"
[ -n "${GIT_USER_EMAIL:-}" ] && git config --file "$cfg" user.email "$GIT_USER_EMAIL"
[ -n "$from_host" ] && log "git identity read from host ~/.gitconfig"
if [ -n "${GH_TOKEN:-${GITHUB_TOKEN:-}}" ]; then
  git config --file "$cfg" credential.https://github.com.helper '!gh auth git-credential'
fi

if [ -n "${GIT_SIGNING_KEY:-}" ]; then
  k="$GIT_SIGNING_KEY" signing="" pub="" agent_keys=""
  [ -n "${SSH_AUTH_SOCK:-}" ] && agent_keys="$(ssh-add -L 2>/dev/null | grep -v '^The agent' || true)"
  case "$k" in
    agent)              pub="$(head -n1 <<<"$agent_keys")"; [ -n "$pub" ] && signing="key::$pub" ;;
    key::*)             pub="${k#key::}"; signing="$k" ;;
    ssh-*|ecdsa-*|sk-*) pub="$k"; signing="key::$k" ;;
    *)
      p="${k/#\~/$H}"; [ "${p:0:1}" = / ] || p="$H/.ssh/$p"
      if [ "${p%.pub}" != "$p" ]; then
        pub="$(cat "$p" 2>/dev/null || true)"; signing="$p"
        if ! grep -qF "$(awk '{print $2}' <<<"$pub")" <<<"$agent_keys" && [ -f "${p%.pub}" ]; then signing="${p%.pub}"; fi
      elif [ -f "$p" ]; then
        signing="$p"; pub="$(cat "$p.pub" 2>/dev/null || ssh-keygen -y -P '' -f "$p" 2>/dev/null || true)"
      fi ;;
  esac
  if [ -n "$signing" ] && [ -n "$pub" ]; then
    git config --file "$cfg" gpg.format ssh
    git config --file "$cfg" user.signingkey "$signing"
    git config --file "$cfg" commit.gpgsign true
    git config --file "$cfg" tag.gpgsign true
    email="$(git config --get user.email || echo '*')"
    printf '%s namespaces="git" %s\n' "$email" "$(awk '{print $1" "$2}' <<<"$pub")" > "$H/.config/git/allowed_signers"
    git config --file "$cfg" gpg.ssh.allowedSignersFile "$H/.config/git/allowed_signers"
    log "commit signing enabled ($(awk '{print $1}' <<<"$pub") key)"
  else
    log "WARNING: GIT_SIGNING_KEY=$GIT_SIGNING_KEY could not be resolved - commits will not be signed"
  fi
fi

# Keep a local, signed snapshot of every skills update. Never blocks startup.
refresh_skills_snapshot() {
  local repo="$H/.agents" msg

  if ! npx -y skills update -g -y; then
    log "WARNING: skills update failed - keeping the previous snapshot"
    return 0
  fi

  mkdir -p "$repo" || { log "WARNING: cannot create $repo"; return 0; }
  if [ ! -d "$repo/.git" ]; then
    git -C "$repo" init -q || { log "WARNING: could not init skills git repo"; return 0; }
  fi

  git -C "$repo" add -A || { log "WARNING: could not stage skills changes"; return 0; }
  if git -C "$repo" diff --cached --quiet; then
    return 0
  fi

  msg="skills: auto-update $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if git -C "$repo" commit -q -m "$msg"; then
    log "committed skills snapshot: $msg"
  else
    log "WARNING: skills snapshot commit failed"
  fi
}

# The updater clones many repositories, which can take minutes. Run it in the background so
# the server starts immediately; its output and snapshot commit go to a log file.
( refresh_skills_snapshot ) > "$H/.local/share/opencode/skills-update.log" 2>&1 &
log "skills refresh started in background (~/.local/share/opencode/skills-update.log)"

exec "$@"

#!/usr/bin/env bash
set -Eeuo pipefail

H=/home/opencode
log() { printf '[entrypoint] %s\n' "$*" >&2; }

install_ssh_keys() {
  local dir="$H/.ssh" f n
  mkdir -p "$dir" && chmod 700 "$dir"
  if [ -d "$H/.ssh-host" ]; then
    for f in "$H/.ssh-host"/* "$H/.ssh-host"/.[!.]*; do
      [ -f "$f" ] || continue
      n="$(basename "$f")"
      case "$n" in authorized_keys|environment) continue ;; esac
      cp -fL "$f" "$dir/$n"
      case "$n" in *.pub|known_hosts*|allowed_signers) chmod 644 "$dir/$n" ;; *) chmod 600 "$dir/$n" ;; esac
    done
    log "installed SSH files from ~/.ssh-host"
  fi
  if [ -n "${SSH_PRIVATE_KEY:-}" ]; then
    local tmp="$dir/.key" pub name=id_ed25519
    printf '%s\n' "$SSH_PRIVATE_KEY" | tr -d '\r' > "$tmp"; chmod 600 "$tmp"
    if pub="$(ssh-keygen -y -P '' -f "$tmp" 2>/dev/null)"; then
      case "$pub" in ssh-rsa*) name=id_rsa ;; ecdsa-*) name=id_ecdsa ;; esac
      printf '%s\n' "$pub" > "$dir/$name.pub"
    fi
    mv -f "$tmp" "$dir/$name"
    log "installed SSH_PRIVATE_KEY as ~/.ssh/$name"
  fi
}

if [ "$(id -u)" = 0 ]; then
  for d in .config .config/opencode .local .local/share .local/share/opencode .local/state .cache workspace; do
    if [ -d "$H/$d" ] && [ "$(stat -c %u "$H/$d")" = 0 ]; then chown -R 1000:1000 "$H/$d"; log "fixed ownership of ~/$d"; fi
  done
  install_ssh_keys
  chown -R 1000:1000 "$H/.ssh"
  # Expose the copied keys at the host's real path, so git (and the host's ~/.gitconfig
  # signingkey, absolute or ~) finds them exactly where the host config expects.
  case "${HOST_HOME:-}" in
    ""|/) ;;
    /*) if mkdir -p "$HOST_HOME" && ln -sfn "$H/.ssh" "$HOST_HOME/.ssh"; then
          log "linked $HOST_HOME/.ssh -> $H/.ssh"
        else
          log "WARNING: could not link $HOST_HOME/.ssh - host signingKey paths will not resolve"
        fi ;;
    *) log "WARNING: HOST_HOME=$HOST_HOME is not an absolute path - ignoring" ;;
  esac
  if [ -n "${SSH_AUTH_SOCK:-}" ]; then
    if [ ! -S "$SSH_AUTH_SOCK" ]; then
      log "SSH_AUTH_SOCK=$SSH_AUTH_SOCK is not a socket - ignoring"; unset SSH_AUTH_SOCK
    elif ! setpriv --reuid=1000 --regid=1000 --init-groups test -w "$SSH_AUTH_SOCK"; then
      install -d -o 1000 -g 1000 -m 0700 /tmp/ssh-agent
      socat "UNIX-LISTEN:/tmp/ssh-agent/agent.sock,fork,unlink-early,user=1000,group=1000,mode=600" \
            "UNIX-CONNECT:$SSH_AUTH_SOCK" &
      for _ in $(seq 50); do [ -S /tmp/ssh-agent/agent.sock ] && break; sleep 0.1; done
      export SSH_AUTH_SOCK=/tmp/ssh-agent/agent.sock
      log "relaying ssh-agent socket for the opencode user"
    fi
  fi
  export HOME="$H" USER=opencode LOGNAME=opencode SHELL=/bin/bash
  exec setpriv --reuid=1000 --regid=1000 --init-groups "$0" "$@"
fi

export HOME="$H"
[ "${USER:-}" = opencode ] || install_ssh_keys

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

exec "$@"

ARG NODE_TAG=slim
FROM platformatic/node-caged:${NODE_TAG}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG DEBIAN_FRONTEND=noninteractive

ARG PACKAGES="bash-completion less nano vim-tiny jq yq ripgrep fd-find tree file zip unzip bzip2 \
  procps htop lsof iputils-ping bind9-dnsutils netcat-openbsd sqlite3 make gh"
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl git git-lfs openssh-client sudo socat tini \
      python3 python3-pip python3-venv python-is-python3 ${PACKAGES} \
 && rm -rf /var/lib/apt/lists/* \
 && git lfs install --system --skip-repo \
 && ln -s /usr/bin/fdfind /usr/local/bin/fd

ARG OPENCODE_VERSION=latest
ARG NPM_PACKAGES=
ARG PIP_PACKAGES=
RUN npm install -g "@opencode/cli@${OPENCODE_VERSION}" ${NPM_PACKAGES} \
 && rm -rf "$(npm root -g)/@opencode/cli/node_modules" \
 && if [ -n "${PIP_PACKAGES}" ]; then pip install --break-system-packages --no-cache-dir ${PIP_PACKAGES}; fi \
 && npm cache clean --force

COPY --chmod=0644 ssh_known_hosts /etc/ssh/ssh_known_hosts
COPY --chmod=0644 ssh_config /etc/ssh/ssh_config.d/50-opencode.conf
COPY --chmod=0644 AGENTS.md opencode.json /etc/opencode/
COPY --chmod=0755 entrypoint.sh /usr/local/bin/opencode-entrypoint.sh
RUN chmod 0755 /etc/opencode \
 && useradd -m -u 1000 -U -s /bin/bash opencode \
 && mkdir -p /home/opencode/{.ssh,.config/opencode,.local/share/opencode,.local/bin,.cache,workspace} \
 && chmod 700 /home/opencode/.ssh && chown -R opencode:opencode /home/opencode \
 && echo 'opencode ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/opencode && chmod 0440 /etc/sudoers.d/opencode

ENV LANG=C.UTF-8 \
    OPENCODE_DISABLE_AUTOUPDATE=1 \
    NPM_CONFIG_PREFIX=/home/opencode/.local \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    PATH=/home/opencode/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

WORKDIR /home/opencode/workspace
EXPOSE 4000
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s \
  CMD curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:4000/api/info | grep -qE "^(200|401)$"
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/usr/local/bin/opencode-entrypoint.sh"]
CMD ["opencode", "serve", "--hostname", "0.0.0.0", "--port", "4000"]

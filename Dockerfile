ARG NODE_TAG=slim
ARG DOCKER_CLI_TAG=29-cli
FROM docker:${DOCKER_CLI_TAG} AS docker-cli

FROM platformatic/node-caged:${NODE_TAG}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG DEBIAN_FRONTEND=noninteractive
ARG PACKAGES="bash-completion less nano vim-tiny jq yq ripgrep fd-find tree file zip unzip bzip2 ffmpeg \
  procps htop lsof iputils-ping bind9-dnsutils netcat-openbsd sqlite3 make gh"
ARG NPM_PACKAGES= PIP_PACKAGES=
ARG SKILLS_REF=main

RUN apt-get update && apt-get install -y --no-install-recommends \
      curl git git-lfs openssh-client socat tini util-linux \
      python3 python3-pip python3-venv python-is-python3 ${PACKAGES} \
  && rm -rf /var/lib/apt/lists/* \
  && git lfs install --system --skip-repo \
  && ln -s /usr/bin/fdfind /usr/local/bin/fd

RUN npm i -g npm@latest \
  && npm install -g --dangerously-allow-all-scripts "@opencode/cli@latest" ${NPM_PACKAGES} \
  && rm -rf "$(npm root -g)/@opencode/cli/node_modules" \
  && python3 -m pip install --break-system-packages --no-cache-dir --upgrade --ignore-installed pip \
  && if [ -n "${PIP_PACKAGES}" ]; then pip install --break-system-packages --no-cache-dir ${PIP_PACKAGES}; fi \
  && npm cache clean --force

RUN mkdir -p /opt/opencode-base-skills/find-skills \
  && curl -fsSL --retry 3 \
       "https://raw.githubusercontent.com/vercel-labs/skills/${SKILLS_REF}/skills/find-skills/SKILL.md" \
       -o /opt/opencode-base-skills/find-skills/SKILL.md \
  && chmod -R a+rX /opt/opencode-base-skills \
  && useradd -m -u 1000 -U -s /bin/bash opencode \
  && mkdir -p /home/opencode/{.ssh,.config/opencode/skills,.local/share/opencode,.local/bin,.cache,workspace} \
  && chmod 700 /home/opencode/.ssh \
  && mkdir -p /etc/opencode && chmod 755 /etc/opencode \
  && chown -R opencode:opencode /home/opencode \
  && mkdir -p /tmp/opencode && chown opencode:opencode /tmp/opencode

COPY --chmod=0644 ssh_known_hosts /etc/ssh/ssh_known_hosts
COPY --chmod=0644 ssh_config /etc/ssh/ssh_config.d/50-opencode.conf
COPY --chmod=0644 AGENTS.md opencode.json /etc/opencode/
COPY --chmod=0755 entrypoint.sh /usr/local/bin/opencode-entrypoint.sh
COPY --from=docker-cli --chmod=0755 /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker-cli --chmod=0755 /usr/local/libexec/docker/cli-plugins/ /usr/local/libexec/docker/cli-plugins/

ENV LANG=C.UTF-8 \
    OPENCODE_DISABLE_AUTOUPDATE=1 \
    NPM_CONFIG_PREFIX=/home/opencode/.local \
    NPM_CONFIG_DANGEROUSLY_ALLOW_ALL_SCRIPTS=true \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    PATH=/home/opencode/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

WORKDIR /home/opencode/workspace
EXPOSE 4000
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s \
  CMD curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:4000/api/info | grep -qE "^(200|401)$"
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/usr/local/bin/opencode-entrypoint.sh"]
CMD ["opencode", "serve", "--hostname", "0.0.0.0", "--port", "4000"]

# syntax=docker/dockerfile:1
#
# scc — sandboxed Claude Code
#
# Design:
#   * Claude Code installed via Anthropic's official native installer, as a
#     non-root user. It auto-updates in the background into the persisted
#     home volume; `scc update` forces the newest release immediately.
#   * The entrypoint remaps the container user to your host UID/GID at start
#     (inside the container only — host namespaces are never touched).
#   * No sudo in the image. The optional egress firewall runs from the
#     entrypoint before privileges are dropped.
#
# Need more tools (compilers, python, etc.)? Add them to the apt-get line
# below and run `scc rebuild`.

FROM node:22-bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# The printf line makes apt resilient to flaky CDNs, proxies, and VM NAT:
# retry failed fetches, and disable HTTP pipelining (the usual cause of
# "Ign ... Error reading from server. Remote end closed connection").
RUN printf 'Acquire::Retries "5";\nAcquire::http::Pipeline-Depth "0";\nAcquire::http::No-Cache "true";\n' \
        > /etc/apt/apt.conf.d/80-scc-robust \
    && apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl git openssh-client \
        jq less nano procps ripgrep unzip \
        gosu iptables ipset dnsutils \
    && rm -rf /var/lib/apt/lists/* \
    && gosu nobody true

# Runtime identity: reuse the image's 'node' user (uid/gid 1000). The
# entrypoint remaps it to the actual host UID/GID on every start.
ENV HOME=/home/node \
    CLAUDE_CONFIG_DIR=/home/node/.claude \
    PATH=/home/node/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    IS_SANDBOX=1

# Install Claude Code with the official native installer, as non-root.
# WORKDIR must be a small directory: running the installer from / makes it
# scan the whole filesystem and get OOM-killed inside containers.
USER node
WORKDIR /tmp
RUN curl -fsSL https://claude.ai/install.sh | bash \
    && claude --version

# Seed onboarding state so a fresh home volume skips first-run setup.
RUN printf '{"hasCompletedOnboarding": true}\n' > /home/node/.claude.json \
    && mkdir -p /home/node/.claude

USER root
COPY --chmod=755 entrypoint.sh init-firewall.sh /usr/local/bin/

WORKDIR /home/node
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["claude"]

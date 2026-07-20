# syntax=docker/dockerfile:1
#
# scc — sandboxed Claude Code
# Source-available under PolyForm Noncommercial 1.0.0; see LICENSE.
#
# NOTICE: scc is an INDEPENDENT, UNOFFICIAL project. It is NOT affiliated with,
# endorsed by, or bundled with Anthropic or Claude Code. This image does not
# contain Claude Code; it downloads Anthropic's official CLI at build time from
# Anthropic's own installer and runs it unmodified. "Claude"/"Claude Code" are
# Anthropic's. Use of Claude Code is governed by Anthropic's terms.
#
# Add tools (compilers, python, ...) to the apt line below, then `scc rebuild`.

# Debian slim, not node:22 — Claude Code's installer fetches a self-contained
# native binary, so no Node.js runtime is needed (that's the size win).
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# apt config: retry fetches and disable HTTP pipelining — robust against flaky
# CDNs/proxies/VM NAT ("Ign ... Remote end closed connection").
# libstdc++6/libgcc-s1: the native binary links them; explicit so the slim base
# is guaranteed to carry them. bind9-dnsutils provides dig (dnsutils is transitional).
RUN printf 'Acquire::Retries "5";\nAcquire::http::Pipeline-Depth "0";\nAcquire::http::No-Cache "true";\n' \
        > /etc/apt/apt.conf.d/80-scc-robust \
    && apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl git openssh-client \
        jq less nano procps ripgrep unzip \
        gosu iptables ipset bind9-dnsutils \
        libstdc++6 libgcc-s1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && gosu nobody true

# This base has no 'node' user (the old node:22 base provided one), so create
# it at uid/gid 1000. The entrypoint remaps it to the host UID/GID on start.
RUN groupadd --gid 1000 node \
    && useradd --uid 1000 --gid 1000 --create-home --shell /bin/bash node

# Runtime identity + Claude Code config location.
ENV HOME=/home/node \
    CLAUDE_CONFIG_DIR=/home/node/.claude \
    PATH=/home/node/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    IS_SANDBOX=1

# Install Claude Code (non-root), seed onboarding so a fresh volume skips
# first-run setup, and clean scratch in-layer. WORKDIR must be small — from /
# the installer scans the whole FS and gets OOM-killed in containers.
USER node
WORKDIR /tmp
RUN curl -fsSL https://claude.ai/install.sh | bash \
    && claude --version \
    && printf '{"hasCompletedOnboarding": true}\n' > /home/node/.claude.json \
    && mkdir -p /home/node/.claude \
    && rm -rf /home/node/.cache /home/node/.npm \
    && { find /tmp -mindepth 1 -delete 2>/dev/null || true; }

USER root
COPY --chmod=755 entrypoint.sh init-firewall.sh /usr/local/bin/

WORKDIR /home/node
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["claude"]

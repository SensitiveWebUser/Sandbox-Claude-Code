# syntax=docker/dockerfile:1
# scc: source-available under PolyForm Noncommercial 1.0.0; see LICENSE.
# Toolchain layer: adds language runtimes atop the scc base image, into system
# paths (not the home dir) so they survive the runtime home volume. Built on
# demand by `scc --with ...`; the launcher supplies BASE and TOOLCHAINS.
ARG BASE=scc:latest
FROM ${BASE}

ARG TOOLCHAINS=""
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:/usr/local/go/bin:/home/node/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

USER root
COPY install.sh /usr/local/lib/scc-toolchains-install.sh
RUN sh /usr/local/lib/scc-toolchains-install.sh ${TOOLCHAINS} \
    && rm -f /usr/local/lib/scc-toolchains-install.sh
USER node

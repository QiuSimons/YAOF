FROM ghcr.io/openwrt/buildbot/buildworker-v3.8.0:latest

ARG USER=buildbot
ARG WORKDIR=/builder/
ARG CMD="/bin/bash"

USER $USER
WORKDIR $WORKDIR

COPY --chown=$USER:$USER ./imagebuilder/ ./

ENTRYPOINT [ ]

# required to have CMD as ENV to be executed
ENV CMD_ENV=${CMD}
FROM ubuntu:latest

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      davfs2 \
      ca-certificates \
      locales \
      inotify-tools \
      tini && \
    mkdir -p /mnt/source && \
    mkdir -p /mnt/webdrive && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:de
ENV LC_ALL=en_US.UTF-8
RUN locale-gen "$LC_ALL" && \
    update-locale LANG="$LANG"

COPY *.sh /

ENTRYPOINT [ "tini", "-g", "--", "/start.sh" ]

HEALTHCHECK --timeout=10s --start-period=10s CMD ["bash", "/healthcheck.sh"]

# docker build --file ./Dockerfile --tag paperless-nextcloud-sync .

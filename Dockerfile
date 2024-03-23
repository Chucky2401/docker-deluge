FROM alpine:3.19

LABEL fr.blackwizard.author="Chucky2401" \
    fr.blackwizard.description="OpenVPN/Deluged container" \
    fr.blackwizard.version="0.1.0" \
    fr.blackwizard.source="https://github.com/Chucky2401/docker-deluge" \
    fr.blackwizard.support="https://github.com/Chucky2401/docker-deluge/issues" \
    fr.blackwizard.url="https://blackwizard.fr"

RUN \
    echo "*** Create directories ***" ; \
    mkdir /deluge-conf ; \
    mkdir /downloads ; \
    mkdir /.openvpn

RUN \
    echo "*** Update apk ***" ; \
    apk --no-cache upgrade -U ; \
    echo "*** Enable Shell color ***" ; \
    mv /etc/profile.d/color_prompt.sh.disabled /etc/profile.d/color_prompt.sh ; \
    echo "*** Install procps ***" ; \
    apk --no-cache add procps openrc ; \
    echo "*** Enable Static Route" ; \
    rc-update add staticroute ; \
    echo "*** Install Python3 ***" ; \
    apk --no-cache add python3 py3-pip ; \
    echo "*** Install OpenVPN ***" ; \
    apk --no-cache add openvpn ; \
    echo "*** Install Deluged ***" ; \
    apk --no-cache add deluge ; \
    echo "*** Create deluge group ***" ; \
    addgroup deluge ; \
    echo "*** Create deluge user ***" ; \
    adduser --system --home /var/lib/deluge --ingroup deluge deluge ; \
    echo "*** Clean ***" ; \
    apk cache clean ; \
    rm -rf /tmp/*

ARG S6_OVERLAY_VERSION="3.1.6.2"
ARG S6_OVERLAY_ARCH="aarch64"

# add s6 overlay
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz

# add s6 optional symlinks
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-noarch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-symlinks-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-arch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-symlinks-arch.tar.xz

COPY src/ /

ENV ENV="/etc/profile"
ENV VERSION="0.1.0"
ENV PUID=1000 PGID=1000

EXPOSE 8112 6881 6881/udp 58846 10000
VOLUME /deluge-conf /downloads /.openvpn

HEALTHCHECK --interval=1m --timeout=10s \
  CMD nc -z localhost 22067 || exit 1

ENTRYPOINT ["/init"]

FROM forgejo.intranet.blackwizard.fr/docker/alpine:latest

ARG CREATED
ARG DIGEST
ARG REVISION
ARG VERSION

LABEL org.opencontainers.image.authors="Chucky2401"
LABEL org.opencontainers.image.base.digest=$DIGEST
LABEL org.opencontainers.image.base.name="alpine:latest"
LABEL org.opencontainers.image.created=$CREATED
LABEL org.opencontainers.image.description="OpenVPN and Deluge"
LABEL org.opencontainers.image.documentation="https://github.com/Chucky2401/docker-deluge"
LABEL org.opencontainers.image.url="https://github.com/Chucky2401/docker-deluge"
LABEL org.opencontainers.image.revision=$REVISION
LABEL org.opencontainers.image.source="https://github.com/Chucky2401/docker-deluge"
LABEL org.opencontainers.image.version=$VERSION


ENV PUID=1000
ENV PGID=1000

RUN \
    echo "*** Install procps ***" ; \
    apk add --no-cache procps \
      openrc \
      shadow \
      tzdata \
      iptables \
      ip6tables ; \
    echo "*** Enable Static Route" ; \
    rc-update add staticroute ; \
    echo "*** Install Python3 ***" ; \
    apk add --no-cache python3 \
      py3-netifaces \
      py3-requests ; \
    echo "*** Install OpenVPN ***" ; \
    apk add --no-cache openvpn wireguard-tools \
      geoip ; \
    echo "*** Install Deluged ***" ; \
    apk add --no-cache deluge ; \
    echo "*** Create deluge group ***" ; \
    addgroup -g ${PGID} deluge ; \
    echo "*** Create deluge user ***" ; \
    adduser --system --home /var/lib/deluge -u ${PUID} --ingroup deluge deluge ; \
    echo "*** Workaround for WireGuard ***" ; \
    echo "wireguard" >> /etc/modules ; \
    sed -i 's|\[\[ $proto == -4 \]\] && cmd sysctl -q net\.ipv4\.conf\.all\.src_valid_mark=1|[[ $proto == -4 ]] \&\& [[ $(sysctl -n net.ipv4.conf.all.src_valid_mark) != 1 ]] \&\& cmd sysctl -q net.ipv4.conf.all.src_valid_mark=1|' /usr/bin/wg-quick ; \
    echo "*** Create directories ***" ; \
    mkdir /deluge-conf ; \
    mkdir /downloads ; \
    mkdir /.openvpn ; \
    mkdir /.wg ; \
    mkdir /entrypoint ; \
    mkdir /template ; \
    chown -R deluge:deluge /deluge-conf /downloads /.openvpn /.wg /entrypoint /template

COPY --chmod=755 src/ /

EXPOSE 8112 58846
VOLUME /deluge-conf /downloads /.wg

WORKDIR /entrypoint
ENTRYPOINT ["sh", "start.sh"]

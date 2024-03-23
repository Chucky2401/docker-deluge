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
    mkdir /.openvpn ; \
    mkdir /entrypoint

#ADD src/* /root/
COPY --chmod=644 src/alias.sh /etc/profile.d/alias.sh
COPY --chmod=755 src/docker-entrypoint.py /entrypoint/

RUN \
    echo "*** Enable Shell color ***" ; \
    mv /etc/profile.d/color_prompt.sh.disabled /etc/profile.d/color_prompt.sh ; \
    echo "*** Update APK ***" ; \
    apk update ; apk upgrade ; \
    echo "*** Install procps ***" ; \
    apk add procps openrc ; \
    echo "*** Enable Static Route" ; \
    rc-update add staticroute ; \
    echo "*** Install Python3 ***" ; \
    apk add python3 py3-pip ; \
    echo "*** Install OpenVPN ***" ; \
    apk add openvpn ; \
    echo "*** Install Deluged ***" ; \
    apk add deluge ; \
    echo "*** Create deluge group ***" ; \
    addgroup deluge ; \
    echo "*** Create deluge user ***" ; \
    adduser --system --home /var/lib/deluge --ingroup deluge deluge ; \
    echo "*** Clean ***" ; \
    apk cache clean

EXPOSE 8112 6881 6881/udp 58846 10000
VOLUME /deluge-conf /downloads /.openvpn

WORKDIR /entrypoint
CMD ["python3", "docker-entrypoint.py"]

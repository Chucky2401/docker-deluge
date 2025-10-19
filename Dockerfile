FROM alpine:latest

LABEL Author="Chucky2401"
LABEL Description="OpenVPN/Deluged container"
LABEL Version="0.0.13"

RUN \
    echo "*** Create directories ***" ; \
    mkdir /deluge-conf ; \
    mkdir /downloads ; \
    mkdir /.openvpn ; \
    mkdir /entrypoint

# ADD src/* /root/
# COPY --chmod=644 src/alias.sh /etc/profile.d/alias.sh
COPY --chmod=755 src/docker-entrypoint.py /entrypoint/
COPY --chmod=755 src/deluge/core.conf /entrypoint/

RUN \
    # echo "*** Enable Shell color ***" ; \
    # mv /etc/profile.d/color_prompt.sh.disabled /etc/profile.d/color_prompt.sh ; \
    # echo "*** Update APK ***" ; \
    # apk update ; apk upgrade ; \
    echo "*** Install procps ***" ; \
    apk add --no-cache procps openrc ; \
    echo "*** Enable Static Route" ; \
    rc-update add staticroute ; \
    echo "*** Install Python3 ***" ; \
    apk add --no-cache python3 py3-netifaces ; \
    echo "*** Install OpenVPN ***" ; \
    apk add --no-cache openvpn ; \
    echo "*** Install Deluged ***" ; \
    apk add --no-cache deluge ; \
    echo "*** Create deluge group ***" ; \
    addgroup deluge ; \
    echo "*** Create deluge user ***" ; \
    adduser --system --home /var/lib/deluge -u 1000 --ingroup deluge deluge
    # adduser --system --home /var/lib/deluge --ingroup deluge deluge ; \
    # echo "*** Clean ***" ; \
    # apk cache clean

EXPOSE 8112 6881 6881/udp 58846 10000
VOLUME /deluge-conf /downloads /.openvpn

WORKDIR /entrypoint
CMD ["python3", "docker-entrypoint.py"]

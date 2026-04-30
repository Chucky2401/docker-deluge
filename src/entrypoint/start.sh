#!/usr/bin/env sh

# Default variable with value
CURRENTUID=$(id -u deluge)
CURRENTGID=$(id -g deluge)
USERID=$CURRENTUID
GROUPID=$CURRENTGID

VPN_FILE=${VPN_FILE:-/run/secrets/VPN_FILE}
LOCAL_VPN_FILE="/.wg/vpn.conf"
VPN_CREDENTIALS=${VPN_CREDENTIALS:-/run/secrets/VPN_CREDENTIALS}

REGEX_VPN_CLIENT="^openvpn|^wireguard"

DIR="/deluge-conf /downloads /.openvpn /.wg /entrypoint /template"

. /entrypoint/openvpn.sh
. /entrypoint/wireguard.sh

echo "************************************"
echo "*                                  *"
echo "*  ____       _                    *"
echo "* |  _ \  ___| |_   _  __ _  ___   *"
echo "* | | | |/ _ \ | | | |/ _\ |/ _ \  *"
echo "* | |_| |  __/ | |_| | (_| |  __/  *"
echo "* |____/ \___|_|\__,_|\__, |\___|  *"
echo "*                     |___/        *"
echo "*                                  *"
echo "************************************"
echo ""

if [[ ! "$VPN_CLIENT" =~ $REGEX_VPN_CLIENT ]]; then
  cat <<EOF
==> Please provide a valid VPN client in:
- openvpn
- wireguard
EOF

  exit 1
fi

# If VPN .conf file does not exist stop
if [[ ! -e "$VPN_FILE" ]]; then
  cat <<EOF
==> You must provide a valid .conf or .ovpn file by creating a secret named VPN_FILE:
  VPN_FILE:
    file: ./.secrets/file.conf
EOF
  exit 1
fi

echo "==> Setting $VPN_CLIENT..."

case "$VPN_CLIENT" in
"wireguard")
  set_wireguard "$LOCAL_VPN_FILE"
  SET_STATUS=$?
  ;;
"openvpn")
  LOCAL_VPN_FILE="/.openvpn/vpn.ovpn"
  set_openvpn "$LOCAL_VPN_FILE"
  SET_STATUS=$?
  ;;
esac

if [[ $SET_STATUS -ne 0 ]]; then
  cat <<EOF
Cannot set VPN client
EOF

  exit 1
fi

echo ""
echo "==> Setting Deluge..."

# Deluge web ui credentials
RANDOM_PASSWORD=$(
  tr -dc 'A-Za-z0-9!"#$%&'\''()*+,-./:;<=>?@[\]^_`{|}~' </dev/urandom | head -c 20
  echo
)

if [[ -z "$DELUGE_DAEMON_USERNAME" ]]; then
  echo "DELUGE_DAEMON_USERNAME is not set. Fallback to: deluge"
fi

if [[ -z "$DELUGE_DAEMON_PASSWORD" ]]; then
  echo "DELUGE_DAEMON_PASSWORD is not set. This random password will be set: ${RANDOM_PASSWORD}"
fi

if [[ -z "$DELUGE_DAEMON_USER_LEVEL" ]]; then
  echo "DELUGE_DAEMON_USER_LEVEL is not set. Defaul to administrator (10)"
fi

LOCAL_DELUGE_DAEMON_USERNAME=${DELUGE_DAEMON_USERNAME:-deluge}
LOCAL_DELUGE_DAEMON_PASSWORD=${DELUGE_DAEMON_PASSWORD:-$RANDOM_PASSWORD}
LOCAL_DELUGE_DAEMON_USER_LEVEL=${DELUGE_DAEMON_USER_LEVEL:-10}

if [[ -e "$DELUGE_DAEMON_PASSWORD" ]]; then
  LOCAL_DELUGE_DAEMON_PASSWORD=$(cat "$DELUGE_DAEMON_PASSWORD")
fi

DELUGE_CREDENTIALS="${LOCAL_DELUGE_DAEMON_USERNAME}:${LOCAL_DELUGE_DAEMON_PASSWORD}:${LOCAL_DELUGE_DAEMON_USER_LEVEL}"

if ! grep -q "$DELUGE_CREDENTIALS" /deluge-conf/auth; then
  echo "$DELUGE_CREDENTIALS" >/deluge-conf/auth
fi

echo ""
echo "==> Setting directories permissions..."

# Define UID and GID to deluge
if [[ -n "$PUID" ]]; then
  USERID=${PUID}
fi

if [[ -n "$PGID" ]]; then
  GROUPID=${PGID}
fi

if [[ "$USERID" != "$CURRENTUID" || "$GROUPID" != "$CURRENTGID" ]]; then
  usermod -g $GROUPID -u $USERID deluge
fi

# Update permissions
for e in ${DIR}; do
  chown -R $USERID:$GROUPID $e
done

# Update timezone
if [[ -n "$TZ" ]]; then
  ln -fs /usr/share/zoneinfo/${TZ} /etc/localtime
fi

# Export necessary variable
export LOCAL_VPN_FILE

# Empty line to lighten log
echo ""

# Prepare and run Deluge
# tail -f /dev/null
exec python3 ./start.py -c "$VPN_CLIENT"

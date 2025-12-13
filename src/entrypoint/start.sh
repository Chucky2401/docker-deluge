#!/usr/bin/env sh

# Default variable with value
CURRENTUID=$(id -u deluge)
CURRENTGID=$(id -g deluge)
USERID=$CURRENTUID
GROUPID=$CURRENTGID
VPN_FILE=${VPN_FILE:-/.openvpn/vpn.ovpn}

DIR="/deluge-conf /downloads /.openvpn /entrypoint /template"

# If no VPN credentials, either by env var or secrets, stop
if [[ -z "$VPN_USER" || -z "$VPN_PASSWORD" ]] && [[ ! -e /run/secrets/VPN_CREDENTIALS ]]; then
  cat <<EOF
==> Please provide a valid VPN username and password
You can use environment variables:
  - VPN_USER
  - VPN_PASSWORD

Or a secret name 'VPN_CREDENTIALS'
EOF

  exit 1
fi

# Define VPN credentials
VPN_USER=${VPN_USER}
VPN_PASSWORD=${VPN_PASSWORD}

if [[ -e /run/secrets/VPN_CREDENTIALS ]]; then
  { IFS= read -r VPN_USER && IFS= read -r VPN_PASSWORD; } </run/secrets/VPN_CREDENTIALS
fi

# Define VPN .ovpn file
if [[ -e /run/secrets/VPN_FILE ]]; then
  VPN_FILE="/run/secrets/VPN_FILE"
fi

# If VPN .ovpn file does not exist stop
if [[ ! -e "$VPN_FILE" ]]; then
  cat <<EOF
You must provide a valid .ovpn file or be sure the file exist here:
  ${VPN_FILE}
EOF
  exit 1
fi

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

if [[ -z "$DELUGE_LEVEL" ]]; then
  echo "DELUGE_LEVEL is not set. Defaul to administrator (10)"
fi

DELUGE_DAEMON_USERNAME=${DELUGE_DAEMON_USERNAME:-deluge}
DELUGE_DAEMON_PASSWORD=${DELUGE_DAEMON_PASSWORD:-$RANDOM_PASSWORD}
DELUGE_LEVEL=${DELUGE_LEVEL:-10}

if [[ -e "$DELUGE_DAEMON_PASSWORD" ]]; then
  DELUGE_DAEMON_PASSWORD=$(cat "$DELUGE_DAEMON_PASSWORD")
fi

DELUGE_CREDENTIALS="${DELUGE_DAEMON_USERNAME}:${DELUGE_DAEMON_PASSWORD}:${DELUGE_LEVEL}"

if ! grep -q "$DELUGE_CREDENTIALS" /deluge-conf/auth; then
  echo "$DELUGE_CREDENTIALS" >/deluge-conf/auth
fi

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
  ln -s /usr/share/zoneinfo/${TZ} /etc/localtime
fi

# Define VPN credentials files
cat <<-EOF >/var/lib/deluge/vpn
${VPN_USER}
${VPN_PASSWORD}
EOF
chmod 400 /var/lib/deluge/vpn

# Clear var
unset VPN_USER
unset VPN_PASSWORD

# Export necessary variable
export VPN_FILE

# Empty line to lighten log
echo ""

# Prepare and run Deluge
exec python3 ./start.py

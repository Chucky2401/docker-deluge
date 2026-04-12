#!/usr/bin/env sh

# Default variable with value
CURRENTUID=$(id -u deluge)
CURRENTGID=$(id -g deluge)
USERID=$CURRENTUID
GROUPID=$CURRENTGID
LOCAL_VPN_FILE="/.wg/vpn.conf"

DIR="/deluge-conf /downloads /.wg /entrypoint /template"

echo "************************************"
echo "*                                  *"
echo "*  ____       _                    *"
echo "* |  _ \  ___| |_   _  __ _  ___   *"
echo "* | | | |/ _ \ | | | |/ _\` |/ _ \  *"
echo "* | |_| |  __/ | |_| | (_| |  __/  *"
echo "* |____/ \___|_|\__,_|\__, |\___|  *"
echo "*                     |___/        *"
echo "*                                  *"
echo "************************************"
echo ""

# If no VPN credentials, either by env var or secrets, stop
if [[ -z "$PRIVATE_KEY" || -z "$PRESHARED_KEY" || -z "$ADDRESS" ]] && [[ ! -e /run/secrets/VPN_CREDENTIALS ]]; then
  cat <<EOF
==> Please provide a valid VPN username and password
You can use environment variables:
  - PRIVATE_KEY
  - PRESHARED_KEY
  - ADDRESS

Or a secret name 'VPN_CREDENTIALS', the file must have the following format:
PRIVATE_KEY
PRESHARED_KEY
ADDRESS
EOF

  exit 1
fi

# Define VPN credentials
LOCAL_PRIVATE_KEY=${PRIVATE_KEY}
LOCAL_PRESHARED_KEY=${PRESHARED_KEY}
LOCAL_ADDRESS=${ADDRESS}

if [[ -e "$VPN_CREDENTIALS" ]]; then
  { IFS= read -r LOCAL_PRIVATE_KEY && IFS= read -r LOCAL_PRESHARED_KEY && IFS= read -r LOCAL_ADDRESS; } <"$VPN_CREDENTIALS"
fi

# If VPN .conf file does not exist stop
if [[ ! -e "$VPN_FILE" ]]; then
  cat <<EOF
You must provide a valid .conf file or be sure the file exist here:
  ${VPN_FILE}
EOF
  exit 1
fi

# Copy secrets file to internal file only if necessary
if [[ "$VPN_FILE" != "$LOCAL_VPN_FILE" ]]; then
  cp $VPN_FILE $LOCAL_VPN_FILE
fi

# Define VPN conf file with data
sed -i -e "s/\(PrivateKey = \).*/\1${LOCAL_PRIVATE_KEY}/g" $LOCAL_VPN_FILE
sed -i -e "s/\(PresharedKey = \).*/\1${LOCAL_PRESHARED_KEY}/g" $LOCAL_VPN_FILE
sed -i -e "s/\(Address = \).*/\1${LOCAL_ADDRESS}/g" $LOCAL_VPN_FILE
sed -i -e "s/\(DNS = \).*/\1/g" $LOCAL_VPN_FILE

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

# Clear var
unset PRIVATE_KEY
unset PRESHARED_KEY
unset ADDRESS
unset LOCAL_PRIVATE_KEY
unset LOCAL_PRESHARED_KEY
unset LOCAL_ADDRESS

# Export necessary variable
export LOCAL_VPN_FILE

# Empty line to lighten log
echo ""

# Prepare and run Deluge
# tail -f /dev/null
exec python3 ./start.py

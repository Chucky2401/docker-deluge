#!/usr/bin/env sh

set_wireguard() {
  if [[ -z "$PRIVATE_KEY" || -z "$PRESHARED_KEY" || -z "$ADDRESS" ]] &&
    [[ ! -e "$PRIVATE_KEY_FILE" || -e "$PRESHARED_KEY_FILE" || -e "$ADDRESS_FILE" ]] &&
    [[ ! -e "$VPN_CREDENTIALS" ]]; then
    cat <<EOF
You need to provide at least the following:
- PRIVATE_KEY(_FILE)
- PRESHARED_KEY(_FILE)
- ADDRESS(_FILE)
  -- OR --
- VPN_CREDENTIALS with the following format:
  PRIVATE_KEY
  PRESHARED_KEY
  ADDRESS
EOF

    return 1
  fi

  echo " * Define VPN credentials"
  # Define VPN credentials
  local LOCAL_PRIVATE_KEY=${PRIVATE_KEY}
  local LOCAL_PRESHARED_KEY=${PRESHARED_KEY}
  local LOCAL_ADDRESS=${ADDRESS}

  # Use secret file if set
  if [[ -e "$VPN_CREDENTIALS" ]]; then
    { IFS= read -r LOCAL_PRIVATE_KEY && IFS= read -r LOCAL_PRESHARED_KEY && IFS= read -r LOCAL_ADDRESS; } <"$VPN_CREDENTIALS"
  fi

  cp $VPN_FILE $LOCAL_VPN_FILE

  # Define VPN conf file with data
  sed -i -e "s/\(PrivateKey = \).*/\1${LOCAL_PRIVATE_KEY}/g" $LOCAL_VPN_FILE
  sed -i -e "s/\(PresharedKey = \).*/\1${LOCAL_PRESHARED_KEY}/g" $LOCAL_VPN_FILE
  sed -i -e "s/\(Address = \).*/\1${LOCAL_ADDRESS}/g" $LOCAL_VPN_FILE
  sed -i -e "s/\(DNS = \).*/\1/g" $LOCAL_VPN_FILE
}

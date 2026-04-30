#!/usr/bin/env sh

set_openvpn() {
  if [[ -n "$VPN_USER" && -n "$VPN_PASSWORD" ]] ||
    [[ -e "$VPN_USER_FILE" && -e "$VPN_PASSWORD_FILE" ]]; then
    cat <<EOF
You need to provide at least the following:
- VPN_USER(_FILE)
- VPN_PASSWORD(_FILE)
or
- VPN_CREDENTIALS with the following format:
  VPN_USER
  VPN_PASSWORD
EOF

    return 1
  fi

  echo " * Define VPN credentials"
  # Define VPN credentials
  local LOCAL_VPN_USER=${VPN_USER}
  local LOCAL_VPN_PASSWORD=${VPN_PASSWORD}

  # Use secret file if set
  if [[ -e "$VPN_CREDENTIALS" ]]; then
    { IFS= read -r LOCAL_VPN_USER && IFS= read -r LOCAL_VPN_PASSWORD; } <"$VPN_CREDENTIALS"
  fi

  cp $VPN_FILE $LOCAL_VPN_FILE

  cat <<-EOF >/var/lib/deluge/vpn
${LOCAL_VPN_USER}
${LOCAL_VPN_PASSWORD}
EOF

  chmod 400 /var/lib/deluge/vpn
}

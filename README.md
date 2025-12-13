# Docker OpenVPN/Deluge

Find me at:

* [Blog](https://blackwizard.fr)
* [GitHub](https://github.com/Chucky2401)

Deluge is a lightweight, Free Software, cross-platform BitTorrent client.

<a href="https://deluge-torrent.org"><img src="https://www.omgubuntu.co.uk/wp-content/uploads/2019/06/the-new-deluge-icon-300x300.png" alt="placeholder" width="48"></a>

## Supported Architectures

Simply pulling `chucky2401/deluge:tagversion` should retrieve the correct image
for your arch.

Actually, only the following arch are available:

* linux/amd64
* linux/arm64

## Usage

To help you get started creating a container from this image, you will find
docker compose example below.

### docker compose (recommended)

With the below configuration, you must have prepare the following:

* `openvpn` directory with the `vpn.ovpn` file
* `vpn_credentials` file to authenticate to the VPN. You must respect this
format:

  ```
  username
  password
  ```

This example is the most simple.

```yaml
services:
  syncrelay:
    image: chucky2401/deluge:latest
    container_name: deluge
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Paris
      - LOCAL_NETWORK=192.168.1.0/24
      - DELUGE_LOGLEVEL=warning
      - VPN_FILE=/.openvpn/vpn.ovpn
    volumes:
      - ./openvpn/:/.openvpn
      - ./config/:/deluge-conf
      - ./downloads:/downloads
    ports:
      - 8112:8112
      - 6881:6881
      - 6881:6881/udp
      - 58846:58846
    dns:
      - 8.8.8.8
      - 8.4.4.8
    dns_search: '.'
    restart: unless-stopped
    secrets:
      - VPN_CREDENTIALS

secrets:
  # The VPN_CREDENTIALS must have
  # username on first line and
  # password on second line
  VPN_CREDENTIALS:
    file: vpn_credentials
```

You can replace the `vpn_credentials` secrets with the following environment
variables:

* VPN_USER
* VPN_PASSWORD

But I don't recommend them, as the variables will be in clear text in the
container.

## Parameters

Here the list of all parameters.

For the `VPN_CREDENTIALS` no need to set an environment variable, but the secret
must be write exactly as above

| Parameter | Default | Remark | Function |
| :-------: | ------- | ------ |-------- |
| `PUID=1000` | `1000` | **Optional** | for UserID - see below for explanation |
| `PGID=1000` | `1000` | **Optional** | for GroupID - see below for explanation |
| `TZ=Europe/Paris` | `N/A` | **Optional** | specify a timezone to use, see this [list](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List). |
| `LOCAL_NETWORK=192.168.1.0/24` | `Empty` | **Mandatory** | Define your local network ip range with CIDR to be able to access the container |
| `DELUGE_LOGLEVEL=warning` | `error` | **Optional** | Set the Deluge log level. (Valid values: none; info; warning; error; debug) |
| `VPN_FILE=/.openvpn/vpn.ovpn` | `N/A` | **Mandatory** | Internal container path to the OpenVPN .ovpn file. You can use a Docker secret |
| `DELUGE_DAEMON_USERNAME=` | `deluge` | **Optional** | Username to access the Deluge daemon |
| `DELUGE_PASSWORD=` | *random* | **Optional** - *Use `docker logs` to find it or open `./config/auth`*. You can also use a Docker secret | Password of the associated username to access the Deluge daemon |
| `DELUGE_LEVEL=` | `10` | **Optional** | Level access of the associated username. (Valid values: 0 (None); 1 (Read only); 5 (Normal); 10 (Administrator)) |
| `VPN_USER=` | `N/A` | **Not recommended** | Set the VPN username |
| `VPN_PASSWORD=` | `N/A` | **Not recommended** | Set the VPN password |

### Deluge password with secret

You can use a Docker secret to set Deluge daemon access password like `VPN_CREDENTIALS`

```yaml
  [...]
    environment:
      - DELUGE_PASSWORD=/run/secrets/DELUGE_PASSWORD
    secrets:
      - DELUGE_PASSWORD
  [...]

secrets:
  DELUGE_PASSWORD:
    file: deluge_password
```

### OpenVPN file with secret

You can use a Docker secret to set OpenVPN file configuration like `VPN_CREDENTIALS`

```yaml
  [...]
    environment:
      - VPN_FILE=/run/secrets/VPN_FILE
    secrets:
      - VPN_FILE
  [...]

secrets:
  VPN_FILE:
    file: vpn.ovpn
```

## Complete example with only secrets

```yaml
services:
  deluge:
    container_name: deluge
    image: chucky2401/deluge:latest
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Paris
      - LOCAL_NETWORK=192.168.1.0/24
      - DELUGE_LOGLEVEL=warning
      - DELUGE_DAEMON_USERNAME=user
      - DELUGE_PASSWORD=/run/secrets/DELUGE_PASSWORD
      - DELUGE_LEVEL=10
      - VPN_FILE=/run/secrets/VPN_FILE
    volumes:
      - ./config/:/deluge-conf
      - ./downloads:/downloads
    ports:
      - 8112:8112
      - 6881:6881
      - 6881:6881/udp
      - 58846:58846
    networks:
      - deluge
    dns:
      - 8.8.8.8
      - 8.4.4.8
    dns_search: '.'
    restart: unless-stopped
    secrets:
      - VPN_CREDENTIALS
      - VPN_FILE
      - DELUGE_PASSWORD
    labels:
      - wud.watch=false
    deploy:
      resources:
        limits:
          memory: 1G

networks:
  deluge:
    driver: bridge
    enable_ipv6: false

secrets:
  VPN_CREDENTIALS:
    file: vpn_credentials
  VPN_FILE:
    file: vpn.ovpn
  DELUGE_PASSWORD:
    file: deluge_password
```

## User / Group Identifiers

When using volumes (`-v` flags), permissions issues can arise between the host
OS and the container, I avoid this issue by allowing you to specify the user
`PUID` and group `PGID`.

Ensure any volume directories on the host are owned by the same user you specify
and any permissions issues will vanish like magic.

In this instance `PUID=1000` and `PGID=1000`, to find yours use `id your_user`
as below:

```bash
id your_user
```

Example output:

```text
uid=1000(your_user) gid=1000(your_user) groups=1000(your_user)
```

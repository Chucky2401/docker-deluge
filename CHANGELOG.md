# Changelog

## 1.0.0 - 2026.04.12

### News

- Use a shell script as entrypoint for basic configuration
  - Prepare file for VPN credentials
  - Checking VPN file as been declared
  - Set Deluge daemon credentials. Generate user/password if not set
  - Change user UID/GID if set PUID/PGID are set
  - Update timezone
- Copy a default **core.conf** if not exist
- Add OpenContainers label
- Add `compose.build.yaml` and `run_compose_build.sh` to try out the image
- Add Header for the Docker logs

### Changes

- Check when `tun0` is up to continue starting

### Fixes

- Wrong error message for interface
- Use `getenv()` in case of non set value
- Message said **core.conf** has been copied event not the case

### Commits

- *6b4e69f* - doc(changelog): complete changelog
- *c1bf8ad* - fix(py): message bad position
- *3524b9c* - feat(sh): add header
- *e5ac0b4* - doc(readme): add roadmap and faq
- *f7399d6* - chore(compose): add test for DELUGE_DAEMON_PORT
- *ed17ee3* - chore(sh): force timezone link file to remove error message
- *044d391* - chore(py): test current port before set
- *e85d0bb* - fix(py): bad keywork for exception
- *5caeca8* - fix(py): use getenv() with default value to the default port
- *bffd58f* - feat: add env var to set the daemon port
- *e66b807* - chore: change DELUGE_LEVEL to DELUVE_DAEMON_USER_LEVEL
- *8333210* - chore: change DELUGE_PASSWORD to DELUGE_DAEMON_PASSWORD
- *bdf99fb* - chore(readme): visual update
- *6a85e3a* - chore: change DELUGE_USERNAME to DELUGE_DAEMON_USERNAME
- *b0e107f* - fix(py): error message for interface is wrong
- *8a5550b* - doc(readme): use HTML to show icon
- *756c87d* - doc: write a proper readme
- *7de1b5e* - feat: script to run docker compose with build
- *f967820* - feat(compose-build): set args from environment var for build
- *af5bd39* - feat: define a compose file with build
- *968e6fb* - feat: move docker-entrypoint.py to start.py
- *64485ca* - chore(Dockerfile): remove useless port
- *aa936de* - feat(Dockerfile): use only one COPY directive
- *8b76519* - feat(Dockerfile): use one RUN directive and enhance it
- *240f113* - feat(Dockerfile): set PUID & PGID as ENV
- *95cd8ad* - chore(Dockerfile): use opencontainers label
- *bc2e01e* - feat: add start.sh as ENTRYPOINT
- *fce8c9f* - chore(git): resotre notes/ in ignore
- *da81bd0* - chore: clean and update .gitignore
- *1412871* - chore: alias.sh
- *05f8908* - chore: move core.conf template to container destination
- *ce6f438* - feat: enhance globally entrypoint and set interfaces
- *6bfc938* - feat: remove useless settings and enhance some
- *42a7a48* - chore: add template core.conf

---

## 0.0.12 - 2023.08.09

- First version of this image

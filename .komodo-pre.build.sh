#!/usr/bin/env bash

################################################################################
#                                                                              #
#                                  DECLARATION                                 #
#                                                                              #
################################################################################

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

function show_help() {
  cat <<EOF
${shell_underline}${0^^}${shell_reset}          Help page

${shell_bold}USAGE${shell_reset}
  $0 -c|--certificatename -d|--domain -r|--repodir [-h|--help]"

${shell_bold}OPTIONS${shell_reset}
  -c, --certificatename CERTIFICATE_NAME   Root CA certificatename
  -r, --repodir         REPO_DIR           Directory fo the current repo
  -s, --servername      SERVER_NAME        Server name FQDN
  -h, --help                      Affiche l'aide (ce message)

${shell_bold}EXAMPLES${shell_reset}
  $0  -c "CERTCA" -r "/repos/syncrelay" -s "forgejo.lan.domain.com"
EOF

  exit 0
}

################################################################################
#                                                                              #
#                                   VARIABLES                                  #
#                                                                              #
################################################################################

OPTS=$(getopt -o c:r:s:h --long certificatename:repodir:servername:,help -n '.komodo-pre.build.sh' -- "$@")

if [[ $? -ne 0 ]]; then
  error_message "Échec de l'analyse des options"
  exit 1
fi

eval set -- "$OPTS"

CERTIFICATE_NAME=""
REPO_DIR=""
SERVER_NAME=""
HELP="false"

while true; do
  case "$1" in
  -c | --certificatename)
    CERTIFICATE_NAME="${2}"
    shift 2
    ;;
  -r | --repodir)
    REPO_DIR="${2}"
    shift 2
    ;;
  -s | --servername)
    SERVER_NAME="${2}"
    shift 2
    ;;
  -h | --help)
    HELP="true"
    shift
    ;;
  --)
    shift
    break
    ;;
  esac
done

if [[ "$HELP" == "true" ]]; then
  show_help
  exit 0
fi

BUILDER_EXIST=0
DOCKER_EXIST=0
CERTIFICATE_VALID=0
CERT_PATH=""
BUILDER_NAME="mybuilder"
CONTAINER_NAME="buildx_buildkit_mybuilder0"

################################################################################
#                                                                              #
#                                     MAIN                                     #
#                                                                              #
################################################################################

if docker ps -a | grep "$CONTAINER_NAME" &>/dev/null; then
  DOCKER_EXIST=1
fi

if docker buildx ls | grep -q "$BUILDER_NAME" &>/dev/null; then
  BUILDER_EXIST=1
fi

if [[ $DOCKER_EXIST -eq 1 && $BUILDER_EXIST -eq 1 ]]; then
  CERT_PATH=$(docker exec $CONTAINER_NAME sh -c "ls /etc/buildkit/certs/$SERVER_NAME/*$CERTIFICATE_NAME*")
fi

if [[ -n "$CERT_PATH" ]]; then
  if docker exec $CONTAINER_NAME sh -c "openssl x509 -checkend 86400 -noout -in $CERT_PATH" &>/dev/null; then
    CERTIFICATE_VALID=1
  fi
fi

if [[ $BUILDER_EXIST -eq 0 || $DOCKER_EXIST -eq 0 || $CERTIFICATE_VALID -eq 0 ]]; then
  echo "Need recreate builder"

  # Copy internal CA cert in the repo directory
  certs=$(ls /etc/ssl/certs/*$CERTIFICATE_NAME*.pem)
  for cert in $certs; do cp $cert $REPO_DIR/; done

  # Create the buildkit.toml file
  echo "debug = true" >$REPO_DIR/buildkit.toml
  echo "[registry.\"${SERVER_NAME}\"]" >>$REPO_DIR/buildkit.toml
  certs=$(ls ${REPO_DIR}/*${CERTIFICATE_NAME}*.pem)
  for cert in $certs; do echo "  ca = [\"$cert\"]" >>${REPO_DIR}/buildkit.toml; done

  # Remove previous and create fresh builder
  docker buildx stop $BUILDER_NAME
  docker buildx rm $BUILDER_NAME
  docker buildx create --name $BUILDER_NAME --use --bootstrap --node mybuilder0 --buildkitd-config ${REPO_DIR}/buildkit.toml

  # Remove working file
  rm -f *${CERTIFICATE_NAME}*.pem ${REPO_ROOT}/buildkit.toml
else
  echo "Builder up to date"
fi

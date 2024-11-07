KEY_FILE=${KEY_FILE:-"$(__get-current-home-dir)/.ssh/id_rsa"}
PUB_KEY_FILE=${PUB_KEY_FILE:-"${KEY_FILE}.pub"}

CURRENT_USER="$(__get-current-user)"

DEFAULT_USER=${DEFAULT_USER:-"root"}

is-default-user() {
  [[ "${CURRENT_USER}" == "${DEFAULT_USER}" ]]
}

default-user-home() {
  if [[ "${DEFAULT_USER}" == "root" ]]; then
    echo "/root"
  else
    echo "/home/${DEFAULT_USER}"
  fi
}

DEFAULT_USER_HOME=${DEFAULT_USER_HOME:-"$(default-user-home)"}

DEFAULT_USER_KEY_FILE=${DEFAULT_USER_KEY_FILE:-"${DEFAULT_USER_HOME}/.ssh/id_rsa"}
DEFAULT_USER_PUB_KEY_FILE=${DEFAULT_USER_PUB_KEY_FILE:-"${DEFAULT_USER_KEY_FILE}.pub"}

default-user-pub-key() {
  sudo mkdir -p "$(dirname ${DEFAULT_USER_PUB_KEY_FILE})"
  sudo chmod 700 "$(dirname ${DEFAULT_USER_PUB_KEY_FILE})"
  sudo chown "${DEFAULT_USER}:${DEFAULT_USER}" "$(dirname ${DEFAULT_USER_PUB_KEY_FILE})"

  if [[ -f "${DEFAULT_USER_PUB_KEY_FILE}" ]]; then
    sudo cat "${DEFAULT_USER_PUB_KEY_FILE}"
  else
    echo ""
  fi
}

DEFAULT_USER_PUB_KEY=${DEFAULT_USER_PUB_KEY:-"$(default-user-pub-key)"}

check-pub-key-file() {
  mkdir -p "$(dirname ${PUB_KEY_FILE})"
  chmod 700 "$(dirname ${PUB_KEY_FILE})"

  if [[ ! -f "${PUB_KEY_FILE}" ]]; then
    echo "PUB_KEY_FILE: ${PUB_KEY_FILE} is not exists!" >&2
    exit 1
  fi
}

check-default-user-mode() {
  if __is-sudo; then
    echo "Execution in \"sudo\" mode, abort the operation."
    exit 1
  fi

  if ! is-default-user; then
    echo "Current user: ${CURRENT_USER} is not the default user: ${DEFAULT_USER}, abort the operation."
    exit 1
  fi
}

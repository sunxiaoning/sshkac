KEY_FILE=${KEY_FILE:-"$(__get-current-home-dir)/.ssh/id_rsa"}
PUB_KEY_FILE=${PUB_KEY_FILE:-"${KEY_FILE}.pub"}

check-pub-key-file() {
  mkdir -p "$(dirname ${PUB_KEY_FILE})"

  if [[ ! -f "${PUB_KEY_FILE}" ]]; then
    echo "PUB_KEY_FILE: ${PUB_KEY_FILE} is not exists!" >&2
    exit 1
  fi
}

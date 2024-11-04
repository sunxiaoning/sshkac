KNOWN_HOSTS_FILE="$(__get-current-home-dir)/.ssh/known_hosts"

REMOTE_PASSWORD=${REMOTE_PASSWORD:-""}

STRICT_HOST_KEY_CHECKING_YES="yes"
STRICT_HOST_KEY_CHECKING_ACCEPT_NEW="accept-new"
STRICT_HOST_KEY_CHECKING_NO="no"

STRICT_HOST_KEY_CHECKING=${STRICT_HOST_KEY_CHECKING:-"${STRICT_HOST_KEY_CHECKING_YES}"}

REMOTE_USER=${REMOTE_USER:-"$(__get-current-user)"}

TARGET_HOSTS=${TARGET_HOSTS:-""}
TARGET_HOSTS_ARRAY=()

AUTHORIZED_KEYS_FILE="$(__get-current-home-dir)/.ssh/authorized_keys"

SOURCE_KEY_IDENTIFIERS=${SOURCE_KEY_IDENTIFIERS:-""}
SOURCE_KEY_IDENTIFIERS_ARRAY=()

trust-target-hosts() {
  check-target-hosts

  mkdir -p "$(dirname ${KNOWN_HOSTS_FILE})"

  if [[ ! -f "${KNOWN_HOSTS_FILE}" ]]; then
    touch "${KNOWN_HOSTS_FILE}"
  fi

  for target_host in "${TARGET_HOSTS_ARRAY[@]}"; do
    local target_host_key=$(ssh-keyscan "${target_host}" 2>/dev/null)

    if [ -z "${target_host_key}" ]; then
      echo "Failed to retrieve the host key for ${target_host}." >&2
      exit 1
    fi

    if grep -q "${target_host}" "${KNOWN_HOSTS_FILE}"; then
      if ! grep -F -q "${target_host_key}" "${KNOWN_HOSTS_FILE}"; then
        sed -i.bak "/${target_host}/d" "${KNOWN_HOSTS_FILE}"
        echo "${target_host_key}" >>"${KNOWN_HOSTS_FILE}"
        echo "Host key for ${target_host} updated in known_hosts."
      else
        echo "Host key for ${target_host} already exists in known_hosts and is up to date."
      fi
    else
      echo "${target_host_key}" >>"${KNOWN_HOSTS_FILE}"
      echo "Host key for ${target_host} added to known_hosts."
    fi
  done
}

untrust-target-hosts() {
  check-target-hosts

  mkdir -p "$(dirname ${KNOWN_HOSTS_FILE})"

  if [[ ! -f "${KNOWN_HOSTS_FILE}" ]]; then
    touch "${KNOWN_HOSTS_FILE}"
  fi

  for target_host in "${TARGET_HOSTS_ARRAY[@]}"; do
    echo "Host key for ${target_host} removed from known_hosts."
    sed -i.bak "/${target_host}/d" "${KNOWN_HOSTS_FILE}"
  done
}

auth-target-hosts() {
  if [[ -z "${REMOTE_PASSWORD}" ]]; then
    echo "REMOTE_PASSWORD param is empty!" >&2
    exit 1
  fi

  check-pub-key-file

  check-target-hosts

  if ! rpm -q "sshpass" &>/dev/null; then
    yum -y install sshpass
  fi

  for target_host in "${TARGET_HOSTS_ARRAY[@]}"; do
    sshpass -v -p "${REMOTE_PASSWORD}" ssh-copy-id -i "${PUB_KEY_FILE}" -o StrictHostKeyChecking="${STRICT_HOST_KEY_CHECKING}" "${REMOTE_USER}@${target_host}"

    # restart target_host ??

    echo "granted authentication to target host: ${target_host}"

  done
}

revoke-target-hosts() {
  if [[ -z "${REMOTE_PASSWORD}" ]]; then
    echo "REMOTE_PASSWORD param is empty!" >&2
    exit 1
  fi

  check-pub-key-file

  check-target-hosts

  if ! rpm -q "sshpass" &>/dev/null; then
    yum -y install sshpass
  fi

  local pub_key_escaped="$(cat ${PUB_KEY_FILE} | sed 's/[\/&]/\\&/g')"

  for target_host in "${TARGET_HOSTS_ARRAY[@]}"; do
    sshpass -v -p "${REMOTE_PASSWORD}" ssh "${REMOTE_USER}@${target_host}" "bash -c \"
        sed -i.bak '/${pub_key_escaped}/d' ${AUTHORIZED_KEYS_FILE}\""

    echo "revoked authentication to target host: ${target_host}"
  done
}

revoke-source-keys() {
  check-source-keys

  for key_identifier in "${SOURCE_KEY_IDENTIFIERS_ARRAY[@]}"; do

    local key_identifier_escaped="$(echo ${key_identifier} | sed 's/[\/&]/\\&/g')"

    # only last operation bak exists
    sed -i.bak "/${key_identifier_escaped}/d" "${AUTHORIZED_KEYS_FILE}"

    echo "revoked authentication from source key: ${key_identifier}"
  done
}

check-source-keys() {
  if [ -z "${SOURCE_KEY_IDENTIFIERS}" ]; then
    echo "SOURCE_KEY_IDENTIFIERS is empty!" >&2
    exit 1
  fi

  IFS=',' read -r -a SOURCE_KEY_IDENTIFIERS_ARRAY <<<"${SOURCE_KEY_IDENTIFIERS}"

  if [ "${#SOURCE_KEY_IDENTIFIERS_ARRAY[@]}" -lt 1 ]; then
    echo "SOURCE_KEY_IDENTIFIERS is invalid!" >&2
    exit 1
  fi
}

check-target-hosts() {
  if [ -z "${TARGET_HOSTS}" ]; then
    echo "TARGET_HOSTS is empty!" >&2
    exit 1
  fi

  IFS=',' read -r -a TARGET_HOSTS_ARRAY <<<"${TARGET_HOSTS}"

  if [ "${#TARGET_HOSTS_ARRAY[@]}" -lt 1 ]; then
    echo "TARGET_HOSTS is invalid!" >&2
    exit 1
  fi
}

KNOWN_HOSTS_FILE="$(__get-current-home-dir)/.ssh/known_hosts"

REMOTE_PASSWORD=${REMOTE_PASSWORD:-""}

STRICT_HOST_KEY_CHECKING_YES="yes"
STRICT_HOST_KEY_CHECKING_ACCEPT_NEW="accept-new"
STRICT_HOST_KEY_CHECKING_NO="no"

STRICT_HOST_KEY_CHECKING=${STRICT_HOST_KEY_CHECKING:-"${STRICT_HOST_KEY_CHECKING_YES}"}

REMOTE_USER="${CURRENT_USER}"

TARGET_HOSTS=${TARGET_HOSTS:-""}
TARGET_HOSTS_ARRAY=()

EXECRSH_SH_FILE="${CONTEXT_DIR}/bashutils/execrsh.sh"

AUTHORIZED_KEYS_FILE="$(__get-current-home-dir)/.ssh/authorized_keys"

SOURCE_KEY_IDENTIFIERS=${SOURCE_KEY_IDENTIFIERS:-""}
SOURCE_KEY_IDENTIFIERS_ARRAY=()

trust-target-hosts() {
  check-target-hosts

  check-default-user-mode

  mkdir -p "$(dirname ${KNOWN_HOSTS_FILE})"
  chmod 700 "$(dirname ${KNOWN_HOSTS_FILE})"

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

  check-default-user-mode

  mkdir -p "$(dirname ${KNOWN_HOSTS_FILE})"
  chmod 700 "$(dirname ${KNOWN_HOSTS_FILE})"

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

  local remote_password="${REMOTE_PASSWORD}"
  unset REMOTE_PASSWORD

  check-pub-key-file

  check-target-hosts

  check-default-user-mode

  if ! rpm -q "sshpass" &>/dev/null; then
    yum -y install sshpass
  fi

  for target_host in "${TARGET_HOSTS_ARRAY[@]}"; do
    sshpass -v -p "${remote_password}" ssh-copy-id -i "${PUB_KEY_FILE}" -o StrictHostKeyChecking="${STRICT_HOST_KEY_CHECKING}" "${REMOTE_USER}@${target_host}"

    "${EXECRSH_SH_FILE}" -e "-o BatchMode=yes" -p "${CONTEXT_DIR}/bashutils/basicenv.sh ${CONTEXT_DIR}/app/env.sh ${CONTEXT_DIR}/app/sec.sh ${CONTEXT_DIR}/rsh/app/ ${CONTEXT_DIR}/rsh/rsh.sh" -a "forbid-password-authentication" -s "${target_host}" rsh.sh &

    wait $!

    if [[ "${DEFAULT_USER}" != "root" ]]; then
      echo "DEFAULT_USER is not \"root\", pervent the \"root\" login."

      "${EXECRSH_SH_FILE}" -e "-o BatchMode=yes" -b "DEFAULT_USER=${DEFAULT_USER} DEFAULT_USER_PUB_KEY=\"${DEFAULT_USER_PUB_KEY}\"" -p "${CONTEXT_DIR}/bashutils/basicenv.sh ${CONTEXT_DIR}/app/env.sh ${CONTEXT_DIR}/app/sec.sh ${CONTEXT_DIR}/rsh/app/ ${CONTEXT_DIR}/rsh/rsh.sh" -a "prevent-root-login" -s "${target_host}" rsh.sh &

      wait $!
    fi

    # Please restart the target host to terminate all existing connections for security purposes; however, note that restarting the host is a critical operation, so proceed with caution.

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

  check-default-user-mode

  if ! rpm -q "sshpass" &>/dev/null; then
    yum -y install sshpass
  fi

  local pub_key_escaped="$(cat ${PUB_KEY_FILE} | sed 's/[\/&]/\\&/g')"

  for target_host in "${TARGET_HOSTS_ARRAY[@]}"; do

    # [Warning] You need either a password or a key; otherwise, you'll lose access to the target host and won't be able to connect via SSH.

    if [[ "${DEFAULT_USER}" != "root" ]]; then
      echo "DEFAULT_USER is not \"root\", allow the \"root\" login."

      "${EXECRSH_SH_FILE}" -e "-o BatchMode=yes" -b "DEFAULT_USER=${DEFAULT_USER} DEFAULT_USER_PUB_KEY=\"${DEFAULT_USER_PUB_KEY}\"" -p "${CONTEXT_DIR}/bashutils/basicenv.sh ${CONTEXT_DIR}/app/env.sh ${CONTEXT_DIR}/app/sec.sh ${CONTEXT_DIR}/rsh/app/ ${CONTEXT_DIR}/rsh/rsh.sh" -a "allow-root-login" -s "${target_host}" rsh.sh &

      wait $!
    fi

    "${EXECRSH_SH_FILE}" -e "-o BatchMode=yes" -b "DEFAULT_USER=${DEFAULT_USER}" -p "${CONTEXT_DIR}/bashutils/basicenv.sh ${CONTEXT_DIR}/app/env.sh ${CONTEXT_DIR}/app/sec.sh ${CONTEXT_DIR}/rsh/app/ ${CONTEXT_DIR}/rsh/rsh.sh" -a "permit-password-authentication" -s "${target_host}" rsh.sh &

    wait $!

    sshpass -v -p "${REMOTE_PASSWORD}" ssh "${REMOTE_USER}@${target_host}" "bash -c \"
        mkdir -p $(dirname ${AUTHORIZED_KEYS_FILE}) && \
        chmod 700 $(dirname ${AUTHORIZED_KEYS_FILE}) && \
        if [[ -f ${AUTHORIZED_KEYS_FILE} ]]; then
          sed -i.bak '/${pub_key_escaped}/d' ${AUTHORIZED_KEYS_FILE} && \
          echo "revoked authentication to target host: ${target_host}"
        fi\""
  done
}

revoke-source-keys() {
  check-source-keys

  check-default-user-mode

  mkdir -p "$(dirname ${AUTHORIZED_KEYS_FILE})"
  chmod 700 "$(dirname ${AUTHORIZED_KEYS_FILE})"

  for key_identifier in "${SOURCE_KEY_IDENTIFIERS_ARRAY[@]}"; do

    local key_identifier_escaped="$(echo ${key_identifier} | sed 's/[\/&]/\\&/g')"

    # only last operation bak exists
    if [[ -f ${AUTHORIZED_KEYS_FILE} ]]; then
      sed -i.bak "/${key_identifier_escaped}/d" "${AUTHORIZED_KEYS_FILE}"
      echo "revoked authentication from source key: ${key_identifier}"
    fi
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

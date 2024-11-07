SSHD_CONFIG_FILE="/etc/ssh/sshd_config"

PASSWORD_AUTHENTICATION_KEY="PasswordAuthentication"

PERMIT_ROOT_LOGIN_KEY="PermitRootLogin"

SSH_CONFIG_FUNCTION=""
SSH_CONFIG_KEY=""
SSH_CONFIG_VAL=""

ROOT_AUTHORIZED_KEYS_FILE="/root/.ssh/authorized_keys"

# Please restart the target host to terminate all existing connections for security purposes; however, note that restarting the host is a critical operation, so proceed with caution.

forbid-password-authentication() {
  SSH_CONFIG_KEY="${PASSWORD_AUTHENTICATION_KEY}"
  SSH_CONFIG_VAL="no"
  update-ssh-config
  echo "${PASSWORD_AUTHENTICATION_KEY} has been forbidden."
}

permit-password-authentication() {
  SSH_CONFIG_KEY="${PASSWORD_AUTHENTICATION_KEY}"
  SSH_CONFIG_VAL="yes"
  update-ssh-config
  echo "${PASSWORD_AUTHENTICATION_KEY} has been permitted."
}

forbid-root-login() {
  SSH_CONFIG_KEY="${PERMIT_ROOT_LOGIN_KEY}"
  SSH_CONFIG_VAL="no"
  update-ssh-config
  echo "${PERMIT_ROOT_LOGIN_KEY} has been forbidden."

  # Root authentication will consistently fail without any messages.
}

permit-root-login() {
  SSH_CONFIG_KEY="${PERMIT_ROOT_LOGIN_KEY}"
  SSH_CONFIG_VAL="yes"
  update-ssh-config
  echo "${PERMIT_ROOT_LOGIN_KEY} has been permitted."
}

prevent-root-login() {

  # To prevent logging in as the root user using an SSH key while still allowing password-based login. If stricter root login restrictions are required, please use the forbid-root-login function or combine it with the forbid-password-authentication function. In other words, this function is limited in scope and only applies to key-based login scenarios. Its purpose is to guide users who log in with the root account to use a regular user account instead, thereby reducing the security risks associated with frequent use of the root account.

  echo "DEFAULT_USER: ${DEFAULT_USER}"

  if [[ "${DEFAULT_USER}" == "root" ]]; then
    echo "Default user is root, abort the operation." >&2
    exit 1
  fi

  if [[ -z "${DEFAULT_USER_PUB_KEY}" ]]; then
    echo "DEFAULT_USER_PUB_KEY can't be empty!" >&2
    exit 1
  fi

  if ! __has-root-privileges; then
    echo "\"prevent-root-login\" don't run in \"sudo or root\" mode, abort the operation."
    exit 1
  fi

  local authroized_keys_content="no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command=\"echo 'Please login as the user \\\"${DEFAULT_USER}\\\" rather than the user \\\"root\\\".';echo;sleep 10;exit 142\" ${DEFAULT_USER_PUB_KEY}"

  mkdir -p "$(dirname ${ROOT_AUTHORIZED_KEYS_FILE})"

  # will override the old ROOT_AUTHORIZED_KEYS_FILE
  echo "${authroized_keys_content}" | sudo tee "${ROOT_AUTHORIZED_KEYS_FILE}" >/dev/null

  chmod 600 "${ROOT_AUTHORIZED_KEYS_FILE}"
  chown root:root "${ROOT_AUTHORIZED_KEYS_FILE}"

  echo "Successfully created "${ROOT_AUTHORIZED_KEYS_FILE}" to guide root login to user '${DEFAULT_USER}'."
}

allow-root-login() {

  # To prevent logging in as the root user using an SSH key while still allowing password-based login. If stricter root login restrictions are required, please use the forbid-root-login function or combine it with the forbid-password-authentication function. In other words, this function is limited in scope and only applies to key-based login scenarios. Its purpose is to guide users who log in with the root account to use a regular user account instead, thereby reducing the security risks associated with frequent use of the root account.

  echo "DEFAULT_USER: ${DEFAULT_USER}"

  if [[ "${DEFAULT_USER}" == "root" ]]; then
    echo "Default user is root, abort the operation." >&2
    exit 1
  fi

  if [[ -z "${DEFAULT_USER_PUB_KEY}" ]]; then
    echo "DEFAULT_USER_PUB_KEY can't be empty!" >&2
    exit 1
  fi

  if ! __has-root-privileges; then
    echo "\"allow-root-login\" don't run in \"sudo or root\" mode, abort the operation."
    exit 1
  fi

  local pub_key_escaped="$(echo ${DEFAULT_USER_PUB_KEY} | sed 's/[\/&]/\\&/g')"

  mkdir -p "$(dirname ${ROOT_AUTHORIZED_KEYS_FILE})"

  if [[ ! -f "${ROOT_AUTHORIZED_KEYS_FILE}" ]]; then
    echo "${ROOT_AUTHORIZED_KEYS_FILE} is not exists, skip the operation."
    return 0
  fi

  sed -i.bak "/${pub_key_escaped}/d" ${ROOT_AUTHORIZED_KEYS_FILE}

  echo "Removed the restriction on root login authentication."
}

update-ssh-config() {
  if [[ -z "${SSH_CONFIG_KEY}" ]]; then
    echo "SSH_CONFIG_KEY param can't be empty!" >&2
    exit 1
  fi

  if [[ -z "${SSH_CONFIG_VAL}" ]]; then
    echo "SSH_CONFIG_VAL param can't be empty!" >&2
    exit 1
  fi

  if ! __has-root-privileges; then
    echo "\"${FUNCNAME[1]}\" don't run in \"sudo or root\" mode, abort the operation."
    exit 1
  fi

  cp "${SSHD_CONFIG_FILE}" "${SSHD_CONFIG_FILE}.bak"

  local ssh_config_match="^${SSH_CONFIG_KEY}[[:space:]]"

  local ssh_config_setting="${SSH_CONFIG_KEY} ${SSH_CONFIG_VAL}"

  if grep -q "${ssh_config_match}" "${SSHD_CONFIG_FILE}"; then
    sed -i "/${ssh_config_match}/s/".*"/${ssh_config_setting}/" "${SSHD_CONFIG_FILE}"
  else
    echo "${ssh_config_setting}" | tee -a "${SSHD_CONFIG_FILE}" >/dev/null
  fi

  if ! grep -q "^${SSH_CONFIG_KEY}[[:space:]]${SSH_CONFIG_VAL}" "${SSHD_CONFIG_FILE}"; then
    echo "Failed to modify ${SSH_CONFIG_KEY}. Please check the configuration file manually." >&2
    exit 1
  fi

  systemctl reload sshd

  echo "SSH configuration updated: ${SSH_CONFIG_KEY} set to ${SSH_CONFIG_VAL}."
}

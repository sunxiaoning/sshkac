KEY_TYPE_RSA="rsa"
KEY_TYPE_ED25519="ed25519"

KEY_TYPE=${KEY_TYPE:-${KEY_TYPE_RSA}}

KEY_BITS_2048="2048"
KEY_BITS_4096="4096"

KEY_BITS=${KEY_BITS:-${KEY_BITS_4096}}

KEY_COMMENT=${KEY_COMMENT:-""}
NEW_PASSPHRASE=${NEW_PASSPHRASE:-""}

ORIGINAL_KEYFINGER=${ORIGINAL_KEYFINGER:-""}

gen-keypair() {
  check-keypair

  mkdir -p "$(dirname ${KEY_FILE})"

  if [[ -f "${KEY_FILE}" ]]; then
    echo "KEY_FILE: ${KEY_FILE} is already exists!" >&2
    return 0
  fi

  if [[ -f "${KEY_FILE}.pub" ]]; then
    echo "[WARNING] Removing the public key file ${KEY_FILE}.pub to avoid conflicts with new key generation."
    rm -f "${KEY_FILE}.pub"
  fi

  ssh-keygen -t "${KEY_TYPE}" -b "${KEY_BITS}" -C "${KEY_COMMENT}" -N "${NEW_PASSPHRASE}" -q -f "${KEY_FILE}"

  echo "Generated key file: ${KEY_FILE}."

  echo "The key fingerprint is: $(ssh-keygen -lf ${KEY_FILE}.pub | awk '{print $2}')"
}

remove-keypair() {
  if [[ ! -f "${KEY_FILE}" ]]; then
    echo "KEY_FILE: ${KEY_FILE} is not exists!" >&2
    return 0
  fi

  rm -f "${KEY_FILE}" "${PUB_KEY_FILE}"

  echo "Removed key file: ${KEY_FILE}"
}

check-keyfinger() {
  if [[ -z "${ORIGINAL_KEYFINGER}" ]]; then
    echo "ORIGINAL_KEYFINGER param can't be emtpy!" >&2
    exit 1
  fi

  check-pub-key-file

  local keyfinger_type=""

  case "${ORIGINAL_KEYFINGER}" in
  SHA256:*)
    keyfinger_type="sha256"
    ;;
  MD5:*)
    keyfinger_type="md5"
    ;;
  *)
    keyfinger_type="sha256"
    ;;
  esac

  local original_keyfinger_content="${ORIGINAL_KEYFINGER#${keyfinger_type^^}:}"
  local real_keyfinger_content=$(ssh-keygen -lf "${PUB_KEY_FILE}" -E "${keyfinger_type}" | awk '{print $2}' | sed "s/^${keyfinger_type^^}://")

  if [[ "${original_keyfinger_content}" != "${real_keyfinger_content}" ]]; then
    echo "Verification failed: The real keyfinger content: ${real_keyfinger_content} does not match the original keyfinger content: ${original_keyfinger_content}." >&2
    exit 1
  fi

  echo "Verification passed: The real keyfinger content matches the original keyfinger content."
}

check-keypair() {
  case "${KEY_TYPE}" in
  "${KEY_TYPE_RSA}") ;;
  "${KEY_TYPE_ED25519}") ;;
  *)
    echo "KEY_TYPE: ${KEY_TYPE} param is invalid!" >&2
    exit 1
    ;;
  esac

  if [[ "${KEY_BITS}" != "${KEY_BITS_2048}" && "${KEY_BITS}" != "${KEY_BITS_4096}" ]]; then
    echo "KEY_BITS: ${KEY_BITS} param is invalid!" >&2
    exit 1
  fi

  if [[ -z "${KEY_COMMENT}" ]]; then
    echo "KEY_COMMENT param can't be empty!" >&2
    exit 1
  fi
}

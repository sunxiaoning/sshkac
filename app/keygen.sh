KEY_TYPE_RSA="rsa"
KEY_TYPE_ED25519="ed25519"

KEY_TYPE=${KEY_TYPE:-${KEY_TYPE_RSA}}

KEY_BITS_2048="2048"
KEY_BITS_4096="4096"

KEY_BITS=${KEY_BITS:-${KEY_BITS_4096}}

KEY_COMMENT=${KEY_COMMENT:-""}
NEW_PASSPHRASE=${NEW_PASSPHRASE:-""}

ORIGINAL_KEYFINGER=${ORIGINAL_KEYFINGER:-""}

PAT=${PAT:-""}
REPO_ORIGIN_SOURCE=${REPO_ORIGIN_SOURCE:-"0"}
OPS_KEY_REPO_URL=${OPS_KEY_REPO_URL:-""}

OPS_KEY_FILE=${OPS_KEY_FILE:-"id_rsa"}
OPS_PUB_KEY_FILE=${OPS_PUB_KEY_FILE:-"id_rsa.pub"}

gen-keypair() {
  check-keypair

  check-default-user-mode

  mkdir -p "$(dirname ${KEY_FILE})"
  chmod 700 "$(dirname ${KEY_FILE})"

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

# Only do this operation on hosts in trust
import-keypair() {
  if [[ -z "${PAT}" ]]; then
    echo "PAT param can't be empty!" >&2
    exit 1
  fi

  if [[ -z "${OPS_KEY_REPO_URL}" ]]; then
    echo "OPS_KEY_REPO_URL param can't be empty!" >&2
    exit 1
  fi

  check-default-user-mode

  echo "Use REPO_ORIGIN_SOURCE: ${REPO_ORIGIN_SOURCE}"

  # TODO deal with half-success status. override ?? or cleanup by hand ??

  if [[ -f "${KEY_FILE}" ]]; then
    echo "KEY_FILE: ${KEY_FILE} is already exists!" >&2
    return 0
  fi

  if [[ -f "${PUB_KEY_FILE}" ]]; then
    echo "PUB_KEY_FILE: ${PUB_KEY_FILE} is already exists!" >&2
    return 0
  fi

  if ! rpm -q "jq" &>/dev/null; then
    sudo yum -y install jq
  fi

  local key_file_url="${OPS_KEY_REPO_URL}/${OPS_KEY_FILE}"

  if [[ "${REPO_ORIGIN_SOURCE}" == "1" ]]; then
    key_file_url="${key_file_url}?ref=main"
  fi

  if [[ "${REPO_ORIGIN_SOURCE}" == "1" ]]; then
    curl -fsSL -H "Authorization: token ${PAT}" "${key_file_url}" | jq -r '.content' | base64 --decode >"${WORKDIR}/${OPS_KEY_FILE}" &
  else
    curl -fsSLo "${WORKDIR}/${OPS_KEY_FILE}" -H "Authorization: token ${PAT}" "${key_file_url}" &
  fi

  wait $!

  cp "${WORKDIR}/${OPS_KEY_FILE}" "${KEY_FILE}"
  chmod 700 "${KEY_FILE}"

  echo "Imported key file: ${KEY_FILE}"

  local pub_key_file_url="${OPS_KEY_REPO_URL}/${OPS_PUB_KEY_FILE}"

  if [[ "${REPO_ORIGIN_SOURCE}" == "1" ]]; then
    pub_key_file_url="${pub_key_file_url}?ref=main"
  fi

  if [[ "${REPO_ORIGIN_SOURCE}" == "1" ]]; then
    curl -fsSL -H "Authorization: token ${PAT}" "${pub_key_file_url}" | jq -r '.content' | base64 --decode >"${WORKDIR}/${OPS_PUB_KEY_FILE}" &
  else
    curl -fsSLo "${WORKDIR}/${OPS_PUB_KEY_FILE}" -H "Authorization: token ${PAT}" "${pub_key_file_url}" &
  fi

  wait $!

  cp "${WORKDIR}/${OPS_PUB_KEY_FILE}" "${PUB_KEY_FILE}"
  chmod 700 "${PUB_KEY_FILE}"

  echo "Imported key file: ${PUB_KEY_FILE}"
}

remove-keypair() {
  if [[ ! -f "${KEY_FILE}" ]]; then
    echo "KEY_FILE: ${KEY_FILE} is not exists!" >&2
    return 0
  fi

  check-default-user-mode

  rm -f "${KEY_FILE}" "${PUB_KEY_FILE}"

  echo "Removed key file: ${KEY_FILE}"
}

check-keyfinger() {
  if [[ -z "${ORIGINAL_KEYFINGER}" ]]; then
    echo "ORIGINAL_KEYFINGER param can't be emtpy!" >&2
    exit 1
  fi

  check-pub-key-file

  check-default-user-mode

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

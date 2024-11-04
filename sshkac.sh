#!/bin/bash

CONTEXT_DIR=$(dirname "$(realpath "${BASH_SOURCE}")")
SCRIPT_NAME=$(basename "$0")

. ${CONTEXT_DIR}/bashutils/basicenv.sh

. ${CONTEXT_DIR}/app/env.sh
. ${CONTEXT_DIR}/app/keygen.sh
. ${CONTEXT_DIR}/app/auth.sh

trap __terminate INT TERM
trap __cleanup EXIT

TEMP_FILES=()

main() {
  ACTION="${1-}"
  case "${ACTION}" in
  gen-keypair)
    gen-keypair
    ;;
  remove-keypair)
    remove-keypair
    ;;
  check-keyfinger)
    check-keyfinger
    ;;
  trust-target-hosts)
    trust-target-hosts
    ;;
  untrust-target-hosts)
    untrust-target-hosts
    ;;
  auth-target-hosts)
    auth-target-hosts
    ;;
  revoke-target-hosts)
    revoke-target-hosts
    ;;
  revoke-source-keys)
    revoke-source-keys
    ;;
  *)
    echo "The action: ${1-} is not supported!"
    exit 1
    ;;
  esac
}

terminate() {
  echo "terminating..."
}

cleanup() {
  if [[ "${#TEMP_FILES[@]}" -gt 0 ]]; then
    echo "Cleaning temp_files...."

    for temp_file in "${TEMP_FILES[@]}"; do
      rm -f "${temp_file}" || true
    done
  fi

  echo "Start cleanup action: ${ACTION} ..."

  case "${ACTION}" in
  autosetup)
    clean-autosetup
    ;;
  *)
    echo "The action: ${1-} cleanup is empty, skip the operation."
    ;;
  esac
}

main "$@"

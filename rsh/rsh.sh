#!/bin/bash

PID_FILE=${PID_FILE:-""}

if [[ -z "${PID_FILE}" ]]; then
  exit "${PID_FILE} can't be empty!" >&2
  exit 1
fi

echo "$$" >${PID_FILE}

PID_RES_FILE=${PID_RES_FILE:-""}

CONTEXT_DIR=$(dirname "$(realpath "${BASH_SOURCE}")")
SCRIPT_NAME=$(basename "$0")

. ${CONTEXT_DIR}/basicenv.sh

. ${CONTEXT_DIR}/app/env.sh

. ${CONTEXT_DIR}/app/sec.sh

trap __terminate INT TERM
trap __cleanup EXIT

TEMP_FILES=()

main() {
  ACTION="${1-}"
  case "${ACTION}" in
  forbid-password-authentication)
    forbid-password-authentication
    ;;
  permit-password-authentication)
    permit-password-authentication
    ;;
  prevent-root-login)
    prevent-root-login
    ;;
  allow-root-login)
    allow-root-login
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

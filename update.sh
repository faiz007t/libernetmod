#!/bin/bash

# Libernet Mod Updater
# v1.5.4

HOME="/root"
DOWNLOADS_DIR="${HOME}/Downloads"
LIBERNET_TMP="${DOWNLOADS_DIR}/libernetmod"
REPOSITORY_URL="git://github.com/faiz007t/libernetmod.git"

function update_libernet() {
  if [[ ! -d "${LIBERNET_TMP}" ]]; then
    echo -e "There's no Libernet installer on ~/Downloads directory, please clone it first!"
    exit 1
  fi
  # change working dir to Libernet Mod installer
  cd "${LIBERNET_TMP}"
  # verify Libernet Mod installer
  if git branch > /dev/null 2>&1; then
    update_libernet_cli
  else
    echo -e "This is not Libernet Mod installer directory, please use installer directory to update Libernet Mod !"
    exit 1
  fi
}

function update_libernet_cli() {
  echo -e "Updating Libernet ..." \
    && git fetch origin main \
    && git reset --hard FETCH_HEAD \
    && bash install.sh \
    && echo -e "\nLibernet successfully updated!"
}

function update_libernet_web() {
  # create downloads directory if not exist
  if [[ ! -d "${DOWNLOADS_DIR}" ]]; then
    mkdir -p "${DOWNLOADS_DIR}"
  fi
  # update Libernet
  "${LIBERNET_DIR}/bin/log.sh" -u 1
  if [[ -d "${LIBERNET_TMP}" ]]; then
    update_libernet
  else
    git clone --depth 1 "${REPOSITORY_URL}" "${LIBERNET_TMP}" \
      && cd "${LIBERNET_TMP}" \
      && bash install.sh \
      && echo -e "\nLibernet successfully updated!"
  fi
  "${LIBERNET_DIR}/bin/log.sh" -u 2
}

case $1 in
  -web)
    update_libernet_web || "${LIBERNET_DIR}/bin/log.sh" -u 3
    ;;
  *)
    update_libernet
    ;;
esac

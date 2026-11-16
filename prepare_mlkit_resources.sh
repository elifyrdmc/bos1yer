#!/bin/bash
# Fetch the ML Kit model bundles missing from the SwiftPM binary frameworks.
# Xcode runs this before packaging Runner.app; end users need no setup.
set -euo pipefail

: "${TARGET_BUILD_DIR:?Xcode must set TARGET_BUILD_DIR}"
: "${UNLOCALIZED_RESOURCES_FOLDER_PATH:?Xcode must set the app resource path}"
: "${DERIVED_FILE_DIR:?Xcode must set DERIVED_FILE_DIR}"

readonly VERSION="9.0.2"
readonly BASE_URL="https://github.com/d-date/google-mlkit-swiftpm/releases/download/${VERSION}"
readonly CACHE_DIR="${DERIVED_FILE_DIR}/mlkit-resource-bundles-${VERSION}"
readonly APP_RESOURCES="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"

mkdir -p "${CACHE_DIR}" "${APP_RESOURCES}"

download_bundle() {
  local name="$1"
  local expected_sha="$2"
  local cached="${CACHE_DIR}/${name}"
  local archive tmp actual_sha

  if [[ -d "${cached}" ]]; then
    return
  fi

  tmp="$(mktemp -d "${CACHE_DIR}/download.XXXXXX")"
  archive="${tmp}/${name}.zip"

  echo "Downloading required ML Kit resource bundle: ${name}"
  if ! curl --fail --location --retry 3 --silent --show-error \
    "${BASE_URL}/${name}.zip" --output "${archive}"; then
    rm -rf "${tmp}"
    echo "error: Could not download required ML Kit resource bundle ${name}." >&2
    return 1
  fi
  actual_sha="$(shasum -a 256 "${archive}" | awk '{print $1}')"
  if [[ "${actual_sha}" != "${expected_sha}" ]]; then
    echo "error: SHA-256 mismatch for ${name}; refusing to package an unverified model." >&2
    rm -rf "${tmp}"
    exit 1
  fi

  if ! unzip -q "${archive}" -d "${tmp}"; then
    rm -rf "${tmp}"
    echo "error: Could not unpack required ML Kit resource bundle ${name}." >&2
    return 1
  fi
  if [[ ! -d "${tmp}/${name}" ]]; then
    echo "error: Expected ${name} was not present in the downloaded archive." >&2
    rm -rf "${tmp}"
    exit 1
  fi
  ditto "${tmp}/${name}" "${cached}"
  rm -rf "${tmp}"
}

download_bundle "GoogleMVFaceDetectorResources.bundle" "a81acdd21b76228981f6332b0e7f2166e297528d756fb0099d98930d58eb51c3"
download_bundle "LatinOCRResources.bundle" "c790283599f67708c06fd93de61d96823ce2ad984ad00bfda5922afda0861758"

ditto "${CACHE_DIR}/GoogleMVFaceDetectorResources.bundle" "${APP_RESOURCES}/GoogleMVFaceDetectorResources.bundle"
ditto "${CACHE_DIR}/LatinOCRResources.bundle" "${APP_RESOURCES}/LatinOCRResources.bundle"

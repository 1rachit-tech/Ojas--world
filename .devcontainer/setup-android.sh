#!/usr/bin/env bash

set -euo pipefail

android_home="/home/codespace/android-sdk"
cmdline_tools_version="13114758"
cmdline_tools_archive="/tmp/commandlinetools-linux-${cmdline_tools_version}.zip"
cmdline_tools_url="https://dl.google.com/android/repository/commandlinetools-linux-${cmdline_tools_version}_latest.zip"

mkdir -p "${android_home}/cmdline-tools"

if [[ ! -x "${android_home}/cmdline-tools/latest/bin/sdkmanager" ]]; then
    curl --fail --location --retry 3 "${cmdline_tools_url}" --output "${cmdline_tools_archive}"
    rm -rf "${android_home}/cmdline-tools/latest" "${android_home}/cmdline-tools/cmdline-tools"
    unzip -q "${cmdline_tools_archive}" -d "${android_home}/cmdline-tools"
    mv "${android_home}/cmdline-tools/cmdline-tools" "${android_home}/cmdline-tools/latest"
    rm -f "${cmdline_tools_archive}"
fi

export ANDROID_HOME="${android_home}"
export ANDROID_SDK_ROOT="${android_home}"
export PATH="${android_home}/platform-tools:${android_home}/cmdline-tools/latest/bin:${PATH}"

yes | sdkmanager --sdk_root="${android_home}" --licenses >/dev/null
sdkmanager --sdk_root="${android_home}" "platform-tools" "platforms;android-36" "build-tools;36.0.0"
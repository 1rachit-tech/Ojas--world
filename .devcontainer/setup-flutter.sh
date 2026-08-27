#!/usr/bin/env bash

set -euo pipefail

flutter_home="/home/codespace/flutter"
bashrc_file="${HOME}/.bashrc"

if [[ ! -x "${flutter_home}/bin/flutter" ]]; then
    rm -rf "${flutter_home}"
    git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "${flutter_home}"
fi

path_line='export PATH="/home/codespace/flutter/bin:$PATH"'
if ! grep -Fqx "${path_line}" "${bashrc_file}" 2>/dev/null; then
    printf '\n# Flutter SDK\nif [[ -d "/home/codespace/flutter/bin" ]]; then\n    %s\nfi\n' "${path_line}" >> "${bashrc_file}"
fi

export PATH="${flutter_home}/bin:${PATH}"
flutter --version
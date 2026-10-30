#!/usr/bin/env bash
set -e
base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
export ASSISTENTE_PLATFORM=Linux
exec bash "$base_dir/ASSISTENTE-IA-MAC.command" "$@"

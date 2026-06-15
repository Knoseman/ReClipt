#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "Validating shell scripts..."

for script in "$ROOT_DIR"/scripts/*.sh; do
  if [[ ! -x "$script" ]]; then
    echo "Script is not executable: $script" >&2
    exit 1
  fi

  zsh -n "$script"
done

echo "Shell script validation succeeded."

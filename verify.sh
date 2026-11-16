#!/usr/bin/env bash
# Run the same code checks locally and in GitHub Actions.
set -euo pipefail

cd "$(dirname "$0")/.."
flutter pub get
dart analyze lib test
flutter test --no-pub

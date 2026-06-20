#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
BUILD="$HERE/.build"
mkdir -p "$BUILD"

SCORER_SWIFT="$ROOT/divedave-ios/divedave Shared/Components/Scene/DiveScorer.swift"
CONSTANTS_SWIFT="$ROOT/divedave-ios/divedave Shared/Util/Constants.swift"
SWIFT_BIN="$BUILD/parity-test-swift"

if [ ! -f "$SWIFT_BIN" ] \
   || [ "$SCORER_SWIFT" -nt "$SWIFT_BIN" ] \
   || [ "$CONSTANTS_SWIFT" -nt "$SWIFT_BIN" ] \
   || [ "$HERE/parity-test.swift" -nt "$SWIFT_BIN" ]
then
    swiftc "$SCORER_SWIFT" "$CONSTANTS_SWIFT" "$HERE/parity-test.swift" -o "$SWIFT_BIN"
fi

node "$HERE/parity-test.mjs"
"$SWIFT_BIN" "$HERE/parity-fixtures.json"

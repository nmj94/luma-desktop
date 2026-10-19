#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"
mkdir -p build/module-cache build/test-artifacts
swiftc -swift-version 5 -module-cache-path "$PROJECT_ROOT/build/module-cache" Sources/Localization.swift Sources/Models.swift Tests/ModelChecks.swift -o build/model-checks
build/model-checks
ffmpeg -hide_banner -loglevel error -y -f lavfi -i 'testsrc2=size=640x360:rate=24' -t 1.2 -an -c:v libx264 -pix_fmt yuv420p build/test-artifacts/sample.mp4
LUMA_TEST_ROOT="$(mktemp -d "$PROJECT_ROOT/build/test-state.XXXXXX")" \
LUMA_ARTIFACT_ROOT="$PROJECT_ROOT/build/test-artifacts" \
LUMA_TEST_VIDEO="$PROJECT_ROOT/build/test-artifacts/sample.mp4" \
    "$PROJECT_ROOT/dist/流光桌面.app/Contents/MacOS/LumaDesktop" --self-test
python3 -c 'import json; r=json.load(open("build/test-artifacts/integration-report.json")); assert r["passed"], "Integration checks failed"; print(str(len(r["checks"])) + " integration checks passed")'

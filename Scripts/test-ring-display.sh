#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
swift "$REPO_ROOT/Tests/RingDisplayChecks.swift"

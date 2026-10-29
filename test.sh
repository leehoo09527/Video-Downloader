#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(pwd -P)"
mkdir -p "$ROOT/.build/test-module-cache"
swiftc -module-cache-path "$ROOT/.build/test-module-cache" Source/Queue.swift tests/main.swift -o .build/queue-tests
.build/queue-tests
/opt/homebrew/bin/python3 -c "import ast,pathlib; ast.parse(pathlib.Path('Resources/download.py').read_text()); print('PASS: Python syntax')"

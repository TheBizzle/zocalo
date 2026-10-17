#! /usr/bin/env bash

set -euo pipefail

(cd frontend/ && npm run build)

stack build

killall run-zocalo || true

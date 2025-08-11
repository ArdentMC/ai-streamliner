#!/bin/bash
set -e

# Always run extract-artifacts.sh, using /output as default
exec /app/scripts/extract-artifacts.sh "${1:-/output}"
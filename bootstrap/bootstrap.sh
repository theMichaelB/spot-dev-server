#!/bin/bash
set -euo pipefail

SCRIPTS_DIR="/opt/bootstrap/scripts"

echo "=== Starting bootstrap ==="

for script in "$SCRIPTS_DIR"/*.sh; do
    if [ -x "$script" ]; then
        echo ">>> Running: $(basename "$script")"
        "$script"
        echo "<<< Completed: $(basename "$script")"
    fi
done

echo "=== Bootstrap complete ==="

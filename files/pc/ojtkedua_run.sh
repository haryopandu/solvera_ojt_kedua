# Letakkan di ~/home/haryo

#!/usr/bin/env bash
set -euo pipefail
# Ensure ~/bin is on PATH even in non-interactive shells
export PATH="$HOME/bin:$PATH"
# Hand off to the real launcher (accepts extra args, e.g., ODOO_HTTP_PORT=8071)
exec ojtgo "$@"

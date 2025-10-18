# Letakkan di ~/home/haryo, lalu jalankan melalui Powershell menggunakan perintah wsl -d Ubuntu-24.04 bash -lc '~/ojtkedua_run.sh'

#!/usr/bin/env bash
set -euo pipefail

# =========================
#  Variabel lingkungan (WSL)
# =========================
USER_HOME="/home/haryo"                   # ganti jika perlu
VENV_DIR="$USER_HOME/.venvs/odoo18"       # venv Python 3.12 utk Odoo 18
WORK_DIR="$USER_HOME/work"
ODOO_DIR="$WORK_DIR/odoo18"               # lokasi Odoo 18
CUSTOM_ADDONS="$USER_HOME/custom_addons"  # direktori addon kustom
DB_NAME="odoo18"                          # nama database
MODULE_TO_UPDATE="solvera_ojt_kedua"      # modul target

# Interpreter & pip di venv (hard-pin agar tak pakai Python Windows)
PY="$VENV_DIR/bin/python"
PIP="$VENV_DIR/bin/pip"

# =========================
#  Pastikan PostgreSQL 17 hidup
# =========================
if command -v pg_lsclusters >/dev/null 2>&1; then
  if ! pg_lsclusters | awk '{print $1" "$2" "$4}' | grep -qE '^17 main online$'; then
    sudo pg_createcluster 17 main --start 2>/dev/null || sudo pg_ctlcluster 17 main start || true
  fi
fi
if command -v pg_isready >/dev/null 2>&1; then
  if ! pg_isready -q; then
    sudo systemctl start postgresql 2>/dev/null || \
    sudo service postgresql start 2>/dev/null || \
    sudo pg_ctlcluster 17 main start || true
  fi
fi

# =========================
#  Validasi venv
# =========================
# (ID) Cegah salah interpreter (mis. Python Windows)
if [ ! -x "$PY" ]; then
  echo "Venv tidak ditemukan di $VENV_DIR (tidak ada $PY). Buat venv Python 3.12 dulu."
  exit 1
fi
"$PY" -c 'import sys; print("Using:", sys.executable)'

# =========================
#  Odoo core update + deps
# =========================
if [ -d "$ODOO_DIR/.git" ]; then
  cd "$ODOO_DIR"
  git fetch --all --tags
  git switch 18.0 2>/dev/null || git checkout -B 18.0 origin/18.0
  git pull --ff-only

  # (ID) Install deps Odoo ke dalam venv
  "$PY" -m pip install -U pip setuptools wheel
  if [ -f "requirements.txt" ]; then
    "$PIP" install -r requirements.txt
  fi

  # (ID) Tambahan: pastikan Babel & pdfminer.six terpasang
  #     Catatan: Odoo 18 umumnya butuh Babel>=2.6; pakai versi 2.x aman.
  if ! "$PIP" show Babel >/dev/null 2>&1; then
    "$PIP" install "Babel>=2.6.0"
  fi
  if ! "$PIP" show pdfminer.six >/dev/null 2>&1; then
    "$PIP" install "pdfminer.six"
  fi

  # (ID) Health check: pastikan modul bisa di-import dari interpreter venv
  "$PY" -c 'import babel, sys; print("Babel OK:", getattr(babel,"__version__","unknown"), "from", sys.executable)'
  "$PY" -c 'import pdfminer, sys; print("pdfminer OK:", getattr(pdfminer,"__version__","unknown"), "from", sys.executable)'
else
  echo "Repo Odoo tidak ditemukan di $ODOO_DIR (tidak ada .git)."
  exit 1
fi

# =========================
#  Siapkan addons path
# =========================
# (ID) Buat custom_addons jika belum ada
sudo mkdir -p "$CUSTOM_ADDONS"
sudo chown -R "$(id -u -n)":"$(id -g -n)" "$CUSTOM_ADDONS"

# (ID) Jika modul ada di lokasi lain, auto-locate dan set parent-nya sbg addons dir
if [ ! -d "$CUSTOM_ADDONS/$MODULE_TO_UPDATE" ]; then
  FOUND_MOD_DIR="$(find "$USER_HOME" -maxdepth 6 -type d -name "$MODULE_TO_UPDATE" 2>/dev/null | head -n1 || true)"
  if [ -n "${FOUND_MOD_DIR:-}" ]; then
    ADDONS_CUSTOM="$(dirname "$FOUND_MOD_DIR")"
  else
    ADDONS_CUSTOM="$CUSTOM_ADDONS"
  fi
else
  ADDONS_CUSTOM="$CUSTOM_ADDONS"
fi

ODOO_BIN="$ODOO_DIR/odoo-bin"
[ -x "$ODOO_BIN" ] || ODOO_BIN="$ODOO_DIR/odoo/odoo-bin"
[ -x "$ODOO_BIN" ] || { echo "Tidak menemukan odoo-bin yang bisa dieksekusi."; exit 1; }

ADDONS_CORE="$(dirname "$ODOO_BIN")/addons"

echo "==> PYTHON        : $PY"
echo "==> ODOO_BIN      : $ODOO_BIN"
echo "==> ADDONS_CORE   : $ADDONS_CORE"
echo "==> ADDONS_CUSTOM : $ADDONS_CUSTOM"
echo "==> MODULE        : $MODULE_TO_UPDATE"

# =========================
#  Pastikan DB ada (opsional non-destruktif)
# =========================
if command -v psql >/dev/null 2>&1; then
  if ! psql -Atqc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" postgres >/dev/null 2>&1; then
    createdb "${DB_NAME}" || true
  fi
fi

# =========================
#  Tentukan aksi install/upgrade modul
# =========================
# (ID) Cek apakah modul sudah terpasang di DB; jika belum → pakai -i, jika sudah → pakai -u
ACTION="-i"  # default: install
if command -v psql >/dev/null 2>&1; then
  MOD_STATE="$(psql -Atqc "SELECT state FROM ir_module_module WHERE name='${MODULE_TO_UPDATE}'" "${DB_NAME}" 2>/dev/null | head -n1 | tr -d '[:space:]' || true)"
  case "${MOD_STATE}" in
    installed|to\ upgrade|to\ remove|to\ install)
      ACTION="-u"
      ;;
  esac
fi

echo "==> MODULE STATE   : ${MOD_STATE:-unknown}  → ACTION ${ACTION}"

# (ID) Terapkan install/upgrade modul sesuai ACTION lalu berhenti
"$PY" "$ODOO_BIN" \
  -c "$USER_HOME/.odoo/odoo.conf" \
  --addons-path="$ADDONS_CORE,$ADDONS_CUSTOM" \
  -d "$DB_NAME" ${ACTION} "$MODULE_TO_UPDATE" \
  --stop-after-init

# (ID) Lanjut run dev server
exec "$PY" "$ODOO_BIN" \
  -c "$USER_HOME/.odoo/odoo.conf" \
  --addons-path="$ADDONS_CORE,$ADDONS_CUSTOM" \
  -d "$DB_NAME" \
  --dev=reload

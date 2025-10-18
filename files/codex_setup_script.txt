Di bawah ini adalah setup script idempotent yang disarankan oleh ChatGPT untuk variabel lingkungan (environment variables) Codex OpenAI setelah mempertimbangkan saran dari Codex. Script ini kompatibel dengan Odoo 18, PostgreSQL 17, dan Python 3.12.12 yang diinstal di WSL

#!/usr/bin/env bash
set -euo pipefail

# =========================
#  Variabel (bisa dioverride lewat ENV)
# =========================
USER_HOME="${USER_HOME:-/home/codex}"          # ganti ke /home/haryo bila dipakai di WSL
VENV_DIR="${VENV_DIR:-$USER_HOME/.venvs/odoo18}"
WORK_DIR="${WORK_DIR:-$USER_HOME/work}"        # untuk menaruh Odoo core
ODOO_DIR="${ODOO_DIR:-$WORK_DIR/odoo}"         # lokasi clone Odoo 18
CUSTOM_ADDONS="${CUSTOM_ADDONS:-$USER_HOME/custom_addons}"  # lokasi addon kustom
DB_NAME="${ODOO_DB_NAME:-odoo18}"

# =========================
#  Prasyarat & utilitas
# =========================
export DEBIAN_FRONTEND=noninteractive
mkdir -p "$USER_HOME/.cache/pip" "$USER_HOME/.cache/npm" "$USER_HOME/.odoo" "$WORK_DIR" "$CUSTOM_ADDONS" "$(dirname "$VENV_DIR")"
chown -R "$(id -u)":"$(id -g)" "$USER_HOME/.cache" "$USER_HOME/.odoo" || true

# -------------------------
#  System packages untuk Odoo 18
# -------------------------
apt-get update -y
apt-get install -y --no-install-recommends \
  git build-essential curl ca-certificates gnupg pkg-config \
  python3-dev python3-venv python3-pip python3-setuptools python3-wheel \
  libpq-dev \
  libxml2-dev libxslt1-dev libjpeg-dev libpng-dev zlib1g-dev \
  libldap2-dev libsasl2-dev libffi-dev libssl-dev \
  fonts-dejavu-core xfonts-75dpi xfonts-base \
  wkhtmltopdf

# (Opsional) Node.js bila perlu untuk asset bundling:
# curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt-get install -y nodejs

# -------------------------
#  Python venv (sesuai saran Codex) + deps
# -------------------------
# ID: buat dan aktifkan venv 3.10+ (di sini 3.12 dari base image/host)
if [ ! -d "$VENV_DIR" ]; then
  python3 -m venv "$VENV_DIR"
fi
# shellcheck disable=SC1090
source "$VENV_DIR/bin/activate"

python -m pip install --upgrade pip
# ID: install requirements proyek bila ada
if [ -f "requirements.txt" ]; then
  python -m pip install -r requirements.txt
fi
# ID: tambah deps umum Odoo 18 (hindari duplikasi dengan requirements.txt di atas)
python - <<'PY'
import sys, subprocess
pkgs = [
  "psycopg2==2.9.9",
  "werkzeug",
  "num2words",
  "passlib",
  "babel",
  "lxml",
  "pillow",
  "reportlab",
]
subprocess.check_call([sys.executable, "-m", "pip", "install", *pkgs])
PY

# -------------------------
#  (Opsional) PostgreSQL lokal 17
#  Catatan: kalau Anda pakai DB terkelola (Neon/Supabase/RDS), lewati bagian ini.
# -------------------------
if ! command -v psql >/dev/null 2>&1; then
  # ID: Tambah repo PGDG dan install PG 17
  install -d /usr/share/postgresql-common/pgdg
  sh -c 'echo "deb [arch=amd64,arm64] http://apt.postgresql.org/pub/repos/apt $(. /etc/os-release && echo $VERSION_CODENAME)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
  curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/pgdg.gpg
  apt-get update -y
  apt-get install -y postgresql-17 postgresql-client-17
fi

# ID: Inisialisasi cluster PG lokal (folder di $USER_HOME/pgdata agar aman)
if [ ! -d "$USER_HOME/pgdata" ]; then
  su -s /bin/bash -c "/usr/lib/postgresql/17/bin/initdb -D $USER_HOME/pgdata" postgres
fi
# ID: Jalankan PG (port default 5432); abaikan error jika sudah jalan
su -s /bin/bash -c "/usr/lib/postgresql/17/bin/pg_ctl -D $USER_HOME/pgdata -l $USER_HOME/pg.log -o '-p 5432' start" postgres || true

# ID: Buat role & database bila belum ada (aman dipanggil berulang)
psql -U postgres -h 127.0.0.1 -p 5432 -tc "SELECT 1 FROM pg_roles WHERE rolname = 'odoo'" | grep -q 1 || \
  psql -U postgres -h 127.0.0.1 -p 5432 -c "CREATE USER odoo WITH PASSWORD 'odoo' CREATEDB;"
psql -U postgres -h 127.0.0.1 -p 5432 -tc "SELECT 1 FROM pg_database WHERE datname = '${DB_NAME}'" | grep -q 1 || \
  psql -U postgres -h 127.0.0.1 -p 5432 -c "CREATE DATABASE ${DB_NAME} OWNER odoo;"

# -------------------------
#  Odoo core (sesuai saran Codex: clone ke ~/work/odoo)
#  - Tetap kompatibel dengan layout odoo/odoo/odoo-bin vs odoo/odoo-bin
# -------------------------
if [ ! -d "$ODOO_DIR" ]; then
  mkdir -p "$WORK_DIR"
  git clone --depth 1 --branch 18.0 https://github.com/odoo/odoo.git "$ODOO_DIR"
fi

# Tentukan lokasi addons core & odoo-bin secara dinamis
if [ -d "$ODOO_DIR/odoo/addons" ]; then
  CORE_ADDONS="$ODOO_DIR/odoo/addons"
  ODOO_BIN="$ODOO_DIR/odoo/odoo-bin"
else
  CORE_ADDONS="$ODOO_DIR/addons"
  ODOO_BIN="$ODOO_DIR/odoo-bin"
fi

# -------------------------
#  Tulis ~/.odoo/odoo.conf dari Secrets (atau fallback lokal)
#  Catatan: di Codex, Secrets hanya tersedia saat setup; jangan echo nilainya.
# -------------------------
DB_URI="${POSTGRES_URI:-postgresql://odoo:odoo@127.0.0.1:5432/${DB_NAME}}"
mkdir -p "$USER_HOME/.odoo"
cat > "$USER_HOME/.odoo/odoo.conf" <<EOF
[options]
db_uri = ${DB_URI}
# addons-path: core + custom_addons + direktori repo saat ini (agar modul di repo ikut terbaca)
addons_path = ${CORE_ADDONS},${CUSTOM_ADDONS},$(pwd)
admin_passwd = ${ODOO_ADMIN_PASSWORD:-admin}
# SMTP (opsional)
smtp_server = ${SMTP_HOST:-}
smtp_port = ${SMTP_PORT:-}
smtp_ssl = ${SMTP_SSL:-False}
smtp_user = ${SMTP_USER:-}
smtp_password = ${SMTP_PASSWORD:-}
EOF
chmod 600 "$USER_HOME/.odoo/odoo.conf"

# -------------------------
#  Sanity check & output ringkas
# -------------------------
echo "[OK] Environment ready for Odoo 18."
python --version
wkhtmltopdf --version || true
psql --version || true

# Cetak petunjuk run (aman untuk copy-paste di task agent)
cat <<EOM

# =========================
#  Cara pakai (copy-paste)
# =========================
# Update modul Anda saja lalu berhenti (build / load tanpa server jalan terus):
${ODOO_BIN} -c $USER_HOME/.odoo/odoo.conf -d "${DB_NAME}" -u solvera_ojt_core --stop-after-init

# Mode dev dengan auto-reload:
${ODOO_BIN} -c $USER_HOME/.odoo/odoo.conf -d "${DB_NAME}" --dev=reload

# Catatan:
# - PYTHON venv aktif otomatis hanya dalam script ini. Di langkah agent berikutnya,
#   aktifkan lagi jika perlu: source "$VENV_DIR/bin/activate"
# - Tambahkan modul kustom Anda ke ${CUSTOM_ADDONS} ATAU letakkan di repo ini (sudah di-add ke addons_path).
EOM

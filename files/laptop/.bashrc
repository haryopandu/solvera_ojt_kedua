# Jalankan dengan perintah wsl -d Ubuntu-24.04 lalu ojtgo di PowerShell
# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
# --- OJT (BEGIN) ---
# Path inti & venv (WSL)
export OJT_ODOO_DIR="/home/haryo/work/odoo"        # ID: lokasi source Odoo
export OJT_DB="odoo18"                              # ID: nama database dev
export OJT_VENV="/home/haryo/.venvs/odoo18/bin/activate"  # ID: venv Python Odoo

# (Opsional) Hanya aktifkan jika Anda butuh `import odoo` dari skrip di luar odoo-bin:
# export PYTHONPATH="$HOME/work/odoo"

# Catatan: Jangan set ADDONS_PATH di sini.
#          addons_path sudah didefinisikan di ~/.odoo/odoo.conf dan itu yang dipakai odoo-bin.
# --- OJT (END) ---

# pyenv init
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# --- Odoo (WSL laptop) ---
export PYTHONUNBUFFERED=1
export PIP_DISABLE_PIP_VERSION_CHECK=1
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export NODE_OPTIONS="--max_old_space_size=4096"

# Odoo config paths (dipakai odoo & skrip kita)
export ODOO_RC="/home/haryo/.odoo/odoo.conf"
export ODOO_CONF="/home/haryo/.odoo/odoo.conf"

# ====== OJT helpers (portable across laptop & PC) ======

# (ID) Aktifkan venv Odoo 18 dengan cepat
alias vodo='source /home/haryo/.venvs/odoo18/bin/activate'

# (ID) Deteksi Odoo core: prefer /work/odoo (laptop), fallback /work/odoo (PC)
_ojt_detect_odoo_dir() {
  for d in /home/haryo/work/odoo /home/haryo/work/odoo; do
    [ -x "$d/odoo-bin" ] && { printf "%s" "$d"; return 0; }
  done
  return 1
}

# (ID) Jalankan Odoo 18 dengan auto-reload + addons path dinamis (tidak tergantung mesin)
odoo18dev() {
  # aktifkan venv
  source /home/haryo/.venvs/odoo18/bin/activate || { echo "Venv Odoo 18 belum ada"; return 1; }

  # deteksi Odoo core
  local ODOO_DIR; ODOO_DIR="$(_ojt_detect_odoo_dir)" || { echo "Tidak menemukan odoo-bin"; return 1; }

  # rakit addons path dari path yg ada
  local ADDONS=()
  [ -d "$ODOO_DIR/odoo/addons" ] && ADDONS+=("$ODOO_DIR/odoo/addons")
  [ -d "$ODOO_DIR/addons" ]      && ADDONS+=("$ODOO_DIR/addons")
  [ -d "/home/haryo/custom_addons" ] && ADDONS+=("/home/haryo/custom_addons")
  local ADDONS_PATH; ADDONS_PATH="$(IFS=, ; echo "${ADDONS[*]}")"

  # jalankan server
  "$ODOO_DIR/odoo-bin" -c ~/.odoo/odoo.conf --addons-path="$ADDONS_PATH" -d odoo18 --dev=reload
}

# (ID) Buka modul kamu langsung di VS Code (Remote-WSL)
alias cdkedua='code /home/haryo/custom_addons/solvera_ojt_kedua'

# (ID) Jalan cepat skrip proyek kamu (ojtkedua_run.sh) bila ada
# alias ojtgo='/home/haryo/ojtkedua_run.sh'

# ====== pyenv (standar & aman) ======
# (ID) Inisialisasi pyenv hanya jika terpasang—hindari error saat shell start
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv >/dev/null 2>&1; then
  # Catatan: --path berguna untuk login shells; WSL biasa tetap lewat .bashrc
  eval "$(pyenv init --path)"
  eval "$(pyenv init -)"
  # Jika pakai pyenv-virtualenv:
  command -v pyenv-virtualenv-init >/dev/null 2>&1 && eval "$(pyenv virtualenv-init -)"
fi

# ====== History yang lebih nyaman ======
# (ID) Perbesar history & hilangkan duplikat
export HISTSIZE=50000
export HISTFILESIZE=100000
export HISTCONTROL=ignoreboth:erasedups
shopt -s histappend

# ====== VS Code CLI di PATH (jaga-jaga kalau 'code' belum ada) ======
# (ID) Sesuaikan <YourWindowsUser> jika perlu. Abaikan bila sudah bisa 'code .'
if ! command -v code >/dev/null 2>&1; then
  WINUSER="<YourWindowsUser>"
  [ -d "/mnt/c/Users/$WINUSER/AppData/Local/Programs/Microsoft VS Code/bin" ] && \
  export PATH="$PATH:/mnt/c/Users/$WINUSER/AppData/Local/Programs/Microsoft VS Code/bin"
fi

# ====== Locale & Node tuning (sudah OK, duplikasi tak masalah) ======
export PYTHONUNBUFFERED=1
export PIP_DISABLE_PIP_VERSION_CHECK=1
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export NODE_OPTIONS="--max_old_space_size=4096"
export ODOO_RC="$HOME/.odoo/odoo.conf"
export ODOO_CONF="$HOME/.odoo/odoo.conf"

# =========================================================
#  ojtgo: Jalankan Odoo 18 (WSL) utk modul tertentu
#  Pakai: ojtgo [nama_modul] [nama_db]
#  Contoh: ojtgo solvera_ojt_kedua odoo18
#  Default: modul=solvera_ojt_kedua, db=odoo18
# =========================================================
ojtgo() {
  set -euo pipefail
  # ---------- Konfigurasi dasar (ID) ----------
  local USER_HOME="/home/haryo"
  local VENV_DIR="$USER_HOME/.venvs/odoo18"        # venv Python 3.12 utk Odoo 18
  local ODOO_DIR="$USER_HOME/work/odoo"            # lokasi Odoo 18 (laptop)
  local CUSTOM_ADDONS="$USER_HOME/custom_addons"   # direktori addon kustom
  local MODULE="${1:-solvera_ojt_kedua}"           # modul default
  local DB="${2:-odoo18}"                          # nama DB default

  # ---------- Pin interpreter venv (ID) ----------
  local PY="$VENV_DIR/bin/python"
  local PIP="$VENV_DIR/bin/pip"
  if [ ! -x "$PY" ]; then
    echo "Venv tidak ditemukan: $VENV_DIR (buat venv Python 3.12 dulu)"; return 1
  fi

  # ---------- Start PostgreSQL 17 (ID) ----------
  if command -v pg_isready >/dev/null 2>&1; then
    if ! pg_isready -q; then
      sudo systemctl start postgresql 2>/dev/null || \
      sudo service postgresql start 2>/dev/null || \
      sudo pg_ctlcluster 17 main start || true
    fi
  fi
  if command -v pg_lsclusters >/dev/null 2>&1; then
    pg_lsclusters | awk '{print $1" "$2" "$4}' | grep -qE '^17 main online$' || \
      sudo pg_ctlcluster 17 main start || true
  fi

  # ---------- Update Odoo core + deps (ID) ----------
  if [ ! -d "$ODOO_DIR/.git" ]; then
    echo "Repo Odoo tidak ditemukan: $ODOO_DIR"; return 1
  fi
  ( cd "$ODOO_DIR" && \
    git fetch --all --tags && \
    (git switch 18.0 2>/dev/null || git checkout -B 18.0 origin/18.0) && \
    git pull --ff-only
  )
  "$PY" -m pip install -U pip setuptools wheel
  [ -f "$ODOO_DIR/requirements.txt" ] && "$PIP" install -r "$ODOO_DIR/requirements.txt"
  # Pastikan modul tambahan ada (ID)
  "$PIP" show Babel >/dev/null 2>&1 || "$PIP" install "Babel>=2.6.0"
  "$PIP" show pdfminer.six >/dev/null 2>&1 || "$PIP" install "pdfminer.six"

  # ---------- Hitung addons-path & temukan modul (ID) ----------
  local ODOO_BIN="$ODOO_DIR/odoo-bin"
  [ -x "$ODOO_BIN" ] || ODOO_BIN="$ODOO_DIR/odoo/odoo-bin"
  [ -x "$ODOO_BIN" ] || { echo "Tidak menemukan odoo-bin"; return 1; }
  local ADDONS_CORE
  ADDONS_CORE="$(dirname "$ODOO_BIN")/addons"

  sudo mkdir -p "$CUSTOM_ADDONS"
  sudo chown -R "$(id -u -n)":"$(id -g -n)" "$CUSTOM_ADDONS"

  local ADDONS_CUSTOM="$CUSTOM_ADDONS"
  if [ ! -d "$CUSTOM_ADDONS/$MODULE" ]; then
    # auto-locate modul di HOME (ID)
    local FOUND_MOD_DIR
    FOUND_MOD_DIR="$(find "$USER_HOME" -maxdepth 6 -type d -name "$MODULE" 2>/dev/null | head -n1 || true)"
    [ -n "${FOUND_MOD_DIR:-}" ] && ADDONS_CUSTOM="$(dirname "$FOUND_MOD_DIR")"
  fi

  # ---------- Pastikan DB ada (ID) ----------
  if command -v psql >/dev/null 2>&1; then
    psql -Atqc "SELECT 1 FROM pg_database WHERE datname='${DB}'" postgres >/dev/null 2>&1 || createdb "${DB}" || true
  fi

  # ---------- Tentukan install (-i) atau upgrade (-u) (ID) ----------
  local ACTION="-i"
  if command -v psql >/dev/null 2>&1; then
    local MOD_STATE
    MOD_STATE="$(psql -Atqc "SELECT state FROM ir_module_module WHERE name='${MODULE}'" "${DB}" 2>/dev/null | head -n1 | tr -d '[:space:]' || true)"
    case "${MOD_STATE}" in
      installed|to*) ACTION="-u" ;;
    esac
    printf '==> MODULE: %s | DB: %s | STATE: %s | ACTION: %s\n' "$MODULE" "$DB" "${MOD_STATE:-unknown}" "$ACTION"
  fi

  # ---------- Terapkan install/upgrade lalu jalankan server (ID) ----------
  "$PY" "$ODOO_BIN" -c "$USER_HOME/.odoo/odoo.conf" \
    --addons-path="$ADDONS_CORE,$ADDONS_CUSTOM" \
    -d "$DB" $ACTION "$MODULE" --stop-after-init

  exec "$PY" "$ODOO_BIN" -c "$USER_HOME/.odoo/odoo.conf" \
    --addons-path="$ADDONS_CORE,$ADDONS_CUSTOM" \
    -d "$DB" --dev=reload
}

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

# (ID) Deteksi Odoo core: prefer /work/odoo (laptop), fallback /work/odoo18 (PC)
_ojt_detect_odoo_dir() {
  for d in /home/haryo/work/odoo /home/haryo/work/odoo18; do
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
alias ojtgo='/home/haryo/ojtkedua_run.sh'

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

# ====== (Opsional) Auto-activate venv saat masuk folder kerja Odoo ======
# (ID) Nonaktifkan default; aktifkan kalau mau: hapus # di awal 3 baris di bawah
# _ojt_auto_venv() { [[ "$PWD" == /home/haryo/work/* || "$PWD" == /home/haryo/custom_addons/* ]] && source /home/haryo/.venvs/odoo18/bin/activate 2>/dev/null || return 0; }
# PROMPT_COMMAND="_ojt_auto_venv; $PROMPT_COMMAND"
# (ID) Catatan: PROMPT_COMMAND dieksekusi setiap prompt—jika mengganggu, biarkan tetap dikomentari.

# (ID) Jalankan: ojtgo  → install/upgrade solvera_ojt_kedua lalu start Odoo
ojtgo() {
  source /home/haryo/.venvs/odoo18/bin/activate || return 1
  local ODOO_DIR="/home/haryo/work/odoo"
  [ -x "$ODOO_DIR/odoo-bin" ] || ODOO_DIR="/home/haryo/work/odoo18"
  local ADDONS=""
  for p in "$ODOO_DIR/odoo/addons" "$ODOO_DIR/addons" "/home/haryo/custom_addons"; do
    [ -d "$p" ] && ADDONS="${ADDONS:+$ADDONS,}$p"
  done
  local ACTION="-i"
  if psql "postgresql://odoo:admin@127.0.0.1:5432/odoo18" -Atqc \
     "SELECT state FROM ir_module_module WHERE name='solvera_ojt_kedua'" | grep -q installed; then
    ACTION="-u"
  fi
  "$ODOO_DIR/odoo-bin" -c ~/.odoo/odoo.conf --addons-path="$ADDONS" -d odoo18 $ACTION solvera_ojt_kedua --stop-after-init &&
  "$ODOO_DIR/odoo-bin" -c ~/.odoo/odoo.conf --addons-path="$ADDONS" -d odoo18 --dev=reload
}

#!/usr/bin/env bash
# =============================================================================
#  TLab-26 — Ambiente Debian (proot-distro) pronto para uso no Termux
# -----------------------------------------------------------------------------
#  Uso:        bash tlab-26.sh
#  Assets:     coloque font.ttf e termux.properties na mesma pasta do script
#              (ou em ./assets/), ou exporte TLAB_ASSETS_URL=<url base>.
#
#  O script roda em DOIS ESTÁGIOS, usando este mesmo arquivo:
#    1) Termux  -> pacotes, tema, fish, proot-distro, GitHub, desktop (lado X11)
#    2) Debian  -> usuário, sudo, SSH, linguagens, editores, ngrok, LXDE
#  O estágio 2 é chamado automaticamente (--proot-stage); não rode à mão.
# =============================================================================

set -uo pipefail

# -----------------------------------------------------------------------------
# CONSTANTES (todas readonly)
# -----------------------------------------------------------------------------
readonly TLAB_NAME="TLab-26"
readonly TLAB_VERSION="2.0.0"
readonly DISTRO="debian"
readonly SSH_PORT=8122
readonly FISH_PROOT="/usr/bin/fish"
readonly ASSETS_URL="${TLAB_ASSETS_URL:-}"
readonly TTY_IN="${TLAB_TTY:-/dev/tty}"
readonly INPUT_FD=3

readonly DRACULA_URL="https://raw.githubusercontent.com/dracula/termux/master/colors.properties"
readonly NGROK_URL_BASE="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux"
readonly HELIX_RELEASES="https://github.com/helix-editor/helix/releases"
readonly FASTFETCH_RELEASES="https://github.com/fastfetch-cli/fastfetch/releases/latest/download"
readonly TERMUX_X11_RELEASES="https://github.com/termux/termux-x11/releases"
readonly GITHUB_NEW_KEY_URL="https://github.com/settings/ssh/new"

readonly ANSWERS_NAME=".tlab-answers"
readonly SCRIPT_COPY_NAME="tlab-26.sh"
readonly BLOCK_PREFIX="TLab-26"

readonly APT_OPTS=(-o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef)

readonly TERMUX_BASE_PKGS=(curl wget git openssh fish vim micro helix tree htop fastfetch proot-distro)
readonly TERMUX_LANG_PKGS=(rust golang python python-pip nodejs-lts)
readonly DEBIAN_CORE_PKGS=(sudo curl wget ca-certificates git openssh-client openssh-server
    fish vim micro tree htop unzip xz-utils less procps iproute2 build-essential pkg-config libssl-dev)
readonly DEBIAN_LANG_PKGS=(python3 python3-pip python3-venv pipx python-is-python3 nodejs npm golang-go)
readonly DEBIAN_OPTIONAL_PKGS=(fastfetch helix)
readonly DEBIAN_DESKTOP_PKGS=(lxde dbus-x11)

# Caminho do próprio script (vazio se rodando via pipe/curl | bash)
SELF_PATH=""
_src="${BASH_SOURCE[0]:-}"
if [[ -f "$_src" ]]; then
    SELF_PATH="$(cd "$(dirname "$_src")" && pwd)/$(basename "$_src")"
fi
unset _src
readonly SELF_PATH
readonly SELF_DIR="${SELF_PATH:+$(dirname "$SELF_PATH")}"

# Cores (desligadas se a saída não for um terminal)
if [[ -t 1 ]]; then
    readonly C_RST=$'\e[0m' C_BOLD=$'\e[1m' C_RED=$'\e[31m' C_GREEN=$'\e[32m'
    readonly C_YELLOW=$'\e[33m' C_BLUE=$'\e[34m' C_ORANGE=$'\e[38;2;254;128;1m'
else
    readonly C_RST="" C_BOLD="" C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_ORANGE=""
fi

# -----------------------------------------------------------------------------
# ESTADO GLOBAL — únicas variáveis mutáveis; preenchidas por collect_inputs
# (ou lidas do arquivo de respostas no estágio Debian)
# -----------------------------------------------------------------------------
YES_FLAG=""            # "-y" => confirma pacotes automaticamente
CHANGE_REPO="no"
USERNAME=""
USER_PASSWORD=""
ROOT_PASSWORD=""
SETUP_GITHUB="no"
GIT_USER=""
GIT_EMAIL=""
NGROK_TOKEN=""
LANGS_TERMUX="no"
INSTALL_DESKTOP="no"

# =============================================================================
# DADOS EMBUTIDOS (heredocs)
# =============================================================================

# Logo do fastfetch (arte gerada a partir do logo oficial; $1 = cor 1)
emit_logo() {
    cat <<'TLAB_LOGO_EOF'
__TLAB_LOGO__
TLAB_LOGO_EOF
}

# sshd_config exatamente como definido pelo padrão TLab-26 (porta 8122)
emit_sshd_config() {
    cat <<'TLAB_SSHD_EOF'
# This is the sshd server system-wide configuration file.  See
# sshd_config(5) for more information.

# This sshd was compiled with PATH=/usr/local/bin:/usr/bin:/bin:/usr/games

# The strategy used for options in the default sshd_config shipped with
# OpenSSH is to specify options with their default value where
# possible, but leave them commented.  Uncommented options override the
# default value.

Include /etc/ssh/sshd_config.d/*.conf

Port 8122
#AddressFamily any
#ListenAddress 0.0.0.0
#ListenAddress ::

#HostKey /etc/ssh/ssh_host_rsa_key
#HostKey /etc/ssh/ssh_host_ecdsa_key
#HostKey /etc/ssh/ssh_host_ed25519_key

# Ciphers and keying
#RekeyLimit default none

# Logging
#SyslogFacility AUTH
#LogLevel INFO

# Authentication:

#LoginGraceTime 2m
PermitRootLogin yes
#StrictModes yes
#MaxAuthTries 6
MaxSessions 3

#PubkeyAuthentication yes

# Expect .ssh/authorized_keys2 to be disregarded by default in future.
#AuthorizedKeysFile     .ssh/authorized_keys .ssh/authorized_keys2

#AuthorizedPrincipalsFile none

#AuthorizedKeysCommand none
#AuthorizedKeysCommandUser nobody

# For this to work you will also need host keys in /etc/ssh/ssh_known_hosts
#HostbasedAuthentication no
# Change to yes if you don't trust ~/.ssh/known_hosts for
# HostbasedAuthentication
#IgnoreUserKnownHosts no
# Don't read the user's ~/.rhosts and ~/.shosts files
#IgnoreRhosts yes

# To disable tunneled clear text passwords, change to "no" here!
PasswordAuthentication yes
#PermitEmptyPasswords no

# Change to "yes" to enable keyboard-interactive authentication.  Depending on
# the system's configuration, this may involve passwords, challenge-response,
# one-time passwords or some combination of these and other methods.
# Beware issues with some PAM modules and threads.
KbdInteractiveAuthentication no

# Kerberos options
#KerberosAuthentication no
#KerberosOrLocalPasswd yes
#KerberosTicketCleanup yes
#KerberosGetAFSToken no

# GSSAPI options
#GSSAPIAuthentication no
#GSSAPICleanupCredentials yes
#GSSAPIStrictAcceptorCheck yes
#GSSAPIKeyExchange no

# Set this to 'yes' to enable PAM authentication, account processing,
# and session processing. If this is enabled, PAM authentication will
# be allowed through the KbdInteractiveAuthentication and
# PasswordAuthentication.  Depending on your PAM configuration,
# PAM authentication via KbdInteractiveAuthentication may bypass
# the setting of "PermitRootLogin prohibit-password".
# If you just want the PAM account and session checks to run without
# PAM authentication, then enable this but set PasswordAuthentication
# and KbdInteractiveAuthentication to 'no'.
UsePAM no

#AllowAgentForwarding yes
#AllowTcpForwarding yes
#GatewayPorts no
X11Forwarding yes
#X11DisplayOffset 10
#X11UseLocalhost yes
#PermitTTY yes
PrintMotd no
#PrintLastLog yes
#TCPKeepAlive yes
#PermitUserEnvironment no
#Compression delayed
#ClientAliveInterval 0
#ClientAliveCountMax 3
#UseDNS no
#PidFile /run/sshd.pid
#MaxStartups 10:30:100
#PermitTunnel no
#ChrootDirectory none
#VersionAddendum none

# no default banner path
#Banner none

# Allow client to pass locale and color environment variables
AcceptEnv LANG LC_* COLORTERM NO_COLOR

# override default of no subsystems
Subsystem       sftp    /usr/lib/openssh/sftp-server

# Example of overriding settings on a per-user basis
#Match User anoncvs
#       X11Forwarding no
#       AllowTcpForwarding no
#       PermitTTY no
#       ForceCommand cvs server
TLAB_SSHD_EOF
}

# Tema Dracula (cópia de segurança caso o download falhe)
emit_dracula() {
    cat <<'TLAB_DRACULA_EOF'
background:     #282A36
foreground:     #F8F8F2

color0:         #000000
color8:         #4D4D4D

color1:         #FF5555
color9:         #FF6E67

color2:         #50FA7B
color10:        #5AF78E

color3:         #F1FA8C
color11:        #F4F99D

color4:         #BD93F9
color12:        #CAA9FA

color5:         #FF79C6
color13:        #FF92D0

color6:         #8BE9FD
color14:        #9AEDFE

color7:         #BFBFBF
color15:        #E6E6E6
TLAB_DRACULA_EOF
}

# termux.properties mínimo (usado só se o seu termux.properties não for achado)
emit_termux_properties() {
    cat <<'TLAB_PROPS_EOF'
### termux.properties — TLab-26
### Edite e rode `termux-reload-settings` para aplicar.
### A fonte NÃO é definida aqui: o Termux lê ~/.termux/font.ttf
### e as cores vêm de ~/.termux/colors.properties (tema Dracula).

### Esconde a barra de teclas extras
extra-keys = []
TLAB_PROPS_EOF
}

# Script de início do desktop, instalado em $PREFIX/bin/start-lxde
# (baseado no script oficial do LinuxDroidMaster/Termux-Desktops)
emit_start_lxde() {
    cat <<'TLAB_LXDE_EOF'
# Inicia o LXDE no Termux:X11. Rode no Termux "puro" (saia do proot com `exit`).
kill -9 $(pgrep -f "termux.x11") 2>/dev/null

# Áudio via PulseAudio na rede local
pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1

# Sessão X11
export XDG_RUNTIME_DIR="${TMPDIR}"
termux-x11 :0 >/dev/null 2>&1 &
sleep 3
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1
sleep 1

# Entra no Debian e roda o LXDE como o usuário comum
proot-distro login @DISTRO@ --shared-tmp -- /bin/bash -c 'export PULSE_SERVER=127.0.0.1 XDG_RUNTIME_DIR=/tmp && su - @USER@ -c "env DISPLAY=:0 startlxde"'
exit 0
TLAB_LXDE_EOF
}

# =============================================================================
# UTILS — saída
# =============================================================================
info() { printf '%s[i]%s %s\n' "$C_BLUE" "$C_RST" "$*"; }
ok()   { printf '%s[✓]%s %s\n' "$C_GREEN" "$C_RST" "$*"; }
warn() { printf '%s[!]%s %s\n' "$C_YELLOW" "$C_RST" "$*" >&2; }
err()  { printf '%s[✗]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; }
die()  { err "$*"; exit 1; }
step() { printf '\n%s▶ %s%s\n' "${C_ORANGE}${C_BOLD}" "$*" "$C_RST"; }

has_cmd() { command -v "$1" >/dev/null 2>&1; }

# =============================================================================
# UTILS — entrada interativa (sempre lida do terminal, via fd 3)
# =============================================================================
open_input() {
    [[ -r "$TTY_IN" ]] || die "Sem terminal interativo disponível (${TTY_IN})."
    exec 3<"$TTY_IN"
}

# ask <var> <pergunta> [padrão]
ask() {
    local -n __ask_out="$1"
    local prompt="$2" default="${3:-}" reply="" hint=""
    [[ -n "$default" ]] && hint=" [${default}]"
    printf '%s?%s %s%s: ' "$C_ORANGE" "$C_RST" "$prompt" "$hint" >&2
    IFS= read -r -u "$INPUT_FD" reply || die "Entrada interrompida."
    __ask_out="${reply:-$default}"
}

# ask_secret <var> <pergunta>  (digitação oculta)
ask_secret() {
    local -n __secret_out="$1"
    local reply=""
    printf '%s?%s %s: ' "$C_ORANGE" "$C_RST" "$2" >&2
    IFS= read -r -s -u "$INPUT_FD" reply || die "Entrada interrompida."
    printf '\n' >&2
    __secret_out="$reply"
}

# ask_valid <var> <pergunta> <função-validadora> <msg-de-erro> [padrão]
ask_valid() {
    local -n __valid_out="$1"
    local prompt="$2" validator="$3" msg="$4" default="${5:-}" value=""
    while :; do
        ask value "$prompt" "$default"
        if "$validator" "$value"; then
            __valid_out="$value"
            return 0
        fi
        warn "$msg"
    done
}

# ask_new_password <var> <pergunta>  (pede duas vezes)
ask_new_password() {
    local -n __pw_out="$1"
    local first="" second=""
    while :; do
        ask_secret first "$2"
        if [[ -z "$first" ]]; then
            warn "A senha não pode ser vazia."
            continue
        fi
        ask_secret second "Confirme a senha"
        if [[ "$first" == "$second" ]]; then
            __pw_out="$first"
            return 0
        fi
        warn "As senhas não coincidem. Tente de novo."
    done
}

# confirm <pergunta> [S|N]  -> retorna 0 para sim, 1 para não
confirm() {
    local prompt="$1" default="${2:-S}" reply="" hint="[S/n]"
    [[ "${default^^}" == "N" ]] && hint="[s/N]"
    while :; do
        printf '%s?%s %s %s: ' "$C_ORANGE" "$C_RST" "$prompt" "$hint" >&2
        IFS= read -r -u "$INPUT_FD" reply || die "Entrada interrompida."
        reply="${reply:-$default}"
        case "${reply,,}" in
            s|sim|y|yes) return 0 ;;
            n|nao|não|no) return 1 ;;
        esac
        warn "Responda apenas com S ou N."
    done
}

# =============================================================================
# UTILS — validadores
# =============================================================================
valid_username()    { [[ "$1" =~ ^[a-z_][a-z0-9_-]{0,30}$ && "$1" != "root" ]]; }
valid_email()       { [[ "$1" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]; }
valid_github_user() { [[ "$1" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,38})$ ]]; }

# =============================================================================
# UTILS — arquivos e rede
# =============================================================================

# download <url> <destino>  (escreve de forma atômica)
download() {
    local url="$1" dest="$2" tmp
    tmp="$(mktemp)" || return 1
    if curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 15 -o "$tmp" "$url"; then
        mv -f "$tmp" "$dest"
    else
        rm -f "$tmp"
        return 1
    fi
}

# backup_file <arquivo>  (uma única cópia .tlab.bak)
backup_file() {
    [[ -f "$1" && ! -e "$1.tlab.bak" ]] && cp -p "$1" "$1.tlab.bak"
    return 0
}

# fetch_asset <nome> <destino>  (pasta do script, ./assets, ou TLAB_ASSETS_URL)
fetch_asset() {
    local name="$1" dest="$2" dir
    for dir in "$SELF_DIR" "$SELF_DIR/assets"; do
        if [[ -n "$dir" && -f "$dir/$name" ]]; then
            cp -f "$dir/$name" "$dest"
            return 0
        fi
    done
    [[ -n "$ASSETS_URL" ]] && download "${ASSETS_URL%/}/$name" "$dest"
}

# upsert_block <arquivo> <nome> <conteúdo>  (cria/atualiza bloco delimitado; idempotente)
upsert_block() {
    local file="$1" name="$2" content="$3" tmp
    local begin="# >>> ${BLOCK_PREFIX}:${name} >>>" end="# <<< ${BLOCK_PREFIX}:${name} <<<"
    mkdir -p "$(dirname "$file")" && touch "$file" || return 1
    tmp="$(mktemp)" || return 1
    awk -v b="$begin" -v e="$end" '$0==b{skip=1;next} $0==e{skip=0;next} !skip' "$file" >"$tmp"
    { cat "$tmp"; printf '\n%s\n%s\n%s\n' "$begin" "$content" "$end"; } >"$file"
    rm -f "$tmp"
}

# arch_map <uname -m> <tipo>  -> nome da arquitetura em cada ecossistema
#   tipos: ngrok | helix | fastfetch
arch_map() {
    case "$2:$1" in
        ngrok:aarch64|ngrok:arm64)        echo "arm64" ;;
        ngrok:armv7l|ngrok:armv8l)        echo "arm" ;;
        ngrok:x86_64)                     echo "amd64" ;;
        helix:aarch64|helix:arm64)        echo "aarch64-linux" ;;
        helix:x86_64)                     echo "x86_64-linux" ;;
        fastfetch:aarch64|fastfetch:arm64) echo "aarch64" ;;
        fastfetch:armv7l|fastfetch:armv8l) echo "armv7l" ;;
        fastfetch:x86_64)                 echo "amd64" ;;
        *) return 1 ;;
    esac
}

# =============================================================================
# UTILS — gerenciadores de pacotes
# =============================================================================

# Termux
pkg_install() { pkg install ${YES_FLAG:+"$YES_FLAG"} "${APT_OPTS[@]}" "$@"; }

# Debian
apt_install() {
    DEBIAN_FRONTEND=noninteractive apt-get install ${YES_FLAG:+"$YES_FLAG"} "${APT_OPTS[@]}" "$@"
}

# install_many <função-instaladora> <pacotes...>
# Tenta em lote; se falhar, instala um a um e avisa o que não foi possível.
install_many() {
    local installer="$1"; shift
    "$installer" "$@" && return 0
    warn "Instalação em lote falhou; tentando pacote por pacote..."
    local pkg_name failed=()
    for pkg_name in "$@"; do
        "$installer" "$pkg_name" || failed+=("$pkg_name")
    done
    (( ${#failed[@]} == 0 )) || warn "Não instalados: ${failed[*]}"
    return 0
}

# =============================================================================
# UTILS — fish (blocos de configuração compartilhados pelo Termux e pelo Debian)
# =============================================================================

# fish_base_content <termux|proot>
fish_base_content() {
    cat <<'EOF'
set -gx EDITOR micro
set -gx GOPATH $HOME/go
fish_add_path -g $HOME/.local/bin $HOME/.cargo/bin $HOME/go/bin $HOME/.npm-global/bin
function fish_greeting
    command -q fastfetch; and fastfetch
end
EOF
    if [[ "$1" == "proot" ]]; then
        cat <<'EOF'
set -gx LANG C.UTF-8
if test -d /usr/local/lib/helix/runtime
    set -gx HELIX_RUNTIME /usr/local/lib/helix/runtime
end
alias ssh-start 'sudo service ssh start'
EOF
    fi
}

# setup_fastfetch <home>  (logo TLab-26 + config)
setup_fastfetch() {
    local dir="$1/.config/fastfetch"
    mkdir -p "$dir" || return 1
    emit_logo >"$dir/tlab-logo.txt"
    cat >"$dir/config.jsonc" <<EOF
{
  "logo": {
    "type": "file",
    "source": "$dir/tlab-logo.txt",
    "color": { "1": "38;2;254;128;1" },
    "padding": { "right": 3 }
  },
  "modules": ["title", "separator", "os", "kernel", "uptime", "packages",
              "shell", "cpu", "memory", "break", "colors"]
}
EOF
}

# =============================================================================
# ARQUIVO DE RESPOSTAS (Termux -> Debian), modo 600, apagado após o uso
# =============================================================================
write_answers() {
    local file="$1"
    : >"$file" && chmod 600 "$file" || return 1
    {
        printf 'USERNAME=%q\n'        "$USERNAME"
        printf 'USER_PASSWORD=%q\n'   "$USER_PASSWORD"
        printf 'ROOT_PASSWORD=%q\n'   "$ROOT_PASSWORD"
        printf 'YES_FLAG=%q\n'        "$YES_FLAG"
        printf 'NGROK_TOKEN=%q\n'     "$NGROK_TOKEN"
        printf 'INSTALL_DESKTOP=%q\n' "$INSTALL_DESKTOP"
    } >>"$file"
}

load_answers() {
    local file="/root/${ANSWERS_NAME}"
    [[ -f "$file" ]] || die "Arquivo de respostas não encontrado (${file})."
    # shellcheck disable=SC1090
    source "$file"
    rm -f "$file"
}

# =============================================================================
# ESTÁGIO 1 — TERMUX
# =============================================================================

rootfs_path() {
    local base="${PREFIX:-/data/data/com.termux/files/usr}/var/lib/proot-distro" path
    for path in "$base/containers/$DISTRO/rootfs" "$base/installed-rootfs/$DISTRO"; do
        if [[ -d "$path" ]]; then
            printf '%s\n' "$path"
            return 0
        fi
    done
    return 1
}

termux_banner() {
    printf '%s' "$C_ORANGE$C_BOLD"
    cat <<EOF

  ╔════════════════════════════════════════════╗
  ║   ${TLAB_NAME}  ·  Termux + Debian (proot)       ║
  ║   versão ${TLAB_VERSION}                              ║
  ╚════════════════════════════════════════════╝
EOF
    printf '%s\n' "$C_RST"
}

termux_preflight() {
    [[ "${PREFIX:-}" == *com.termux* ]] || die "Este script deve ser executado dentro do Termux."
    [[ "$(id -u)" -ne 0 ]] || die "Não execute como root."
    [[ -n "$SELF_PATH" ]] || die "Salve o script em um arquivo e rode:  bash ${SCRIPT_COPY_NAME}"
    has_cmd curl || pkg install -y curl || die "Não consegui instalar o curl."
    curl -fsI -m 15 https://github.com >/dev/null 2>&1 || die "Sem acesso à internet (github.com)."
}

termux_collect_inputs() {
    step "Configuração inicial"
    confirm "Iniciar a instalação do ${TLAB_NAME}?" S || { info "Cancelado."; exit 0; }
    confirm "Confirmar a instalação de pacotes automaticamente (-y)?" S && YES_FLAG="-y"
    confirm "Escolher o espelho (mirror) do Termux agora?" N && CHANGE_REPO="yes"

    ask_valid USERNAME "Nome do usuário do Debian (letras minúsculas)" valid_username \
        "Use letras minúsculas, números, _ ou -, começando por letra (e não use 'root')."
    ask_new_password USER_PASSWORD "Senha do usuário ${USERNAME}"
    if confirm "Usar a mesma senha para o root?" S; then
        ROOT_PASSWORD="$USER_PASSWORD"
    else
        ask_new_password ROOT_PASSWORD "Senha do root"
    fi

    if confirm "Configurar o GitHub (chave SSH) agora?" S; then
        SETUP_GITHUB="yes"
        ask_valid GIT_USER "Seu nome de usuário do GitHub" valid_github_user \
            "Nome de usuário inválido (apenas letras, números e hífen)."
        ask_valid GIT_EMAIL "E-mail da sua conta do GitHub" valid_email "E-mail inválido."
    fi

    info "O authtoken do ngrok fica em https://dashboard.ngrok.com/get-started/your-authtoken"
    ask_secret NGROK_TOKEN "Authtoken do ngrok (digitação oculta; Enter para pular)"

    confirm "Instalar também Rust/Go/Python/Node no Termux puro? (ocupa ~1,5 GB a mais)" N \
        && LANGS_TERMUX="yes"

    printf '\n%sDesktop gráfico (LXDE):%s recomendado apenas para aparelhos com 4 GB de RAM ou mais.\n' \
        "$C_BOLD" "$C_RST"
    confirm "Instalar o desktop LXDE no Debian?" N && INSTALL_DESKTOP="yes"

    printf '\n'
    info "Usuário: ${USERNAME} | SSH: porta ${SSH_PORT} | GitHub: ${SETUP_GITHUB} | Desktop: ${INSTALL_DESKTOP}"
    confirm "Tudo certo? Começar agora" S || { info "Cancelado."; exit 0; }
}

termux_update_system() {
    step "Atualizando o Termux"
    if [[ "$CHANGE_REPO" == "yes" ]]; then
        has_cmd termux-change-repo && termux-change-repo
    fi
    pkg update ${YES_FLAG:+"$YES_FLAG"} || die "Falha ao sincronizar os repositórios."
    pkg upgrade ${YES_FLAG:+"$YES_FLAG"} "${APT_OPTS[@]}" || die "Falha ao atualizar os pacotes."
}

termux_install_base() {
    step "Pacotes base: ${TERMUX_BASE_PKGS[*]}"
    install_many pkg_install "${TERMUX_BASE_PKGS[@]}"
    has_cmd fish || die "O fish não foi instalado; não dá para continuar."
    has_cmd proot-distro || die "O proot-distro não foi instalado; não dá para continuar."
}

termux_setup_storage() {
    step "Acesso ao armazenamento (termux-setup-storage)"
    if [[ -d "$HOME/storage" ]]; then
        ok "Armazenamento já habilitado."
        return 0
    fi
    info "O Android vai pedir permissão — toque em PERMITIR."
    termux-setup-storage
    local waited
    for (( waited = 0; waited < 30; waited++ )); do
        [[ -d "$HOME/storage" ]] && { ok "Armazenamento habilitado."; return 0; }
        sleep 1
    done
    warn "Permissão não confirmada. Rode 'termux-setup-storage' depois."
}

termux_apply_theme() {
    step "Fonte, tema Dracula e termux.properties"
    local dir="$HOME/.termux"
    mkdir -p "$dir"

    if fetch_asset font.ttf "$dir/font.ttf"; then
        ok "Fonte aplicada (~/.termux/font.ttf)."
    else
        warn "font.ttf não encontrada. Coloque-a ao lado do script ou use TLAB_ASSETS_URL."
    fi

    if download "$DRACULA_URL" "$dir/colors.properties"; then
        ok "Tema Dracula baixado."
    else
        emit_dracula >"$dir/colors.properties"
        warn "Download falhou; usei a cópia embutida do Dracula."
    fi

    backup_file "$dir/termux.properties"
    if fetch_asset termux.properties "$dir/termux.properties"; then
        ok "termux.properties aplicado."
    else
        emit_termux_properties >"$dir/termux.properties"
        warn "Seu termux.properties não foi encontrado; usei o modelo mínimo do ${TLAB_NAME}."
    fi

    has_cmd termux-reload-settings && termux-reload-settings
}

termux_setup_fish() {
    step "fish como shell padrão (Termux)"
    chsh -s fish || warn "Não consegui trocar o shell automaticamente (chsh -s fish)."
    local cfg="$HOME/.config/fish/config.fish" ngrok_fn
    ngrok_fn="function ngrok --description 'ngrok executado dentro do Debian (proot)'
    proot-distro login ${DISTRO} --user ${USERNAME} --shared-tmp -- ngrok \$argv
end"
    upsert_block "$cfg" "base" "$(fish_base_content termux)
${ngrok_fn}" || die "Falha ao escrever ${cfg}."
    setup_fastfetch "$HOME"
    ok "fish configurado."
}

termux_install_langs() {
    [[ "$LANGS_TERMUX" == "yes" ]] || return 0
    step "Linguagens no Termux: ${TERMUX_LANG_PKGS[*]}"
    install_many pkg_install "${TERMUX_LANG_PKGS[@]}"
    mkdir -p "$HOME/go/bin" "$HOME/.npm-global"
    has_cmd npm && npm config set prefix "$HOME/.npm-global"
    ok "Ambientes configurados (GOPATH, cargo, npm global, ~/.local/bin no PATH do fish)."
}

termux_install_debian() {
    step "Instalando o Debian (proot-distro)"
    if rootfs_path >/dev/null; then
        ok "Debian já instalado."
        return 0
    fi
    proot-distro install "$DISTRO" || die "Falha ao instalar o Debian."
    rootfs_path >/dev/null || die "Debian instalado, mas o rootfs não foi encontrado."
}

termux_run_proot_stage() {
    step "Configurando o Debian (pode demorar bastante)"
    local rootfs
    rootfs="$(rootfs_path)" || die "Rootfs do Debian não encontrado."
    install -m 700 "$SELF_PATH" "$rootfs/root/${SCRIPT_COPY_NAME}" || die "Não consegui copiar o script."
    write_answers "$rootfs/root/${ANSWERS_NAME}" || die "Não consegui gravar as respostas."
    proot-distro login "$DISTRO" -- bash "/root/${SCRIPT_COPY_NAME}" --proot-stage
    local rc=$?
    rm -f "$rootfs/root/${SCRIPT_COPY_NAME}" "$rootfs/root/${ANSWERS_NAME}"
    (( rc == 0 )) || die "O estágio Debian terminou com erro (código ${rc})."
    ok "Debian configurado."
}

# --- GitHub (chave SSH única, usada no Termux e no Debian) -------------------

github_test_ssh() {
    local out
    out="$(ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=15 \
        -T git@github.com 2>&1)"
    [[ "$out" == *"successfully authenticated"* ]]
}

# write_github_ssh_config <diretório .ssh>
write_github_ssh_config() {
    cat >"$1/config" <<'EOF'
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking accept-new
EOF
    chmod 600 "$1/config"
}

termux_setup_github() {
    [[ "$SETUP_GITHUB" == "yes" ]] || return 0
    step "GitHub: chave SSH e git"
    local ssh_dir="$HOME/.ssh" key="$HOME/.ssh/id_ed25519"
    mkdir -p "$ssh_dir" && chmod 700 "$ssh_dir"

    if [[ -f "$key" ]]; then
        info "Chave existente encontrada; vou reaproveitá-la."
    else
        ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$key" -N "" -q || die "Falha ao gerar a chave SSH."
        ok "Chave SSH gerada."
    fi
    git config --global user.name "$GIT_USER"
    git config --global user.email "$GIT_EMAIL"
    write_github_ssh_config "$ssh_dir"

    printf '\n%sSua chave pública (copie TUDO, da linha ssh-ed25519 até o e-mail):%s\n\n' "$C_BOLD" "$C_RST"
    printf '%s%s%s\n\n' "$C_GREEN" "$(cat "$key.pub")" "$C_RST"
    info "Segure o dedo sobre o texto acima para selecionar e copiar."
    info "Vou abrir a página do GitHub: cole a chave no campo 'Key' e toque em 'Add SSH key'."
    has_cmd termux-open-url && termux-open-url "$GITHUB_NEW_KEY_URL"

    while :; do
        confirm "Já adicionou a chave no GitHub? (testar conexão)" S || {
            warn "GitHub pulado. Depois, adicione a chave e rode: ssh -T git@github.com"
            return 0
        }
        if github_test_ssh; then
            ok "GitHub autenticado com sucesso!"
            return 0
        fi
        warn "Ainda não autenticou. Confira se colou a chave inteira e tente de novo."
    done
}

termux_sync_github_to_proot() {
    [[ "$SETUP_GITHUB" == "yes" && -f "$HOME/.ssh/id_ed25519" ]] || return 0
    local rootfs home_dir ssh_dir
    rootfs="$(rootfs_path)" || return 0
    home_dir="$rootfs/home/$USERNAME"
    ssh_dir="$home_dir/.ssh"
    [[ -d "$home_dir" ]] || { warn "Home do usuário no Debian não encontrada; pulei o GitHub lá."; return 0; }

    mkdir -p "$ssh_dir" && chmod 700 "$ssh_dir"
    cp -f "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_ed25519.pub" "$ssh_dir/"
    chmod 600 "$ssh_dir/id_ed25519"
    chmod 644 "$ssh_dir/id_ed25519.pub"
    write_github_ssh_config "$ssh_dir"
    cp -f "$HOME/.gitconfig" "$home_dir/.gitconfig" 2>/dev/null
    ok "GitHub também configurado no Debian (mesma chave, sem token)."
}

termux_configure_autologin() {
    step "Iniciar direto no Debian como ${USERNAME}"
    local cfg="$HOME/.config/fish/config.fish"
    upsert_block "$cfg" "autologin" "if status is-interactive
    and not test -f \$HOME/.tlab-no-autologin
    and command -q proot-distro
    proot-distro login ${DISTRO} --user ${USERNAME}
end" || die "Falha ao configurar o início automático."
    ok "Ao abrir o Termux você cai direto no Debian."
}

termux_install_desktop() {
    [[ "$INSTALL_DESKTOP" == "yes" ]] || return 0
    step "Desktop LXDE — lado Termux (X11 + áudio)"
    pkg_install x11-repo && pkg update ${YES_FLAG:+"$YES_FLAG"}
    install_many pkg_install termux-x11-nightly pulseaudio

    local target="$PREFIX/bin/start-lxde"
    {
        printf '#!%s/bin/bash\n' "$PREFIX"
        emit_start_lxde | sed -e "s|@USER@|${USERNAME}|g" -e "s|@DISTRO@|${DISTRO}|g"
    } >"$target"
    chmod 755 "$target"
    ok "Comando criado: start-lxde"

    warn "Falta instalar o APP Termux:X11 (APK separado). Abrindo a página de downloads..."
    has_cmd termux-open-url && termux-open-url "$TERMUX_X11_RELEASES"
}

termux_finish() {
    step "Pronto!"
    cat <<EOF
${C_BOLD}Resumo${C_RST}
  • Shell padrão: fish (Termux e Debian)
  • Usuário no Debian: ${USERNAME} (sudo habilitado)
  • Ao abrir o Termux você entra direto no Debian.
    Digite ${C_BOLD}exit${C_RST} para voltar ao Termux puro.
    Para desligar a entrada automática: ${C_BOLD}touch ~/.tlab-no-autologin${C_RST} (no Termux puro)

${C_ORANGE}${C_BOLD}SSH${C_RST}
  • Porta padrão: ${C_BOLD}${SSH_PORT}${C_RST}
  • Para ligar o servidor, no Debian digite: ${C_BOLD}ssh-start${C_RST}
  • Conectar de outro aparelho:  ssh -p ${SSH_PORT} ${USERNAME}@IP_DO_CELULAR
EOF
    [[ "$INSTALL_DESKTOP" == "yes" ]] && printf '\n%sDesktop%s: instale o app Termux:X11, saia do Debian (exit) e rode: %sstart-lxde%s\n' \
        "$C_BOLD" "$C_RST" "$C_BOLD" "$C_RST"
    printf '\nReinicie o Termux (feche e abra) para aplicar fonte, cores e shell.\n\n'
}

termux_main() {
    open_input
    termux_preflight
    termux_banner
    termux_collect_inputs
    termux_update_system
    termux_install_base
    termux_setup_storage
    termux_apply_theme
    termux_setup_fish
    termux_install_langs
    termux_install_debian
    termux_run_proot_stage
    termux_setup_github
    termux_sync_github_to_proot
    termux_configure_autologin
    termux_install_desktop
    termux_finish
}

# =============================================================================
# ESTÁGIO 2 — DEBIAN (executa dentro do proot, como root)
# =============================================================================

# as_user <comando> [args...]  -> roda como o usuário comum, com login shell
as_user() {
    su -s /bin/bash - "$USERNAME" -c "$(printf '%q ' "$@")"
}

proot_install_packages() {
    step "Pacotes do Debian"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update || die "apt-get update falhou."
    apt-get upgrade ${YES_FLAG:+"$YES_FLAG"} "${APT_OPTS[@]}" || warn "Upgrade com avisos."
    install_many apt_install "${DEBIAN_CORE_PKGS[@]}"
    install_many apt_install "${DEBIAN_LANG_PKGS[@]}"
    local p
    for p in "${DEBIAN_OPTIONAL_PKGS[@]}"; do
        apt_install "$p" || info "Pacote opcional '${p}' indisponível no apt; vou tentar outro jeito."
    done
    has_cmd fish || die "fish não foi instalado."
    has_cmd sudo || die "sudo não foi instalado."
}

proot_install_helix_fallback() {
    has_cmd hx && return 0
    step "Helix (release oficial)"
    local arch tag tmp
    arch="$(arch_map "$(uname -m)" helix)" || { warn "Helix: sem build para $(uname -m)."; return 0; }
    tag="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "${HELIX_RELEASES}/latest")"
    tag="${tag##*/}"
    [[ -n "$tag" ]] || { warn "Helix: não descobri a versão."; return 0; }
    tmp="$(mktemp -d)" || return 0
    if download "${HELIX_RELEASES}/download/${tag}/helix-${tag}-${arch}.tar.xz" "$tmp/hx.tar.xz" \
        && tar -xJf "$tmp/hx.tar.xz" -C "$tmp"; then
        install -m 755 "$tmp/helix-${tag}-${arch}/hx" /usr/local/bin/hx
        mkdir -p /usr/local/lib/helix
        rm -rf /usr/local/lib/helix/runtime
        cp -r "$tmp/helix-${tag}-${arch}/runtime" /usr/local/lib/helix/runtime
        ok "Helix ${tag} instalado (comando: hx)."
    else
        warn "Helix: falha no download."
    fi
    rm -rf "$tmp"
}

proot_install_fastfetch_fallback() {
    has_cmd fastfetch && return 0
    step "fastfetch (release oficial)"
    local arch tmp
    arch="$(arch_map "$(uname -m)" fastfetch)" || { warn "fastfetch: sem build para $(uname -m)."; return 0; }
    tmp="$(mktemp -d)" || return 0
    if download "${FASTFETCH_RELEASES}/fastfetch-linux-${arch}.tar.gz" "$tmp/ff.tgz" \
        && tar -xzf "$tmp/ff.tgz" -C "$tmp"; then
        install -m 755 "$tmp"/fastfetch-linux-*/usr/bin/fastfetch /usr/local/bin/fastfetch
        ok "fastfetch instalado."
    else
        warn "fastfetch: falha no download."
    fi
    rm -rf "$tmp"
}

proot_create_user() {
    step "Usuário ${USERNAME} e sudo"
    grep -qxF "$FISH_PROOT" /etc/shells || echo "$FISH_PROOT" >>/etc/shells

    if id "$USERNAME" >/dev/null 2>&1; then
        info "Usuário ${USERNAME} já existe; atualizando."
        usermod -s "$FISH_PROOT" -aG sudo "$USERNAME"
    else
        useradd -m -s "$FISH_PROOT" -G sudo "$USERNAME" || die "useradd falhou."
    fi
    printf '%s:%s\n' "$USERNAME" "$USER_PASSWORD" | chpasswd || die "Não consegui definir a senha do usuário."
    printf 'root:%s\n' "$ROOT_PASSWORD" | chpasswd || die "Não consegui definir a senha do root."
    usermod -s "$FISH_PROOT" root

    local line="${USERNAME} ALL=(ALL:ALL) ALL" tmp
    if grep -qxF "$line" /etc/sudoers; then
        ok "Permissão sudo já presente em /etc/sudoers."
    else
        tmp="$(mktemp)"
        cp /etc/sudoers "$tmp" && printf '%s\n' "$line" >>"$tmp"
        if visudo -cf "$tmp" >/dev/null; then
            cat "$tmp" >/etc/sudoers
            chmod 0440 /etc/sudoers
            ok "Usuário ${USERNAME} adicionado ao /etc/sudoers."
        else
            rm -f "$tmp"
            die "A edição do sudoers ficou inválida; nada foi alterado."
        fi
        rm -f "$tmp"
    fi
}

proot_configure_fish() {
    step "fish, aliases e fastfetch (root e ${USERNAME})"
    local home content
    content="$(fish_base_content proot)"
    for home in /root "/home/${USERNAME}"; do
        upsert_block "$home/.config/fish/config.fish" "base" "$content" || die "Falha no config.fish de ${home}."
        setup_fastfetch "$home"
    done
    chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}"
    ok "Alias criado: ssh-start  (= sudo service ssh start)"
}

proot_configure_ssh() {
    step "Servidor SSH na porta ${SSH_PORT}"
    backup_file /etc/ssh/sshd_config
    emit_sshd_config >/etc/ssh/sshd_config || die "Não consegui escrever o sshd_config."
    ssh-keygen -A >/dev/null 2>&1
    mkdir -p /run/sshd
    if sshd -t 2>/dev/null; then
        ok "sshd_config válido (Port ${SSH_PORT})."
    else
        warn "sshd -t reportou problemas; verifique /etc/ssh/sshd_config."
    fi
}

proot_install_ngrok() {
    step "ngrok"
    local arch tmp
    arch="$(arch_map "$(uname -m)" ngrok)" || { warn "ngrok: sem build para $(uname -m)."; return 0; }
    tmp="$(mktemp -d)" || return 0
    if download "${NGROK_URL_BASE}-${arch}.tgz" "$tmp/ngrok.tgz" \
        && tar -xzf "$tmp/ngrok.tgz" -C /usr/local/bin ngrok; then
        chmod 755 /usr/local/bin/ngrok
        ok "ngrok instalado."
        if [[ -n "$NGROK_TOKEN" ]]; then
            if as_user ngrok config add-authtoken "$NGROK_TOKEN" >/dev/null; then
                ok "Authtoken do ngrok configurado."
            else
                warn "Não consegui salvar o authtoken."
            fi
        else
            info "Sem authtoken. Configure depois com: ngrok config add-authtoken SEU_TOKEN"
        fi
    else
        warn "ngrok: falha no download."
    fi
    rm -rf "$tmp"
}

proot_install_rust() {
    local script
    script="$(mktemp)" || return 1
    if download "https://sh.rustup.rs" "$script"; then
        chmod 755 "$script"
        if as_user sh "$script" -y --profile minimal --no-modify-path -c clippy -c rustfmt; then
            as_user /home/"$USERNAME"/.cargo/bin/rustup component add rust-analyzer >/dev/null 2>&1 \
                || info "rust-analyzer indisponível para esta arquitetura (opcional)."
            ok "Rust instalado via rustup."
            rm -f "$script"
            return 0
        fi
    fi
    rm -f "$script"
    warn "rustup falhou; instalando rustc/cargo pelo apt."
    apt_install rustc cargo
}

proot_setup_dev_env() {
    step "Ambiente de desenvolvimento: Rust, Go, Python, Node"
    local home="/home/${USERNAME}"
    as_user mkdir -p "$home/go/bin" "$home/.npm-global" "$home/.local/bin"
    has_cmd npm && as_user npm config set prefix "$home/.npm-global"
    proot_install_rust
    ok "Go (GOPATH=~/go), Python (pip/venv/pipx), Node (npm global em ~/.npm-global) prontos."
}

proot_install_desktop() {
    [[ "$INSTALL_DESKTOP" == "yes" ]] || return 0
    step "Desktop LXDE (download grande)"
    install_many apt_install "${DEBIAN_DESKTOP_PKGS[@]}"
    if has_cmd startlxde; then
        ok "LXDE instalado."
    else
        warn "startlxde não encontrado após a instalação."
    fi
}

proot_cleanup() {
    apt-get clean
    rm -f "/root/${SCRIPT_COPY_NAME}"
}

proot_main() {
    [[ "$(id -u)" -eq 0 ]] || die "O estágio Debian deve rodar como root dentro do proot."
    [[ -f /etc/debian_version ]] || die "Este estágio é exclusivo do Debian."
    load_answers
    proot_install_packages
    proot_install_helix_fallback
    proot_install_fastfetch_fallback
    proot_create_user
    proot_configure_fish
    proot_configure_ssh
    proot_install_ngrok
    proot_setup_dev_env
    proot_install_desktop
    proot_cleanup
}

# =============================================================================
# ENTRADA
# =============================================================================
main() {
    case "${1:-}" in
        --proot-stage) proot_main ;;
        -h|--help)
            printf 'Uso: bash %s\n  Variáveis: TLAB_ASSETS_URL=<url base de font.ttf e termux.properties>\n' "$SCRIPT_COPY_NAME" ;;
        --version) printf '%s %s\n' "$TLAB_NAME" "$TLAB_VERSION" ;;
        *) termux_main ;;
    esac
}

# Permite `source tlab-26.sh` para testar funções isoladamente
if [[ "${BASH_SOURCE[0]:-$0}" == "$0" ]]; then
    main "$@"
fi

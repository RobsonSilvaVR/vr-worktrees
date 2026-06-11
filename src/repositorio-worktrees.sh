#!/usr/bin/env bash
# ==================================================================
#  repositorio-worktrees.sh  -  Menu "VR Worktrees" (bash)
#
#  Launcher para configurar QUALQUER repositorio VR no padrao de
#  git worktree (bare + worktrees), com um menu de selecao.
#  Para Git Bash (Git for Windows) ou WSL.
#
#  Para cada repositorio escolhido, monta:
#      C:\git\<Repo>\
#      |-- .bare\        repositorio central (so o historico)
#      |-- <branch>\     uma worktree por branch base escolhida
#
#  O comando 'task' (global, instalado via install-task) funciona em
#  todos os hubs criados aqui, pois detecta o projeto automaticamente.
#
#  Uso:
#      bash repositorio-worktrees.sh
#
#  Requisitos: git instalado e chave SSH do GitHub configurada.
# ==================================================================
set -euo pipefail

ORG='git@github.com:vrsoftbr'   # padrao das URLs (VRPdv confirmado)

# pasta onde este script esta (origem do install-task.sh)
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# raiz C:\git no ambiente atual
if [ -n "${GIT_ROOT:-}" ]; then ROOT="$GIT_ROOT"
elif [ -d /c ]; then ROOT='/c/git'
elif [ -d /mnt/c ]; then ROOT='/mnt/c/git'
else ROOT="$HOME/git"; fi

# cores
C_CY=$'\033[36m'; C_WH=$'\033[97m'; C_YE=$'\033[33m'
C_GR=$'\033[32m'; C_RE=$'\033[31m'; C_DK=$'\033[90m'; C_RS=$'\033[0m'
C_SEL=$'\033[30;46m'   # texto preto, fundo ciano (linha selecionada)
C_OR=$'\033[38;2;232;133;58m'   # laranja (ANSI 24-bit) para o "VR" do titulo

repo_url() { echo "$ORG/$1.git"; }

box_line() { # texto largura
  local text="$1" width="$2" len pad left right
  len=${#text}
  pad=$(( width - len )); [ "$pad" -lt 0 ] && pad=0
  left=$(( pad / 2 )); right=$(( pad - left ))
  printf '%*s%s%*s' "$left" '' "$text" "$right" ''
}

hline() { printf '  %s+%s+%s\n' "$C_CY" "$1" "$C_RS"; }
tline() { # texto cor
  printf '  %s|%s%s%s%s|%s\n' "$C_CY" "$C_RS$2" "$(box_line "$1" 46)" "$C_RS" "$C_CY" "$C_RS"
}

show_header() {
  clear 2>/dev/null || true
  local w=46 bar
  bar=$(printf '%*s' "$w" '' | tr ' ' '=')
  echo
  hline "$bar"
  tline '' "$C_CY"
  # titulo com "VR" em laranja e "WORKTREES" em branco
  printf '  %s|%*s%sV R%s   W O R K T R E E S%*s%s|%s\n' \
    "$C_CY" 11 '' "$C_OR" "$C_WH" 12 '' "$C_CY" "$C_RS"
  tline 'git worktree para os repositorios VR' "$C_DK"
  tline '' "$C_CY"
  hline "$bar"
  echo
}

# menu navegavel por setas. Desenha no /dev/tty e devolve o indice no stdout (-1 = Esc).
select_menu() {
  local title="$1"; shift
  local -a labels=("$@")
  local idx=0 key rest n=${#labels[@]} i

  tput civis >/dev/tty 2>/dev/null || true
  draw() {
    printf '\n' >/dev/tty
    printf '   %s%s%s\n' "$C_YE" "$title" "$C_RS" >/dev/tty
    printf '\n' >/dev/tty
    for i in "${!labels[@]}"; do
      if [ "$i" -eq "$idx" ]; then
        printf '   %s ❯ %s %s\n' "$C_SEL" "${labels[$i]}" "$C_RS" >/dev/tty
      else
        printf '     %s\n' "${labels[$i]}" >/dev/tty
      fi
    done
    printf '\n' >/dev/tty
    printf '   %sSetas ↑↓: Selecionar  ·  Enter: Confirma  ·  Esc: Cancela%s\n' "$C_DK" "$C_RS" >/dev/tty
  }

  draw
  while true; do
    IFS= read -rsn1 key </dev/tty
    case "$key" in
      $'\x1b')
        read -rsn2 -t 0.05 rest </dev/tty || rest=""
        case "$rest" in
          '[A') idx=$(( (idx - 1 + n) % n ));;
          '[B') idx=$(( (idx + 1) % n ));;
          '')   tput cnorm >/dev/tty 2>/dev/null || true; echo "-1"; return 0;;
        esac;;
      '')   tput cnorm >/dev/tty 2>/dev/null || true; echo "$idx"; return 0;;
    esac
    tput cuu $(( n + 5 )) >/dev/tty 2>/dev/null || true
    tput ed >/dev/tty 2>/dev/null || true
    draw
  done
}

install_dep_hook() { # bare
  # Instala o hook post-checkout que religa as juncoes das dependencias VR
  # locais conforme a branch-base do worktree. So em VRMaster/VRAutorizador.
  local bare="$1" hooks="$1/hooks"
  mkdir -p "$hooks"
  cat > "$hooks/post-checkout" <<'EOF'
#!/bin/sh
# Religa as juncoes das dependencias VR locais conforme a branch-base do worktree.
# Instalado automaticamente pelo vrwork (apenas VRMaster e VRAutorizador).
# A ATUALIZACAO (git pull) das dependencias fica a cargo do comando "task update".
# Args: $1=old-head  $2=new-head  $3=flag (1 = troca de branch / git worktree add)
[ "$3" = "1" ] || exit 0
wt="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
script="C:/git/bin/link-deps.ps1"
[ -f "$script" ] || exit 0
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$script" -AppWorktree "$wt" || true
exit 0
EOF
  chmod +x "$hooks/post-checkout" 2>/dev/null || true
  printf '%s  hook post-checkout instalado.%s\n' "$C_GR" "$C_RS"
}

setup_repo() { # nome [url]
  local name="$1" url="${2:-}"
  [ -z "$url" ] && url="$(repo_url "$name")"
  local hub="$ROOT/$name" bare="$ROOT/$name/.bare"

  echo
  printf '%s==> %s%s\n' "$C_CY" "$name" "$C_RS"

  # 1) acesso
  echo "  verificando acesso ($url) ..."
  if ! git ls-remote "$url" >/dev/null 2>&1; then
    echo
    printf '%s  ERRO: nao foi possivel acessar o repositorio %s.%s\n' "$C_RE" "$name" "$C_RS"
    echo '  Verifique se o nome esta correto, sua permissao e a chave SSH:'
    echo '    https://docs.github.com/authentication/connecting-to-github-with-ssh'
    printf '%s  Script encerrado.%s\n' "$C_RE" "$C_RS"
    exit 1
  fi

  # 2) pasta ja existe?
  if [ -e "$hub" ]; then
    printf '%s  "%s" ja existe.%s\n' "$C_YE" "$hub" "$C_RS"
    read -r -p '  Sobrescrever? Isso APAGA a pasta atual e tudo dentro (s/N): ' resp
    case "$resp" in
      [sS]*) echo "  removendo $hub ..."; rm -rf "$hub";;
      *) printf '%s  pulando %s (pasta mantida).%s\n' "$C_YE" "$name" "$C_RS"; return 0;;
    esac
  fi

  # 3) clone bare + hub
  mkdir -p "$hub"
  git clone --bare "$url" "$bare"
  git --git-dir="$bare" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
  git --git-dir="$bare" fetch origin --prune
  printf 'gitdir: ./.bare\n' > "$hub/.git"

  # 3b) hook post-checkout (apenas apps com dependencias locais)
  case "$name" in
    VRMaster|VRAutorizador) install_dep_hook "$bare";;
  esac

  # 4) worktrees base
  (
    cd "$hub"
    for b in "${BRANCHES[@]}"; do
      folder="${b//\//-}"
      if git show-ref --verify --quiet "refs/heads/$b"; then
        git worktree add "$folder" "$b" >/dev/null
        printf '%s  worktree: %s%s\n' "$C_GR" "$folder" "$C_RS"
      elif git show-ref --verify --quiet "refs/remotes/origin/$b"; then
        git worktree add -b "$b" "$folder" "origin/$b" >/dev/null
        printf '%s  worktree: %s%s\n' "$C_GR" "$folder" "$C_RS"
      else
        printf '%s  (aviso) branch "%s" nao existe em %s - pulada.%s\n' "$C_YE" "$b" "$name" "$C_RS"
      fi
    done
  )
  ANY_CREATED=1
  printf '%s  OK: %s%s\n' "$C_GR" "$hub" "$C_RS"
}

offer_install_task() {
  local bin="$ROOT/bin"
  # ja instalado?
  [ -f "$bin/task" ] && return 0
  local installer="$SRC/install-task.sh"
  if [ ! -f "$installer" ]; then
    printf '\n%s  (o comando "task" ainda nao esta instalado, e install-task.sh%s\n' "$C_YE" "$C_RS"
    printf '%s   nao foi encontrado ao lado deste script para instalar)%s\n' "$C_YE" "$C_RS"
    return 0
  fi
  echo
  read -r -p '  O comando global "task" ainda nao esta instalado. Instalar agora? (s/N): ' resp
  case "$resp" in
    [sS]*) bash "$installer";;
    *) printf '%s  ok - voce pode instalar depois com: bash install-task.sh%s\n' "$C_YE" "$C_RS";;
  esac
}

# ================== inicio ========================================
command -v git >/dev/null 2>&1 || { echo 'git nao encontrado no PATH.'; exit 1; }

while true; do
  show_header
  ANY_CREATED=0

  # --- selecao do repositorio ---
  REPOS=()
  CUSTOM_URL=''
  while [ ${#REPOS[@]} -eq 0 ]; do
    sel="$(select_menu 'Escolha o repositorio:' \
      'VRMaster' \
      'Dependencias (VRNfe, VRConnect, VRFramework, VRWorkflow)' \
      'VRPdv' \
      'VRAutorizador' \
      'VRConcentrador' \
      'Outro repositorio' \
      'Sair')"
    case "$sel" in
      0) REPOS=(VRMaster);;
      1) REPOS=(VRNfe VRConnect VRFramework VRWorkflow);;
      2) REPOS=(VRPdv);;
      3) REPOS=(VRAutorizador);;
      4) REPOS=(VRConcentrador);;
      5) read -r -p '   Nome do repo (ex: VRMaster) ou URL completa: ' inp </dev/tty
         if [ -n "$inp" ]; then
           case "$inp" in
             *[:@]*) CUSTOM_URL="$inp"; nm="${inp%.git}"; nm="${nm##*[:/]}"; REPOS=("$nm");;
             *) REPOS=("$inp");;
           esac
         else
           printf '%s   Entrada vazia.%s\n' "$C_RE" "$C_RS"
         fi;;
      *) printf '%s   Saindo.%s\n' "$C_CY" "$C_RS"; exit 0;;   # 6 (Sair) ou -1 (Esc)
    esac
  done

  # --- selecao das worktrees base ---
  BRANCHES=()
  while [ ${#BRANCHES[@]} -eq 0 ]; do
    sel="$(select_menu 'Quais worktrees base criar?' \
      'main + stable-4-4' \
      'somente main' \
      'somente stable-4-4' \
      'main + outra (informar)' \
      'Sair')"
    case "$sel" in
      0) BRANCHES=(main stable-4-4);;
      1) BRANCHES=(main);;
      2) BRANCHES=(stable-4-4);;
      3) read -r -p '   Informe a outra branch (alem de main): ' other </dev/tty
         if [ -n "$other" ]; then BRANCHES=(main "$other"); else printf '%s   Branch vazia.%s\n' "$C_RE" "$C_RS"; fi;;
      *) printf '%s   Saindo.%s\n' "$C_CY" "$C_RS"; exit 0;;   # 4 (Sair) ou -1 (Esc)
    esac
  done

  echo
  printf '  Repositorios: %s\n' "${REPOS[*]}"
  printf '  Worktrees base: %s\n' "${BRANCHES[*]}"

  # --- processa cada repositorio ---
  for r in "${REPOS[@]}"; do
    if [ -n "$CUSTOM_URL" ] && [ ${#REPOS[@]} -eq 1 ]; then
      setup_repo "$r" "$CUSTOM_URL"
    else
      setup_repo "$r"
    fi
  done

  echo
  printf '  %s==================================================%s\n' "$C_CY" "$C_RS"
  printf '  %sConcluido.%s\n' "$C_GR" "$C_RS"

  # --- se criou worktree e o comando "task" nao esta instalado, oferecer ---
  [ "$ANY_CREATED" -eq 1 ] && offer_install_task

  echo
  read -r -p '  Pressione ENTER para voltar ao menu... ' _
done

#!/usr/bin/env bash
# ==================================================================
#  install.sh  -  instalador principal do VR Worktrees (Git Bash/WSL)
#
#  Instala em C:\git\bin:
#    - o comando 'task'   (task, task.ps1, task.cmd)
#    - o menu  'vrwork'   (abre o VR Worktrees)
#  E adiciona C:\git\bin ao PATH (no ~/.bashrc).
#
#  Uso:
#      bash install.sh
# ==================================================================
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/src"

if [ -n "${GIT_BIN:-}" ]; then BIN="$GIT_BIN"
elif [ -d /c ]; then BIN='/c/git/bin'
elif [ -d /mnt/c ]; then BIN='/mnt/c/git/bin'
else BIN="$HOME/git/bin"; fi

C_CY=$'\033[36m'; C_YE=$'\033[33m'; C_GR=$'\033[32m'; C_DK=$'\033[90m'; C_RS=$'\033[0m'

required=(task task.ps1 task.cmd repositorio-worktrees.ps1 repositorio-worktrees.sh)
for f in "${required[@]}"; do
  if [ ! -f "$SRC/$f" ]; then
    echo "ERRO: nao encontrei '$f' na pasta 'src'." >&2
    exit 1
  fi
done

printf '%s== Instalando os comandos em %s ==%s\n' "$C_CY" "$BIN" "$C_RS"
mkdir -p "$BIN"
for f in "${required[@]}"; do cp "$SRC/$f" "$BIN/$f"; done
chmod +x "$BIN/task"
echo "  comando task e menu copiados."

# --- comando global 'vrwork' ---
cat > "$BIN/vrwork" <<'EOF'
#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$DIR/repositorio-worktrees.sh" "$@"
EOF
chmod +x "$BIN/vrwork"

cat > "$BIN/vrwork.cmd" <<'EOF'
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0repositorio-worktrees.ps1" %*
EOF
sed -i 's/\r$//; s/$/\r/' "$BIN/vrwork.cmd"
echo "  comando vrwork criado."

# --- PATH no ~/.bashrc ---
if grep -qsF "$BIN" "$HOME/.bashrc" 2>/dev/null; then
  echo "  ~/.bashrc ja referencia $BIN."
else
  printf '\n# VR Worktrees\nexport PATH="$PATH:%s"\n' "$BIN" >> "$HOME/.bashrc"
  echo "  adicionado ao PATH no ~/.bashrc."
fi

# --- resumo amigavel ---
echo
printf '%s  ============================================================%s\n' "$C_CY" "$C_RS"
printf '%s   Instalacao concluida!%s  %sRecarregue: source ~/.bashrc%s\n' "$C_GR" "$C_RS" "$C_DK" "$C_RS"
printf '%s  ============================================================%s\n' "$C_CY" "$C_RS"
echo
printf '%s  Voce agora tem dois comandos globais:%s\n\n' "$C_YE" "$C_RS"
printf '%s   vrwork%s\n' "$C_GR" "$C_RS"
echo  '       Abre o menu VR Worktrees para montar um repositorio'
echo  '       (clone unico + worktrees).'
echo
printf '%s   task <branch>%s\n' "$C_GR" "$C_RS"
echo  '       Abre/cria a worktree de uma branch que ja existe.'
echo
printf '%s   task <branch-base> <branch>%s\n' "$C_GR" "$C_RS"
echo  '       Cria uma branch nova a partir da base. Ex: task main PPV-123'
echo
printf '%s   Dica: os comandos vrwork e task podem ser executados de qualquer pasta.%s\n' "$C_DK" "$C_RS"
echo

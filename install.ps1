<#
  install.ps1  -  instalador principal do VR Worktrees (Windows)
  ==================================================================
  Instala, de uma vez por maquina, em C:\git\bin:
    - o comando 'task'   (task, task.ps1, task.cmd)
    - o menu  'vrwork'   (abre o VR Worktrees: repositorio-worktrees.ps1/.sh)
  E adiciona C:\git\bin ao PATH do usuario.

  Uso:
      powershell -ExecutionPolicy Bypass -File .\install.ps1
#>

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$bin = 'C:\git\bin'
$src = Join-Path $PSScriptRoot 'src'

$required = @('task','task.ps1','task.cmd','repositorio-worktrees.ps1','repositorio-worktrees.sh')
foreach ($f in $required) {
  if (-not (Test-Path (Join-Path $src $f))) {
    throw "Nao encontrei '$f' na pasta 'src'. Mantenha install.ps1 ao lado da pasta src do repositorio."
  }
}

Write-Host "== Instalando os comandos em $bin ==" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $bin | Out-Null
foreach ($f in $required) { Copy-Item (Join-Path $src $f) (Join-Path $bin $f) -Force }
Write-Host '  comando task e menu copiados.'

# --- cria o comando global 'vrwork' (abre o menu) ---
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$vrworkCmd = "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"%~dp0repositorio-worktrees.ps1`" %*`r`n"
[System.IO.File]::WriteAllText((Join-Path $bin 'vrwork.cmd'), $vrworkCmd, $utf8NoBom)

$vrworkSh = @'
#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$DIR/repositorio-worktrees.sh" "$@"
'@
[System.IO.File]::WriteAllText((Join-Path $bin 'vrwork'), ($vrworkSh -replace "`r`n","`n"), $utf8NoBom)
Write-Host '  comando vrwork criado.'

# --- adiciona C:\git\bin ao PATH do usuario (sem duplicar) ---
$userPath = [Environment]::GetEnvironmentVariable('Path','User')
if (-not $userPath) { $userPath = '' }
$jaTem = ($userPath -split ';') | Where-Object { $_.TrimEnd('\') -ieq $bin.TrimEnd('\') }
if ($jaTem) {
  Write-Host "  PATH ja contem $bin."
} else {
  [Environment]::SetEnvironmentVariable('Path', ($userPath.TrimEnd(';') + ';' + $bin).TrimStart(';'), 'User')
  Write-Host "  $bin adicionado ao PATH do usuario."
}

# --- resumo amigavel ---
$e = [char]27; $cOr = "$e[38;2;232;133;58m"; $rs = "$e[0m"
Write-Host ''
Write-Host '  ============================================================' -ForegroundColor Cyan
Write-Host '   Instalacao concluida!  ' -ForegroundColor Green -NoNewline; Write-Host 'Abra um NOVO terminal para usar.' -ForegroundColor DarkGray
Write-Host '  ============================================================' -ForegroundColor Cyan
Write-Host ''
Write-Host '  Voce agora tem dois comandos globais:' -ForegroundColor Yellow
Write-Host ''
Write-Host '   vrwork' -ForegroundColor Green
Write-Host '       Abre o menu VR Worktrees para montar um repositorio'
Write-Host '       (clone unico + worktrees).'
Write-Host ''
Write-Host '   task <branch>' -ForegroundColor Green
Write-Host '       Abre/cria a worktree de uma branch que ja existe.'
Write-Host ''
Write-Host '   task <branch-base> <branch>' -ForegroundColor Green
Write-Host '       Cria uma branch nova a partir da base.'
Write-Host '       Ex: ' -NoNewline; Write-Host 'task main PPV-123' -ForegroundColor Green
Write-Host ''
Write-Host '   Dica: os comandos vrwork e task podem ser executados de qualquer pasta.' -ForegroundColor DarkGray
Write-Host ''
Write-Host '   Para o Git Bash, rode tambem: bash install.sh' -ForegroundColor DarkGray
Write-Host ''

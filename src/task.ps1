<#
  task.ps1  -  logica do comando 'task' (Windows).
  Chamado pelo shim task.cmd (para o nome 'task' funcionar no PATH).

  uso:
    task <branch>                 checkout de uma branch existente
    task <branch-base> <branch>   cria uma branch nova a partir da base
    task update                   atualiza (git pull) e religa as dependencias VR locais

  - Dentro de um repositorio worktree: detecta o hub pelo git.
  - Fora de um repositorio: mostra um menu (setas + Enter) com os
    hubs ja criados em C:\git para voce escolher onde executar.
#>

$ErrorActionPreference = 'Stop'
$gitRoot = 'C:\git'

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$ARROW = [char]0x276F   # ❯
$NAV   = ('Setas {0}{1}: Selecionar  {2}  Enter: Confirma  {2}  Esc: Cancela' -f [char]0x2191, [char]0x2193, [char]0x00B7)

function Show-Usage {
  Write-Host ''
  Write-Host '  Comando invalido.' -ForegroundColor Red
  Write-Host ''
  Write-Host '  uso:' -ForegroundColor Yellow
  Write-Host '    task <branch>                 checkout de uma branch existente'
  Write-Host '    task <branch-base> <branch>   cria uma branch nova a partir da base'
  Write-Host '    task update                   atualiza (git pull) e religa as dependencias VR locais'
  Write-Host ''
}

function Get-WorktreeHubs {
  param([string]$root)
  if (-not (Test-Path $root)) { return @() }
  Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue |
    Where-Object { Test-Path (Join-Path $_.FullName '.bare') } |
    Select-Object -ExpandProperty FullName
}

function Open-Tab {
  param([string]$path, [string]$title)
  if (Get-Command wt -ErrorAction SilentlyContinue) {
    wt -w 0 nt --title $title -d $path
  }
}

function Select-Hub {
  # Menu navegavel por setas (cursor relativo via ANSI). Devolve o caminho ou $null (Esc).
  param([string[]]$items)
  $e = [char]27
  $count = $items.Count
  $idx = 0
  $lines = $count + 5   # blank + titulo + blank + opcoes + blank + rodape
  try { [Console]::CursorVisible = $false } catch { }
  try {
    $first = $true
    while ($true) {
      if (-not $first) { [Console]::Write("$e[${lines}A$e[0J") }   # sobe e limpa
      $first = $false
      Write-Host ''
      Write-Host '  Voce nao esta em um repositorio. Selecione o projeto:' -ForegroundColor Yellow
      Write-Host ''
      for ($i = 0; $i -lt $count; $i++) {
        $name = Split-Path $items[$i] -Leaf
        if ($i -eq $idx) {
          Write-Host (('  ' + $ARROW + ' ' + $name).PadRight(50)) -ForegroundColor Black -BackgroundColor Cyan
        } else {
          Write-Host (('    ' + $name).PadRight(50))
        }
      }
      Write-Host ''
      Write-Host ('  ' + $NAV) -ForegroundColor DarkGray
      $key = [Console]::ReadKey($true)
      switch ($key.Key) {
        'UpArrow'   { $idx = ($idx - 1 + $count) % $count }
        'DownArrow' { $idx = ($idx + 1) % $count }
        'Enter'     { return $items[$idx] }
        'Escape'    { return $null }
      }
    }
  } finally { try { [Console]::CursorVisible = $true } catch { } }
}

# ---------------- inicio ----------------

# subcomando: "task update" -> atualiza (git pull) e religa as dependencias VR locais
if ($args.Count -eq 1 -and $args[0] -eq 'update') {
  $wt = git rev-parse --show-toplevel 2>$null
  if ($LASTEXITCODE -ne 0 -or -not $wt) {
    Write-Host 'task update: execute dentro de um worktree (repositorio git).' -ForegroundColor Red
    exit 1
  }
  $linker = Join-Path $PSScriptRoot 'link-deps.ps1'
  if (-not (Test-Path $linker)) {
    Write-Host "task update: link-deps.ps1 nao encontrado em $PSScriptRoot." -ForegroundColor Red
    exit 1
  }
  & $linker -AppWorktree $wt -Pull
  exit 0
}

if ($args.Count -lt 1 -or $args.Count -gt 2) { Show-Usage; exit 1 }
if ($args.Count -eq 1) {
  $NEW = [string]$args[0]; $MODE = 'checkout'
} else {
  $BASE = [string]$args[0]; $NEW = [string]$args[1]; $MODE = 'create'
}

# detecta o hub do repositorio atual
$common = git rev-parse --git-common-dir 2>$null
if ($LASTEXITCODE -eq 0 -and $common) {
  try { $common = (Resolve-Path -LiteralPath $common -ErrorAction Stop).Path } catch { }
  $hub = Split-Path $common -Parent
} else {
  $hubs = @(Get-WorktreeHubs $gitRoot)
  if ($hubs.Count -eq 0) {
    Write-Host "Voce nao esta em um repositorio git e nenhum hub worktree foi encontrado em $gitRoot." -ForegroundColor Red
    exit 1
  }
  $hub = Select-Hub $hubs
  if (-not $hub) { Write-Host '  cancelado.'; exit 1 }
}

$folder = $NEW -replace '[\\/]', '-'
$dest   = Join-Path $hub $folder

# worktree ja existe?
if (Test-Path $dest) {
  if ($MODE -eq 'checkout') {
    Write-Host "Worktree ja existe: $dest (abrindo)"
    Open-Tab $dest $NEW
    exit 0
  } else {
    Write-Host "ERRO: ja existe '$dest'." -ForegroundColor Red
    exit 1
  }
}

$failed = $false
Push-Location $hub
try {
  Write-Host "Projeto: $hub" -ForegroundColor Cyan
  Write-Host 'Atualizando refs do remoto...'
  git fetch origin --prune | Out-Null

  $hasNew = @(git ls-remote --heads origin $NEW)

  if ($MODE -eq 'checkout') {
    git show-ref --verify --quiet "refs/heads/$NEW"
    $localHas = ($LASTEXITCODE -eq 0)
    if ($hasNew.Count -gt 0 -or $localHas) {
      git worktree add $dest $NEW
    } else {
      Write-Host "ERRO: a branch '$NEW' nao existe." -ForegroundColor Red
      Write-Host "Para criar uma branch nova: task <branch-base> $NEW"
      $failed = $true
    }
  } else {
    if ($hasNew.Count -gt 0) {
      Write-Host "Branch '$NEW' existe no remoto -> checkout."
      git worktree add $dest $NEW
    } else {
      $hasBase = @(git ls-remote --heads origin $BASE)
      if ($hasBase.Count -gt 0) { $baseref = "origin/$BASE" } else { $baseref = $BASE }
      Write-Host "Criando branch '$NEW' a partir de '$baseref'."
      git worktree add -b $NEW $dest $baseref
    }
  }

  if (-not $failed) {
    Write-Host "Pronto: $dest  (branch $NEW)" -ForegroundColor Green
    Open-Tab $dest $NEW
  }
} finally { Pop-Location }

if ($failed) { exit 1 }

<#
  repositorio-worktrees.ps1  -  Menu "VR Worktrees"
  ==================================================================
  Launcher para configurar QUALQUER repositorio VR no padrao de
  git worktree (bare + worktrees), com um menu de selecao.

  Para cada repositorio escolhido, monta:
      C:\git\<Repo>\
      |-- .bare\        repositorio central (so o historico)
      |-- <branch>\     uma worktree por branch base escolhida
      |-- ...           demais worktrees criadas depois com 'task'

  Fluxo:
    1. Escolhe o repositorio no menu.
    2. Escolhe quais worktrees base criar.
    3. Verifica acesso (SSH). Sem permissao -> encerra.
    4. Se a pasta do repo ja existir, pergunta se sobrescreve.
    5. Clona (bare), estrutura o hub e cria as worktrees base.

  O comando 'task' (global, instalado via install-task) funciona em
  todos os hubs criados aqui, pois detecta o projeto automaticamente.

  Uso:
      powershell -ExecutionPolicy Bypass -File .\repositorio-worktrees.ps1

  Requisitos: git instalado e chave SSH do GitHub configurada.
#>

$ErrorActionPreference = 'Stop'

# ---- Configuracao ------------------------------------------------
$ORG     = 'git@github.com:vrsoftbr'   # padrao das URLs (VRPdv confirmado)
$gitRoot = 'C:\git'
# ------------------------------------------------------------------

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$ARROW = [char]0x276F   # ❯
$NAV   = ('Setas {0}{1}: Selecionar  {2}  Enter: Confirma  {2}  Esc: Cancela' -f [char]0x2191, [char]0x2193, [char]0x00B7)

function Repo-Url([string]$name) { return "$ORG/$name.git" }

function Box-Line([string]$text, [int]$width) {
  $pad   = $width - $text.Length
  if ($pad -lt 0) { $pad = 0 }
  $left  = [math]::Floor($pad / 2)
  $right = $pad - $left
  return (' ' * $left) + $text + (' ' * $right)
}

function Show-Header {
  Clear-Host
  $w = 46
  Write-Host ''
  Write-Host ('  +' + ('=' * $w) + '+') -ForegroundColor Cyan
  Write-Host ('  |' + (Box-Line ''                                    $w) + '|') -ForegroundColor Cyan
  # titulo com "VR" em laranja (ANSI 24-bit) e "WORKTREES" em branco
  $e = [char]27
  $cOr = "$e[38;2;232;133;58m"; $cWh = "$e[97m"; $cCy = "$e[36m"; $cRs = "$e[0m"
  Write-Host ($cCy + '  |' + (' ' * 11) + $cOr + 'V R' + $cWh + '   W O R K T R E E S' + $cCy + (' ' * 12) + '|' + $cRs)
  Write-Host ('  |' + (Box-Line 'git worktree para os repositorios VR' $w) + '|') -ForegroundColor DarkCyan
  Write-Host ('  |' + (Box-Line ''                                    $w) + '|') -ForegroundColor Cyan
  Write-Host ('  +' + ('=' * $w) + '+') -ForegroundColor Cyan
  Write-Host ''
}

function Select-Menu {
  # Mostra um menu navegavel por setas. Devolve o indice (0..n-1) ou -1 (Esc).
  param([string]$title, [string[]]$labels)
  $count = $labels.Count
  try {
    $idx = 0
    Write-Host ''
    Write-Host ('   ' + $title) -ForegroundColor Yellow
    Write-Host ''
    for ($i = 0; $i -lt $count; $i++) { Write-Host '' }      # reserva as linhas das opcoes
    $top = [Console]::CursorTop - $count
    Write-Host ''
    Write-Host ('   ' + $NAV) -ForegroundColor DarkGray
    [Console]::CursorVisible = $false
    while ($true) {
      for ($i = 0; $i -lt $count; $i++) {
        [Console]::SetCursorPosition(0, $top + $i)
        if ($i -eq $idx) {
          Write-Host (('   ' + $ARROW + ' ' + $labels[$i]).PadRight(62)) -ForegroundColor Black -BackgroundColor Cyan
        } else {
          Write-Host (('     ' + $labels[$i]).PadRight(62))
        }
      }
      $key = [Console]::ReadKey($true)
      switch ($key.Key) {
        'UpArrow'   { $idx = ($idx - 1 + $count) % $count }
        'DownArrow' { $idx = ($idx + 1) % $count }
        'Enter'     { [Console]::CursorVisible = $true; [Console]::SetCursorPosition(0, $top + $count + 2); return $idx }
        'Escape'    { [Console]::CursorVisible = $true; [Console]::SetCursorPosition(0, $top + $count + 2); return -1 }
      }
    }
  } catch {
    [Console]::CursorVisible = $true
    Write-Host ''
    Write-Host ('   ' + $title) -ForegroundColor Yellow
    for ($i = 0; $i -lt $count; $i++) { Write-Host ('   {0}) {1}' -f ($i + 1), $labels[$i]) }
    $sel = Read-Host '   Numero'
    if ($sel -match '^\d+$' -and [int]$sel -ge 1 -and [int]$sel -le $count) { return ([int]$sel - 1) }
    return -1
  }
}

function Setup-Repo {
  param(
    [Parameter(Mandatory)] [string]   $name,
    [Parameter(Mandatory)] [string[]] $branches,
                           [string]   $url
  )
  if (-not $url) { $url = Repo-Url $name }
  $hub  = Join-Path $gitRoot $name
  $bare = Join-Path $hub '.bare'

  Write-Host ''
  Write-Host "==> $name" -ForegroundColor Cyan

  # 1) acesso ao repositorio
  Write-Host "  verificando acesso ($url) ..."
  git ls-remote $url 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Write-Host ''
    Write-Host "  ERRO: nao foi possivel acessar o repositorio '$name'." -ForegroundColor Red
    Write-Host '  Verifique se o nome esta correto, sua permissao e a chave SSH no GitHub:'
    Write-Host '    https://docs.github.com/authentication/connecting-to-github-with-ssh'
    Write-Host '  Script encerrado.' -ForegroundColor Red
    exit 1
  }

  # 2) pasta ja existe?
  if (Test-Path $hub) {
    Write-Host "  '$hub' ja existe." -ForegroundColor DarkYellow
    $r = Read-Host '  Sobrescrever? Isso APAGA a pasta atual e tudo dentro dela (s/N)'
    if ($r -notmatch '^[sS]') {
      Write-Host "  pulando $name (pasta existente mantida)." -ForegroundColor DarkYellow
      return
    }
    Write-Host "  removendo $hub ..."
    Remove-Item -Recurse -Force $hub
  }

  # 3) clone bare + configuracao do hub
  New-Item -ItemType Directory -Force -Path $hub | Out-Null
  git clone --bare $url $bare
  git --git-dir="$bare" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
  git --git-dir="$bare" fetch origin --prune
  Set-Content -Path (Join-Path $hub '.git') -Value 'gitdir: ./.bare' -Encoding ascii

  # 4) worktrees base
  Push-Location $hub
  try {
    foreach ($b in $branches) {
      $folder = $b -replace '[\\/]','-'
      git show-ref --verify --quiet ("refs/heads/$b")
      if ($LASTEXITCODE -eq 0) {
        git worktree add $folder $b | Out-Null
        Write-Host "  worktree: $folder" -ForegroundColor Green
      } else {
        git show-ref --verify --quiet ("refs/remotes/origin/$b")
        if ($LASTEXITCODE -eq 0) {
          git worktree add -b $b $folder "origin/$b" | Out-Null
          Write-Host "  worktree: $folder" -ForegroundColor Green
        } else {
          Write-Host "  (aviso) branch '$b' nao existe em $name - pulada." -ForegroundColor DarkYellow
        }
      }
    }
  } finally { Pop-Location }
  $script:AnyCreated = $true
  Write-Host "  OK: $hub" -ForegroundColor Green
}

function Offer-InstallTask {
  $bin = 'C:\git\bin'
  # ja instalado? (arquivo presente no diretorio global)
  if (Test-Path (Join-Path $bin 'task.cmd')) { return }

  $installer = Join-Path $PSScriptRoot 'install-task.ps1'
  if (-not (Test-Path $installer)) {
    Write-Host ''
    Write-Host '  (o comando "task" ainda nao esta instalado, e install-task.ps1' -ForegroundColor DarkYellow
    Write-Host '   nao foi encontrado ao lado deste script para instalar)'        -ForegroundColor DarkYellow
    return
  }

  Write-Host ''
  $r = Read-Host '  O comando global "task" ainda nao esta instalado. Instalar agora? (s/N)'
  if ($r -match '^[sS]') {
    & $installer
  } else {
    Write-Host '  ok - voce pode instalar depois com: .\install-task.ps1' -ForegroundColor DarkYellow
  }
}

# ================== inicio ========================================

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw 'git nao encontrado no PATH. Instale o Git e tente de novo.'
}

while ($true) {
  Show-Header
  $script:AnyCreated = $false

  # --- selecao do repositorio ---
  $repoLabels = @(
    'VRMaster',
    'Dependencias (VRNfe, VRConnect, VRFramework, VRWorkflow)',
    'VRPdv',
    'VRAutorizador',
    'VRConcentrador',
    'Outro repositorio',
    'Sair'
  )
  $repos     = $null
  $customUrl = $null
  while (-not $repos) {
    $sel = Select-Menu 'Escolha o repositorio:' $repoLabels
    switch ($sel) {
      0 { $repos = @('VRMaster') }
      1 { $repos = @('VRNfe','VRConnect','VRFramework','VRWorkflow') }
      2 { $repos = @('VRPdv') }
      3 { $repos = @('VRAutorizador') }
      4 { $repos = @('VRConcentrador') }
      5 {
        $inp = Read-Host '   Nome do repo (ex: VRMaster) ou URL completa'
        if (-not [string]::IsNullOrWhiteSpace($inp)) {
          $inp = $inp.Trim()
          if ($inp -match '[:@]') {
            $customUrl = $inp
            $repos = @( (($inp -replace '\.git$','') -split '[/:]' | Select-Object -Last 1) )
          } else {
            $repos = @($inp)
          }
        } else {
          Write-Host '   Entrada vazia.' -ForegroundColor Red
        }
      }
      default { Write-Host '   Saindo.' -ForegroundColor Cyan; exit 0 }   # 6 (Sair) ou -1 (Esc)
    }
  }

  # --- selecao das worktrees base ---
  $branchLabels = @(
    'main + stable-4-4',
    'somente main',
    'somente stable-4-4',
    'main + outra (informar)',
    'Sair'
  )
  $branches = $null
  while (-not $branches) {
    $sel = Select-Menu 'Quais worktrees base criar?' $branchLabels
    switch ($sel) {
      0 { $branches = @('main','stable-4-4') }
      1 { $branches = @('main') }
      2 { $branches = @('stable-4-4') }
      3 {
        $other = Read-Host '   Informe a outra branch (alem de main)'
        if (-not [string]::IsNullOrWhiteSpace($other)) {
          $branches = @('main', $other.Trim())
        } else {
          Write-Host '   Branch vazia.' -ForegroundColor Red
        }
      }
      default { Write-Host '   Saindo.' -ForegroundColor Cyan; exit 0 }   # 4 (Sair) ou -1 (Esc)
    }
  }

  Write-Host ''
  Write-Host ('  Repositorios: ' + ($repos -join ', ')) -ForegroundColor White
  Write-Host ('  Worktrees base: ' + ($branches -join ', ')) -ForegroundColor White

  # --- processa cada repositorio ---
  foreach ($r in $repos) {
    if ($customUrl -and $repos.Count -eq 1) {
      Setup-Repo -name $r -branches $branches -url $customUrl
    } else {
      Setup-Repo -name $r -branches $branches
    }
  }

  Write-Host ''
  Write-Host '  ==================================================' -ForegroundColor Cyan
  Write-Host '  Concluido.' -ForegroundColor Green

  # --- se criou worktree e o comando "task" nao esta instalado, oferecer ---
  if ($script:AnyCreated) { Offer-InstallTask }

  Write-Host ''
  Read-Host '  Pressione ENTER para voltar ao menu'
}

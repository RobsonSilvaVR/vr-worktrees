#Requires -Version 5.1
<#
.SYNOPSIS
    Religa as juncoes das dependencias VR locais de um app (VRMaster /
    VRAutorizador) conforme a branch-base do worktree informado.

.DESCRIPTION
    Detecta de qual branch-base (main | stable-4-4) o worktree descende,
    comparando os merge-base de HEAD com cada candidata (a base mais especifica
    vence), e cria/atualiza juncoes em <hub>\<dep> apontando para
    C:\git\<dep>\<base>, para cada dependencia que possua um worktree local
    daquela base.

    Dependencias sem worktree local da base sao ignoradas (o Gradle usa o
    artefato publicado no Maven). As juncoes ficam no "hub" (C:\git\<App>), que
    NAO e worktree -> nao aparecem em "git status". O settings.gradle as
    encontra via ../<dep>.

.NOTES
    Chamado automaticamente pelo hook post-checkout que o vrwork instala em
    VRMaster e VRAutorizador. Tambem pode ser executado a mao a partir de
    qualquer worktree desses apps.

.EXAMPLE
    pwsh -File C:\git\bin\link-deps.ps1
    # detecta a base pela pasta atual e religa as dependencias

.EXAMPLE
    pwsh -File C:\git\bin\link-deps.ps1 -AppWorktree C:\git\VRAutorizador\PPV-326
#>
[CmdletBinding()]
param(
    # Worktree do app a inspecionar (default: pasta atual)
    [string]$AppWorktree = (Get-Location).Path,

    # Dependencias candidatas a religar (so religa as que tiverem worktree local)
    [string[]]$Deps = @('VRNfe', 'VRConnect', 'VRWorkflow', 'VRFramework'),

    # Branches-base candidatas (da mais generica para a mais especifica)
    [string[]]$Candidates = @('main', 'stable-4-4'),

    # Faz "git pull --ff-only" no worktree de cada dependencia antes de religar
    [switch]$Pull
)

# git escreve mensagens informativas no stderr; evita que isso vire erro
# terminante quando chamado de um contexto com ErrorActionPreference = 'Stop'
# (ex.: o subcomando "task update", cujo task.ps1 usa Stop).
$ErrorActionPreference = 'Continue'

function Resolve-BaseBranch {
    param([string]$RepoPath, [string[]]$Candidates)

    $current = git -C $RepoPath rev-parse --abbrev-ref HEAD 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    $current = $current.Trim()
    if ($Candidates -contains $current) { return $current }

    $best = $null; $bestMb = $null
    foreach ($c in $Candidates) {
        # aceita branch local ou origin/<branch>
        $ref = $c
        git -C $RepoPath rev-parse --verify --quiet $ref *> $null
        if ($LASTEXITCODE -ne 0) {
            $ref = "origin/$c"
            git -C $RepoPath rev-parse --verify --quiet $ref *> $null
            if ($LASTEXITCODE -ne 0) { continue }
        }

        $mb = git -C $RepoPath merge-base HEAD $ref 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $mb) { continue }
        $mb = $mb.Trim()

        if (-not $bestMb) { $best = $c; $bestMb = $mb; continue }

        # Se o merge-base desta candidata descende do melhor ate agora, ela e a
        # base mais especifica (forkou depois) -> vence.
        git -C $RepoPath merge-base --is-ancestor $bestMb $mb *> $null
        if ($LASTEXITCODE -eq 0 -and $bestMb -ne $mb) { $best = $c; $bestMb = $mb }
    }
    return $best
}

# Quando chamado por um hook (post-checkout), o git exporta GIT_DIR/GIT_WORK_TREE/
# etc. apontando para o repo do hook. Isso faria "git -C <dep>" operar no repo
# errado. Limpamos essas variaveis para que cada "git -C" use o repo correto.
foreach ($v in 'GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_COMMON_DIR', 'GIT_PREFIX', 'GIT_CHECKOUT_TARGET', 'GIT_REFLOG_ACTION') {
    Remove-Item "Env:$v" -ErrorAction SilentlyContinue
}

# Normaliza o caminho (o hook pode passar com barras "/")
$AppWorktree = (Resolve-Path -LiteralPath $AppWorktree).Path
$hub     = Split-Path $AppWorktree -Parent      # C:\git\<App>
$gitRoot = Split-Path $hub -Parent              # C:\git

$base = Resolve-BaseBranch -RepoPath $AppWorktree -Candidates $Candidates
if (-not $base) {
    Write-Warning "link-deps: nao foi possivel determinar a branch-base de '$AppWorktree'."
    return
}

$current = (git -C $AppWorktree rev-parse --abbrev-ref HEAD).Trim()
$appName = Split-Path $hub -Leaf
Write-Host "link-deps: $current  =>  base detectada: $base" -ForegroundColor Cyan

foreach ($dep in $Deps) {
    if ($dep -eq $appName) { continue }                   # nao religar o proprio app

    $target = Join-Path (Join-Path $gitRoot $dep) $base   # C:\git\<dep>\<base>
    if (-not (Test-Path -LiteralPath $target)) {
        # sem worktree local desta base -> Gradle resolve pelo Maven
        continue
    }

    if ($Pull) {
        # pull explicito (origin <base>): os worktrees nao tem upstream configurado
        $out = (git -C $target pull --ff-only origin $base 2>&1 | Out-String).Trim()
        $lines = $out -split "`r?`n" | Where-Object { $_ -ne '' }
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [$dep] pull: $($lines | Select-Object -Last 1)" -ForegroundColor DarkGray
        }
        else {
            Write-Warning "  [$dep] pull falhou (segue assim mesmo): $($lines | Select-Object -First 1)"
        }
    }

    $link = Join-Path $hub $dep                           # C:\git\<App>\<dep>
    $item = Get-Item -LiteralPath $link -ErrorAction SilentlyContinue
    if ($item) {
        if ($item.LinkType -ne 'Junction') {
            Write-Warning "  [$dep] '$link' e pasta real (nao-juncao) - pulado por seguranca."
            continue
        }
        # .Delete() e nao-recursivo: remove apenas o link, nunca o alvo.
        $item.Delete()
    }

    New-Item -ItemType Junction -Path $link -Target $target | Out-Null
    Write-Host "  [$dep] $link  ->  $target" -ForegroundColor Green
}

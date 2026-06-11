# VR Worktrees

Scripts para trabalhar com os repositórios VR usando **git worktree**: um clone único por projeto e várias pastas de trabalho, uma por branch.

## Uso

1. Instalar (uma vez por máquina) — cria os comandos globais `vrwork` e `task` e configura o PATH:

   ```powershell
   .\install.ps1        # PowerShell
   bash install.sh      # Git Bash
   ```

   Abra um novo terminal depois.

2. Montar um repositório (menu interativo, setas + Enter):

   ```
   vrwork
   ```

3. Criar/abrir worktrees com o comando `task`:

   ```
   task main PPV-123     # cria a branch PPV-123 a partir de main
   task PPV-123          # checkout de uma branch existente
   ```

   Rodando o `task` fora de um repositório, ele abre um menu para escolher o projeto.

4. Atualizar e religar as dependências VR locais com `vrdeps` (dentro de uma worktree):

   ```
   vrdeps
   ```

   Faz `git pull` e religa as junções de `VRNfe`, `VRConnect`, `VRWorkflow` e
   `VRFramework` para o worktree da branch-base detectada (`main` ou `stable-4-4`).

## Dependências locais (VRMaster / VRAutorizador)

Para esses apps, o `vrwork` instala um hook `post-checkout` no repositório criado.
A cada `git checkout` / `git worktree add`, o hook **religa** as junções das
dependências VR locais (em `C:\git\<App>\<Dep>`) apontando para o worktree da
branch-base do worktree atual — assim o Gradle compila contra o fonte local.

- A junção fica no *hub* (`C:\git\<App>`), que não é worktree, então não aparece
  no `git status`. O `settings.gradle` a encontra via `../<Dep>`.
- A base é detectada por `git merge-base` (a base mais específica vence).
- A **atualização** (`git pull`) das dependências é feita **só** pelo comando
  manual `vrdeps`; o hook apenas religa.

## Estrutura

```
.
├── install.ps1        instalador (Windows)
├── install.sh         instalador (Git Bash / WSL)
├── README.md
└── src/               arquivos copiados para C:\git\bin na instalação
    ├── task               comando task (bash)
    ├── task.ps1           lógica do task (Windows)
    ├── task.cmd           atalho do task (PowerShell/cmd)
    ├── repositorio-worktrees.ps1   menu vrwork (Windows) — instala o hook post-checkout
    ├── repositorio-worktrees.sh    menu vrwork (Git Bash / WSL)
    ├── link-deps.ps1      detecta a base e religa (com -Pull) as dependências locais
    ├── vrdeps.cmd         comando vrdeps (PowerShell/cmd): git pull + religa
    └── vrdeps             comando vrdeps (bash)
```

## Requisitos

Git no PATH e chave SSH do GitHub configurada (`git@github.com:vrsoftbr/<Repo>.git`). Windows Terminal opcional, para abrir cada worktree numa aba.

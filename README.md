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
    ├── repositorio-worktrees.ps1   menu vrwork (Windows)
    └── repositorio-worktrees.sh    menu vrwork (Git Bash / WSL)
```

## Requisitos

Git no PATH e chave SSH do GitHub configurada (`git@github.com:vrsoftbr/<Repo>.git`). Windows Terminal opcional, para abrir cada worktree numa aba.

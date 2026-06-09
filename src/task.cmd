@echo off
rem ------------------------------------------------------------------
rem  task.cmd  -  atalho para o comando 'task' em PowerShell/cmd.
rem  Encaminha tudo para o task.ps1 que esta na mesma pasta (no PATH),
rem  onde fica a logica e o menu de selecao de repositorio.
rem
rem  uso:
rem    task <branch>                 checkout de uma branch existente
rem    task <branch-base> <branch>   cria uma branch nova a partir da base
rem ------------------------------------------------------------------
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0task.ps1" %*

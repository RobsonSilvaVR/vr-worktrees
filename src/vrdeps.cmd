@echo off
REM vrdeps - atualiza (git pull) e religa as dependencias VR locais do worktree atual.
REM Detecta o worktree pelo git; se nao estiver num repo, usa o diretorio atual.
setlocal
set "WT="
for /f "delims=" %%i in ('git rev-parse --show-toplevel 2^>nul') do set "WT=%%i"
if not defined WT set "WT=%CD%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0link-deps.ps1" -AppWorktree "%WT%" -Pull %*
endlocal

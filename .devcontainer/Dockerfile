FROM mcr.microsoft.com/vscode/devcontainers/python:3.11

# Zainstaluj Icarus Verilog i narzędzia pomocnicze
RUN apt-get update && apt-get install -y \
    iverilog verilator gtkwave make \
    && rm -rf /var/lib/apt/lists/*

# Domyślny użytkownik
USER vscode
WORKDIR /workspaces

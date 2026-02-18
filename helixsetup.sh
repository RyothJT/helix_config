#!/usr/bin/env bash

# Exit on error
set -e

# --- Configuration ---
LOCAL_BIN="$HOME/.local/bin"
BREW_DIR="$HOME/.linuxbrew"
HELIX_CONFIG_DIR="$HOME/.config/helix"
# Raw URL for your config.toml
GITHUB_CONFIG_URL="https://raw.githubusercontent.com/RyothJT/helix_config/master/config.toml"

mkdir -p "$LOCAL_BIN"
mkdir -p "$HELIX_CONFIG_DIR"

# Function to check if a command exists
is_installed() {
    command -v "$1" >/dev/null 2>&1
}

echo "--- Starting Non-Sudo Setup ---"

# 1. Homebrew Setup
if [ ! -d "$BREW_DIR" ]; then
    echo "[*] Installing Homebrew..."
    mkdir -p "$BREW_DIR"
    curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C "$BREW_DIR"
else
    echo "[✓] Homebrew already exists."
fi

eval "$($BREW_DIR/bin/brew shellenv)"

if ! grep -q "brew shellenv" "$HOME/.bashrc"; then
    echo "[*] Adding Homebrew to .bashrc..."
    echo "eval \"\$($BREW_DIR/bin/brew shellenv)\"" >> "$HOME/.bashrc"
fi

# 2. Helix Installation
if ! is_installed hx; then
    echo "[*] Installing Helix via Brew..."
    brew install helix
else
    echo "[✓] Helix is already installed."
fi

# 3. Verible (Verilog LSP) Setup
if ! is_installed verible-verilog-ls; then
    echo "[*] Installing Verible LSP..."
    VERIBLE_URL="https://github.com/chipsalliance/verible/releases/download/v0.0-4051-g9fdb4057/verible-v0.0-4051-g9fdb4057-linux-static-x86_64.tar.gz"
    curl -Lf "$VERIBLE_URL" -o verible.tar.gz
    tar -xzf verible.tar.gz
    mv verible-*/bin/verible-verilog-ls "$LOCAL_BIN/"
    rm -rf verible.tar.gz verible-*
    chmod +x "$LOCAL_BIN/verible-verilog-ls"
    echo "[✓] Verible LSP installed to $LOCAL_BIN"
fi

# 4. Clangd (C LSP) Setup
if ! is_installed clangd; then
    echo "[*] Installing clangd..."
    CLANGD_URL="https://github.com/clangd/clangd/releases/download/18.1.3/clangd-linux-18.1.3.zip"
    curl -Lf "$CLANGD_URL" -o clangd.zip
    unzip -q clangd.zip
    mv clangd_18.1.3/bin/clangd "$LOCAL_BIN/"
    rm -rf clangd.zip clangd_18.1.3
    chmod +x "$LOCAL_BIN/clangd"
    echo "[✓] clangd installed to $LOCAL_BIN"
fi

# 5. Helix Language Configuration
LANG_CONFIG="$HELIX_CONFIG_DIR/languages.toml"
if [ ! -f "$LANG_CONFIG" ]; then
    echo "[*] Creating Helix languages.toml..."
    cat <<EOF > "$LANG_CONFIG"
[[language]]
name = "c"
auto-format = true
formatter = { command = "clang-format", args = ["-"] }
language-servers = [ "clangd" ]

[language-server.clangd]
command = "clangd"

[[language]]
name = "verilog"
language-servers = [ "verible-verilog-ls" ]

[language-server.verible-verilog-ls]
command = "verible-verilog-ls"
EOF
    echo "[✓] languages.toml created."
fi

# --- NEW: 7. Pull Helix config.toml from GitHub ---
HX_MAIN_CONFIG="$HELIX_CONFIG_DIR/config.toml"
echo "[*] Pulling Helix config from GitHub..."

if [ -f "$HX_MAIN_CONFIG" ]; then
    echo "[!] Existing config.toml found. Backing up to config.toml.bak"
    cp "$HX_MAIN_CONFIG" "${HX_MAIN_CONFIG}.bak"
fi

# Attempt to download the file
if curl -SfL "$GITHUB_CONFIG_URL" -o "$HX_MAIN_CONFIG"; then
    echo "[✓] Helix config.toml successfully updated from GitHub."
else
    echo "[X] Failed to download config.toml. Check if the URL/branch is correct."
fi

# 6. Final Path Check
if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
    echo "[!] Adding $LOCAL_BIN to .bashrc..."
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    export PATH="$HOME/.local/bin:$PATH"
fi

echo "--- Setup Complete! ---"
echo "Please run: source ~/.bashrc"

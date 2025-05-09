#!/bin/bash

set -e

# Konfiguration
WATCOM=~/watcom
ROOT_DIR=~/pcgeos
LOCAL_ROOT=~
BASEBOX_DIR=~/pcgeos-basebox
BASH_PROFILE=~/.bash_profile

# 1. Abhängigkeiten installieren
echo "Detecting distribution and installing required packages..."
if command -v dnf &>/dev/null; then
    # Fedora
    sudo dnf install -y perl sed wget unzip xdotool
elif command -v apt &>/dev/null; then
    # Debian/Ubuntu
    sudo apt update
    sudo apt install -y perl sed wget unzip xdotool
else
    echo "Unsupported distribution. Please install perl, sed, wget, unzip, and xdotool manually."
    exit 1
fi

# 2. Open Watcom installieren
mkdir -p "$WATCOM"
cd ~
if [ ! -d "$WATCOM/binl" ]; then
    echo "Downloading Open Watcom..."
    wget https://github.com/open-watcom/open-watcom-v2/releases/download/2020-12-01-Build/ow-snapshot.tar.gz
    tar -xzf ow-snapshot.tar.gz -C "$WATCOM" --strip-components=1
    rm ow-snapshot.tar.gz
fi

# 3. PC/GEOS klonen
cd ~
if [ ! -d "pcgeos" ]; then
    echo "Cloning PC/GEOS repo..."
    git clone https://github.com/bluewaysw/pcgeos.git
fi

# 4. basebox herunterladen und komplett entpacken
cd ~
if [ ! -d "$BASEBOX_DIR" ]; then
    echo "Downloading pcgeos-basebox..."
    wget https://github.com/bluewaysw/pcgeos-basebox/releases/download/CI-latest-issue-2/pcgeos-basebox.zip
    unzip pcgeos-basebox.zip -d "$BASEBOX_DIR"
    rm pcgeos-basebox.zip
fi

# 5. Umgebungsvariablen in .bash_profile eintragen
echo "Adding environment variables to $BASH_PROFILE..."

add_env_var() {
    local var_name="$1"
    local var_value="$2"
    if ! grep -qxF "export $var_name=$var_value" "$BASH_PROFILE"; then
        echo "export $var_name=$var_value" >> "$BASH_PROFILE"
    fi
}

add_env_var "WATCOM" "$WATCOM"
add_env_var "ROOT_DIR" "$ROOT_DIR"
add_env_var "LOCAL_ROOT" "$LOCAL_ROOT"
add_env_var "BASEBOX" "$BASEBOX_DIR/binl64/basebox"

# PATH-Einträge
if ! grep -qxF 'export PATH=$WATCOM/binl:$ROOT_DIR/bin:$HOME/pcgeos-basebox/binl64:$PATH' "$BASH_PROFILE"; then
    echo 'export PATH=$WATCOM/binl:$ROOT_DIR/bin:$HOME/pcgeos-basebox/binl64:$PATH' >> "$BASH_PROFILE"
fi

echo "Setup complete."
echo "Run 'source ~/.bash_profile' or restart your terminal to apply the environment variables."

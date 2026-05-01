#!/usr/bin/env bash
# ============================================================
# VoiceTag Setup Script
# ============================================================
# Installs whisper.cpp, downloads a Whisper model, and
# creates the default config file.
#
# Usage:
#   chmod +x setup.sh && ./setup.sh
#   ./setup.sh --model large-v3  (to use a bigger model)
#   ./setup.sh --api             (to use OpenAI API instead)
# ============================================================

set -euo pipefail

# ---- Config ------------------------------------------------
VOICETAG_DIR="$HOME/.voicetag"
MODEL="${1:-base.en}"       # default model
WHISPER_CPP_DIR="$VOICETAG_DIR/whisper.cpp"
MODELS_DIR="$VOICETAG_DIR/models"
CONFIG_FILE="$VOICETAG_DIR/config.json"
LOG_FILE="$VOICETAG_DIR/voicetag.log"
USE_API=false

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    --api)   USE_API=true; shift ;;
    *)       shift ;;
  esac
done

# ---- Colors -----------------------------------------------
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${BLUE}[setup]${NC} $1"; }
ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# ---- Banner -----------------------------------------------
echo ""
echo "  ╦  ╦╔═╗╦╔═╗╔═╗╔╦╗╔═╗╔═╗"
echo "  ╚╗╔╝║ ║║║  ║╣  ║ ╠═╣║ ╦"
echo "   ╚╝ ╚═╝╩╚═╝╚═╝ ╩ ╩ ╩╚═╝"
echo "  Voice-Controlled Photo Tagger"
echo ""

# ---- Check requirements -----------------------------------
log "Checking requirements..."

if [[ "$(uname)" != "Darwin" ]]; then
  err "VoiceTag requires macOS"
fi

if ! command -v git &>/dev/null; then
  err "git not found. Install Xcode Command Line Tools: xcode-select --install"
fi

if ! command -v cmake &>/dev/null; then
  warn "cmake not found. Installing via Homebrew..."
  if command -v brew &>/dev/null; then
    brew install cmake
  else
    err "Homebrew not found. Install from https://brew.sh then re-run setup."
  fi
fi

ok "Requirements satisfied"

# ---- Create directories -----------------------------------
log "Creating ~/.voicetag directories..."
mkdir -p "$VOICETAG_DIR" "$MODELS_DIR"
touch "$LOG_FILE"
ok "Directories created"

# ---- whisper.cpp ------------------------------------------
if [[ "$USE_API" == "false" ]]; then
  log "Setting up whisper.cpp..."

  if [[ ! -d "$WHISPER_CPP_DIR" ]]; then
    git clone --depth=1 https://github.com/ggerganov/whisper.cpp.git "$WHISPER_CPP_DIR"
    ok "Cloned whisper.cpp"
  else
    ok "whisper.cpp already cloned"
  fi

  log "Building whisper.cpp (Metal acceleration)..."
  cd "$WHISPER_CPP_DIR"
  cmake -B build -DWHISPER_METAL=ON -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
    -DCMAKE_INSTALL_PREFIX="$VOICETAG_DIR" 2>&1 | tail -5
  cmake --build build -j$(sysctl -n hw.logicalcpu) 2>&1 | tail -10
  ok "whisper.cpp built"

  # Copy binary
  cp "$WHISPER_CPP_DIR/build/bin/whisper-cli" "$VOICETAG_DIR/whisper-cpp" 2>/dev/null || \
  cp "$WHISPER_CPP_DIR/build/bin/main"         "$VOICETAG_DIR/whisper-cpp" 2>/dev/null || true

  if [[ ! -f "$VOICETAG_DIR/whisper-cpp" ]]; then
    warn "Could not locate whisper-cpp binary automatically."
    warn "Check: $WHISPER_CPP_DIR/build/bin/"
  else
    ok "Binary installed: $VOICETAG_DIR/whisper-cpp"
  fi

  # Download model
  MODEL_FILE="$MODELS_DIR/ggml-${MODEL}.bin"
  if [[ ! -f "$MODEL_FILE" ]]; then
    log "Downloading Whisper model: $MODEL (~= 150MB for base.en)..."
    bash "$WHISPER_CPP_DIR/models/download-ggml-model.sh" "$MODEL" "$MODELS_DIR" || \
      curl -L -o "$MODEL_FILE" \
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-${MODEL}.bin"
    ok "Model downloaded: $MODEL_FILE"
  else
    ok "Model already exists: $MODEL_FILE"
  fi

  cd - &>/dev/null
fi

# ---- Config -----------------------------------------------
if [[ ! -f "$CONFIG_FILE" ]]; then
  log "Creating default config..."
  BASE_DIR="$HOME/Pictures/VoiceTagged"
  mkdir -p "$BASE_DIR"

  if [[ "$USE_API" == "true" ]]; then
    WHISPER_MODE="api"
    API_KEY_LINE='"whisperAPIKey": "YOUR_OPENAI_API_KEY",'
  else
    WHISPER_MODE="local"
    API_KEY_LINE=''
  fi

  cat > "$CONFIG_FILE" <<EOF
{
  "baseDirectory": "$BASE_DIR",
  "whisperMode": "$WHISPER_MODE",
  $API_KEY_LINE
  "whisperModel": "$MODEL",
  "skipCommands": ["skip", "next", "pass"],
  "deleteCommands": ["delete", "trash", "remove", "discard"],
  "undoCommands": ["undo", "go back", "revert"],
  "trashFolderName": "Trash_Sorted",
  "tagMappings": {
    "kuari": "Kuari_Pass",
    "not kuari": "Not_Kuari",
    "random": "Random",
    "unsorted": "Unsorted"
  },
  "debugMode": false,
  "logFile": "$LOG_FILE"
}
EOF
  ok "Config written to $CONFIG_FILE"
else
  ok "Config already exists: $CONFIG_FILE"
fi

# ---- Build app --------------------------------------------
log "Building VoiceTag.app..."
cd "$(dirname "$0")"

if command -v swift &>/dev/null; then
  swift build -c release 2>&1 | tail -10
  BIN=".build/release/VoiceTag"
  if [[ -f "$BIN" ]]; then
    ok "Build succeeded: $BIN"
    echo ""
    echo "  Run with:  swift run"
    echo "  Or:        .build/release/VoiceTag"
  fi
else
  warn "swift not found. Open the project in Xcode to build."
fi

# ---- Permissions ------------------------------------------
echo ""
warn "IMPORTANT: Grant Microphone + Accessibility permissions when prompted."
warn "  System Settings → Privacy & Security → Microphone → VoiceTag ✓"
warn "  System Settings → Privacy & Security → Accessibility → VoiceTag ✓"

echo ""
ok "Setup complete!"
echo ""
echo "  Start tagging:  swift run"
echo "  Config file:    $CONFIG_FILE"
echo "  Log file:       $LOG_FILE"
echo ""

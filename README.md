<div align="center">
  <img src="Sources/VoiceTag/Resources/AppIcon.png" width="128" height="128" alt="VoiceTag Icon">
  
  # VoiceTag
  
  **Sort hundreds of photos in minutes — just speak.**
  
  [![macOS](https://img.shields.io/badge/macOS-14%2B-blue)](https://apple.com/macos)
  [![Swift](https://img.shields.io/badge/Swift-5.9-orange)](https://swift.org)
  [![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
  [![Built with Claude](https://img.shields.io/badge/Built%20with-Claude%20AI-blueviolet)](https://claude.ai)
  [![Sarvam AI](https://img.shields.io/badge/Powered%20by-Sarvam%20AI-ff6b35)](https://sarvam.ai)
  [![whisper.cpp](https://img.shields.io/badge/Offline-whisper.cpp-lightgrey)](https://github.com/ggerganov/whisper.cpp)
</div>

---

Ever come back from a trip with 500 photos and dreaded sorting them? VoiceTag lets you blaze through your photo library using just your voice. Hold SPACE, say where the photo belongs, and it moves instantly. No clicking, no dragging, no slow manual renaming.

---

## Demo

```
📂 Open folder with 500 photos from your trek

→ Browse with arrow keys
→ Hold SPACE → say "Kuari Pass Day 2"
→ Release SPACE
→ Photo instantly moves to ~/Pictures/VoiceTagged/Kuari_Pass/Day_2/
→ Next photo loads automatically

Repeat at full speed. Sort 200 photos in 15 minutes.
```

---

## What's New in v1.1

- 🇮🇳 **Sarvam AI support** — best-in-class recognition for Indian languages, accents, and place names (Hampi, Kuari Pass, Puri etc.)
- 🔁 **Three STT backends** — choose between local whisper.cpp, OpenAI API, or Sarvam AI
- 📂 **Recursive folder loading** — opens all images across all subfolders, not just top level
- ↩️ **Smart undo on ← arrow** — press left immediately after tagging to undo and re-tag
- ⚡ **Shift+Space** — repeat last tag instantly without speaking
- 🏷 **Recent tags sidebar** — tap any previously used tag to apply instantly
- 🎙 **Auto mic detection** — automatically finds your MacBook microphone

---

## Features

| Feature | Details |
|---|---|
| 🎙 Voice tagging | Hold SPACE, speak, release — done |
| ⚡ Instant | ~200ms transcription on Apple Silicon |
| 🇮🇳 Indian language support | Sarvam AI handles accents, place names, Hinglish |
| 🔁 Shift+Space | Repeat last tag without speaking |
| ↩️ Smart undo | Press ← right after tagging to undo and re-tag |
| 🏷 Recent tags | Sidebar buttons for quick one-click tagging |
| 📂 Recursive scan | Loads images from all subfolders automatically |
| 📴 Offline option | whisper.cpp works with no internet after setup |
| 🗂 EXIF aware | Shows date taken, camera, GPS in sidebar |
| 📝 Full log | Every action logged to `~/.voicetag/voicetag.log` |

---

## Installation

### Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon (M1/M2/M3) or Intel Mac
- [Homebrew](https://brew.sh)
- Xcode Command Line Tools: `xcode-select --install`

### Step 1 — Install dependencies

```bash
brew install ffmpeg
xcode-select --install
```

### Step 2 — Clone and setup

```bash
git clone https://github.com/zenith0201/voicetag.git
cd voicetag
chmod +x setup.sh
./setup.sh
```

### Step 3 — Build and launch

```bash
chmod +x build.sh
./build.sh
open VoiceTag.app
```

### Step 4 — Grant permissions

When the app opens, grant:
- **Microphone** — System Settings → Privacy & Security → Microphone → VoiceTag ✓
- **Accessibility** (optional) — System Settings → Privacy & Security → Accessibility → VoiceTag ✓

---

## Voice Recognition Backends

VoiceTag supports three backends. Set `whisperMode` in `~/.voicetag/config.json`.

### 🇮🇳 Sarvam AI (Recommended for Indian users)

[Sarvam AI](https://sarvam.ai) is an Indian AI company with state-of-the-art speech recognition for 22 Indian languages. It handles Indian accents, place names, and code-mixed speech far better than generic models.

**Setup:**
1. Get a free API key at [dashboard.sarvam.ai](https://dashboard.sarvam.ai) — starts free with ₹1,000 credits
2. Add to your config:

```json
{
  "whisperMode": "sarvam",
  "sarvamAPIKey": "your-key-here",
  "sarvamLanguage": "en-IN"
}
```

**Supported languages:** `en-IN`, `hi-IN`, `kn-IN`, `ta-IN`, `te-IN`, `ml-IN`, `mr-IN`, `bn-IN`, `gu-IN`, `pa-IN` and more.

**Pricing:** ₹30/hour of audio — sorting 500 photos uses roughly 10 minutes of audio = ~₹5.

---

### 🤖 OpenAI Whisper API

```json
{
  "whisperMode": "api",
  "whisperAPIKey": "sk-your-openai-key"
}
```

---

### 💻 Local whisper.cpp (Offline)

No API key needed. Runs fully offline using Apple Silicon GPU.

```json
{
  "whisperMode": "local",
  "whisperModel": "base.en"
}
```

Available models (run `setup.sh --model <name>` to download):

| Model | Size | Speed | Accuracy |
|---|---|---|---|
| `tiny.en` | 75MB | Fastest | Basic |
| `base.en` | 150MB | Fast | Good |
| `small.en` | 500MB | Medium | Better |
| `medium.en` | 1.5GB | Slower | Best offline |

---

## How to Use

### Keyboard Shortcuts

| Key | Action |
|---|---|
| `← →` | Navigate between images |
| Hold `SPACE` | Start recording voice tag |
| Release `SPACE` | Stop recording and apply tag |
| `Shift + SPACE` | Repeat last tag instantly |
| `←` right after tagging | Undo last tag, re-tag the image |
| `⌘O` | Open a folder |
| `⌘Z` | Undo last action |

### Voice Commands

| Say | What happens |
|---|---|
| `"Kuari Pass Day 2"` | Moves to `Kuari_Pass/Day_2/` |
| `"Hampi"` | Moves to `Hampi/` |
| `"family"` | Moves to `Family/` |
| `"skip"` / `"next"` | Skip, no action |
| `"delete"` / `"trash"` | Move to `Trash_Sorted/` |
| `"undo"` | Undo last move |

### Output Folder Structure

```
~/Pictures/VoiceTagged/
├── Kuari_Pass/
│   ├── Day_1/
│   └── Day_2/
├── Hampi/
├── Family/
├── Landscapes/
├── Trash_Sorted/
└── Unsorted/
```

---

## Configuration

Edit `~/.voicetag/config.json`:

```json
{
  "baseDirectory": "~/Pictures/VoiceTagged",
  "whisperMode": "sarvam",
  "whisperAPIKey": null,
  "sarvamAPIKey": "your-key-here",
  "whisperModel": "base.en",
  "sarvamLanguage": "en-IN",
  "skipCommands": ["skip", "next", "pass"],
  "deleteCommands": ["delete", "trash", "remove"],
  "undoCommands": ["undo", "go back"],
  "trashFolderName": "Trash_Sorted",
  "tagMappings": {
    "hampi": "Hampi",
    "humpy": "Hampi",
    "kuari": "Kuari_Pass",
    "quari": "Kuari_Pass",
    "family": "Family"
  },
  "debugMode": false,
  "logFile": "~/.voicetag/voicetag.log"
}
```

### Tag Mappings

Use `tagMappings` to handle common misrecognitions. The key is what whisper/Sarvam might hear, the value is the correct folder name:

```json
"tagMappings": {
  "humpy": "Hampi",
  "quari": "Kuari_Pass",
  "goa": "Goa"
}
```

---

## Troubleshooting

**Space bar not working?**
Click on the app window first to give it focus.

**Always hears "You" or silence?**
Your mic input might be wrong. Check System Settings → Sound → Input. Also run:
```bash
/opt/homebrew/bin/ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | grep -i micro
```

**App won't open?**
Right-click `VoiceTag.app` → Open → Open (bypasses Gatekeeper for unsigned apps).

**Sarvam API error?**
Check your key at [dashboard.sarvam.ai](https://dashboard.sarvam.ai) and make sure `whisperMode` is set to `"sarvam"` in config.

**Whisper not found?**
Re-run `./setup.sh` — it detects and installs what's missing.

---

## Roadmap

- [ ] First-launch setup wizard (no terminal needed)
- [ ] Bundled ffmpeg (no Homebrew required)
- [ ] Multiple tags per image
- [ ] Sound feedback on tag/undo
- [ ] Session stats (photos sorted, time taken)
- [ ] EXIF auto day-grouping
- [ ] Batch tagging mode
- [ ] Auto-updater

---

## Credits

**Idea & Product** — [Swaroop B Deshpande](https://github.com/zenith0201)

**Built with** — [Claude](https://claude.ai) by Anthropic

**Speech Recognition** — [Sarvam AI](https://sarvam.ai) · [whisper.cpp](https://github.com/ggerganov/whisper.cpp) by Georgi Gerganov · [OpenAI Whisper](https://openai.com/research/whisper)

**Core Technologies** — [ffmpeg](https://ffmpeg.org) · SwiftUI · AVFoundation

---

## License

MIT — see [LICENSE](LICENSE)

---

<div align="center">
  <sub>Made with ❤️ in India — Built for Indian photographers</sub>
</div>

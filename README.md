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
→ Hold SPACE → say "Beach Day 2"
→ Release SPACE
→ Photo instantly moves to ~/Pictures/VoiceTagged/Beach/Day_2/
→ Next photo loads automatically

Repeat at full speed. Sort 200 photos in 15 minutes.
```

---

## What's New

### v1.2
- ✏️ **Tag editor with pencil button** — after transcription, tap ✏️ to fix the tag before applying. All keys (SPACE, arrows) work inside the editor, not as hotkeys
- 📁 **Output folder picker** — change where sorted photos go, right from the sidebar. Persists across sessions
- 🎛 **Model switcher in sidebar** — switch between Sarvam AI, local whisper.cpp, and OpenAI with one tap. No config editing needed

### v1.1
- 🇮🇳 **Sarvam AI** — best-in-class recognition for Indian languages, accents, and place names
- 🔁 **Three STT backends** — Sarvam AI, OpenAI Whisper, local whisper.cpp
- 📂 **Recursive folder loading** — scans all subfolders automatically
- ↩️ **Smart ← undo** — press left arrow right after tagging to undo and re-tag
- ⚡ **Shift+Space** — repeat last tag instantly
- 🏷 **Recent tags sidebar** — one-click to re-apply any previous tag
- 🎙 **Auto mic detection** — finds your MacBook microphone automatically

---

## Features

| Feature | Details |
|---|---|
| 🎙 Voice tagging | Hold SPACE, speak, release — done |
| ✏️ Tag editor | Tap pencil to fix wrong transcription before applying |
| 🇮🇳 Indian language support | Sarvam AI handles accents, place names, Hinglish |
| 🎛 Model switcher | Switch STT backend from the sidebar |
| 📁 Output folder | Choose where photos go, change anytime |
| 🔁 Shift+Space | Repeat last tag without speaking |
| ↩️ Smart undo | Press ← right after tagging to undo and re-tag |
| 🏷 Recent tags | Sidebar buttons for one-click tagging |
| 📂 Recursive scan | Loads images from all subfolders |
| 📴 Offline option | whisper.cpp works with no internet |
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
git clone https://github.com/YOUR_USERNAME/voicetag.git
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

Switch models anytime from the **Voice Model** section in the sidebar.

### 🇮🇳 Sarvam AI (Recommended for Indian users)

[Sarvam AI](https://sarvam.ai) is an Indian AI company with state-of-the-art speech recognition for 22 Indian languages. It handles Indian accents, place names, and code-mixed speech natively.

**Setup:**
1. Get a free API key at [dashboard.sarvam.ai](https://dashboard.sarvam.ai) — starts free with ₹1,000 credits
2. Add to `~/.voicetag/config.json`:

```json
{
  "whisperMode": "sarvam",
  "sarvamAPIKey": "your-key-here",
  "sarvamLanguage": "en-IN"
}
```

**Supported languages:** `en-IN`, `hi-IN`, `kn-IN`, `ta-IN`, `te-IN`, `ml-IN`, `mr-IN`, `bn-IN`, `gu-IN`, `pa-IN` and more.

**Pricing:** ₹30/hour of audio — sorting 500 photos ≈ ₹5.

---

### 💻 Local whisper.cpp (Offline, no API key)

Runs fully offline using Apple Silicon GPU. Set in config or tap in sidebar:

```json
{ "whisperMode": "local", "whisperModel": "base.en" }
```

Available models (download with `setup.sh --model <name>`):

| Model | Size | Accuracy |
|---|---|---|
| `tiny.en` | 75MB | Basic |
| `base.en` | 150MB | Good |
| `small.en` | 500MB | Better |
| `medium.en` | 1.5GB | Best offline |

---

### ☁️ OpenAI Whisper API

```json
{ "whisperMode": "api", "whisperAPIKey": "sk-your-key" }
```

---

## How to Use

### Basic Workflow

1. Open a folder (⌘O or drag-drop)
2. Browse with ← → arrow keys
3. Hold **SPACE**, speak the tag, release
4. Photo moves instantly — next photo loads
5. If the tag was wrong, tap **✏️** in the sidebar to edit and press Enter

### Keyboard Shortcuts

| Key | Action |
|---|---|
| `← →` | Navigate images (disabled in edit mode) |
| Hold `SPACE` | Record voice tag (disabled in edit mode) |
| Release `SPACE` | Stop recording and apply tag |
| `Shift + SPACE` | Repeat last tag instantly |
| `←` right after tagging | Undo last tag, re-tag |
| `⌘O` | Open a folder |
| `⌘Z` | Undo last action |
| `Enter` | Apply edited tag (in edit mode) |
| `Esc` | Dismiss tag editor |

### Voice Commands

| Say | What happens |
|---|---|
| `"Beach Day 2"` | Moves to `Beach/Day_2/` |
| `"Beach"` | Moves to `Beach/` |
| `"family"` | Moves to `Family/` |
| `"skip"` / `"next"` | Skip, no action |
| `"delete"` / `"trash"` | Move to `Trash_Sorted/` |
| `"undo"` | Undo last move |

### Sidebar Controls

| Section | What it does |
|---|---|
| **Status** | Current state + last heard tag with ✏️ edit button |
| **Voice Model** | Switch between Sarvam / Local / OpenAI |
| **Output Folder** | Change where sorted photos are saved |
| **Recent Tags** | Tap any tag to apply it instantly |
| **Current Image** | EXIF metadata (date, camera, GPS) |
| **History** | Last 8 actions with undo button |

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
    "beach": "Beach",
    "beech": "Beach",
    "beach": "Beach",
    "mountains": "Mountains",
    "family": "Family"
  },
  "debugMode": false,
  "logFile": "~/.voicetag/voicetag.log"
}
```

---

## Output Folder Structure

```
~/Pictures/VoiceTagged/     ← configurable from sidebar
├── Beach/
│   ├── Day_1/
│   └── Day_2/
├── Beach/
├── Family/
├── Landscapes/
├── Trash_Sorted/
└── Unsorted/
```

---

## Troubleshooting

**Space bar not working?**
Click on the app window first. If the tag editor is open, close it first (Esc).

**Always hears "You" or silence?**
Run to check mic index:
```bash
/opt/homebrew/bin/ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | grep -i micro
```

**App won't open?**
Right-click `VoiceTag.app` → Open → Open (bypasses Gatekeeper).

**Sarvam API not working?**
Check your key at [dashboard.sarvam.ai](https://dashboard.sarvam.ai). Tap the model selector in sidebar and reselect Sarvam to re-apply.

**Whisper not found?**
Re-run `./setup.sh` to reinstall.

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
**instagram** - (https://www.instagram.com/the_deshpande_?igsh=ajZlMWRicDJlOWV0&utm_source=qr)


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

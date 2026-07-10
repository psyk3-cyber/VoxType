# VoxType

Free, open-source voice typing for macOS: hold a key, speak, and polished text appears in whatever app you're using. Menu-bar only, works in every text field on your Mac. Inspired by [Wispr Flow](https://wisprflow.ai) — no account, no subscription, private by design.

**Website:** https://psyk3.com · **Download DMG:** [latest release](https://github.com/psyk3-cyber/VoxType/releases/latest)

> **First launch (DMG users):** VoxType isn't notarized, so macOS says it "could not verify VoxType is free of malware". Click **Done**, then open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** (once). Or run `xattr -dr com.apple.quarantine /Applications/VoxType.app`.

## Build from source

```bash
cd VoxType
./build_app.sh
mv -f build/VoxType.app /Applications/
open /Applications/VoxType.app
```

Requires macOS 13+ and Xcode (or Command Line Tools: `xcode-select --install`).

## First-run setup

The setup window walks you through three permissions:

1. **Microphone** — capture your voice
2. **Speech Recognition** — Apple's transcription engine
3. **Accessibility** — global fn-key detection + pasting text into other apps

Also set **System Settings → Keyboard → "Press 🌐 key to" → Do Nothing** so fn is reserved for dictation (Wispr Flow requires this too).

> After granting Accessibility, if the hotkey doesn't respond within a few seconds, quit and relaunch the app. If you rebuild the app, re-toggle its Accessibility checkbox (the ad-hoc signature changes).

## How to use

| Action | Gesture |
|---|---|
| Dictate (push-to-talk) | **Hold fn**, speak, release — text is inserted at your cursor |
| Hands-free dictation | **Double-tap fn** to start, tap fn to finish (20-min cap) |
| Command Mode | **Hold fn + ⌃ Control**, speak an instruction |
| Prompt Mode | **Hold fn + ⌥ Option**, talk through your idea naturally |
| Cancel | **Esc** while recording |
| Press Enter by voice | End your dictation with *"press enter"* |

**Command Mode** (requires an OpenAI API key in Settings → AI): highlight text and say "make this more concise" / "translate to Spanish" / "turn this into bullet points" — the selection is replaced. With nothing selected, your answer is generated inline at the cursor.

**Prompt Mode** (free, no API key needed): ramble naturally about what you want and VoxType rewrites it into a clear, structured AI prompt before inserting it — perfect for ChatGPT, Claude, or Cursor. On macOS 26+ with Apple Intelligence it uses Apple's free on-device model (private, offline). Otherwise it falls back to your OpenAI key if set, or a local formatter.

## Features

- **Works everywhere** — inserts text via paste into any app (Mail, Notion, Slack, Cursor, browsers…), then restores your clipboard
- **Live HUD** — floating pill with waveform + real-time transcript while you speak
- **Auto-polish (local, free)** — removes filler words (um, uh…), auto-punctuates, capitalizes sentences
- **AI Auto-Edits (optional)** — with an OpenAI key, every dictation is rewritten by an LLM: false starts and self-corrections ("no wait, make that Tuesday") are cleaned up, lists get formatted
- **Personal dictionary** — add names/jargon; they bias recognition and enforce exact spelling
- **Snippets** — say a cue phrase ("calendar link") and it expands to full text
- **100+ languages** — pick in Settings, or leave on Automatic
- **On-device option** — prefer private, offline transcription (enable the dictation model in System Settings → Keyboard → Dictation)
- **History** — last 200 dictations with copy buttons (stored locally)
- **Sounds, launch-at-login, alternate trigger keys** (right ⌘ / right ⌥ for external keyboards without a real fn key — same workaround Wispr documents)

## Architecture

| File | Role |
|---|---|
| `main.swift` | App bootstrap (menu-bar-only accessory app) |
| `HotkeyManager.swift` | CGEvent tap: fn hold / double-tap / +Ctrl / +Option / Esc gestures |
| `DictationController.swift` | State machine: record → transcribe → polish → insert |
| `TranscriptionService.swift` | AVAudioEngine + SFSpeechRecognizer streaming |
| `TextPolisher.swift` | Local cleanup: fillers, dictionary, snippets, "press enter" |
| `LLMService.swift` | OpenAI client for AI Auto-Edits + Command Mode |
| `PromptComposer.swift` | Prompt Mode: Apple on-device model → OpenAI → rule-based |
| `TextInserter.swift` | Clipboard-paste insertion with clipboard restore |
| `OverlayHUD.swift` | Floating waveform/transcript pill (SwiftUI in NSPanel) |
| `StatusBarController.swift` | Menu bar item + menu |
| `SettingsView.swift` | Settings window (General/Polish/Dictionary/Snippets/AI/History) |
| `OnboardingView.swift`, `Permissions.swift` | Permission checklist |

## Privacy

Transcription uses Apple's speech engine (optionally fully on-device). Nothing leaves your Mac unless you enable AI features with your own OpenAI key. Settings and history live in `~/Library/Application Support/VoxType/`.

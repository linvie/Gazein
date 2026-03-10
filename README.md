# Gazein

> Gaze into any GUI. Extract the data within.

A lightweight pipeline framework that turns any desktop app into a structured data source, without APIs.

## Features

- **Configuration-driven**: Different scenarios = different JSON files, no code changes
- **Pipeline architecture**: Modular design with replaceable components
- **Native macOS**: Built with Swift, Vision Framework, ScreenCaptureKit
- **AI-powered**: Offline batch processing with Claude API

## Architecture

```
[Trigger] → [Capture] → [Extractor] → [Writer]
                                          ↓
                                      SQLite DB
                                          ↓
                              [Processor] → [Exporter]
                            (offline batch, manual trigger)
```

## Requirements

- macOS 14+
- Xcode 15+ / Swift 5.9+
- Permissions: Accessibility, Screen Recording

## Installation

```bash
git clone https://github.com/your-username/Gazein.git
cd Gazein
swift build
```

## Usage

1. Launch the app (menu bar icon appears)
2. Select "Choose Region" → drag to select target area
3. Select "Set Key" → press the key to simulate
4. Choose a profile and start collection
5. Run batch processing when done
6. Export results to CSV

## Configuration

Profiles are stored in `~/.gazein/profiles/`. Example:

```json
{
  "profile_name": "Recruitment Screening",
  "trigger": {
    "type": "key_simulation",
    "key": "arrow_down",
    "interval_ms": 1200
  },
  "capture": {
    "region": { "x": 820, "y": 120, "width": 600, "height": 400 }
  },
  "extractor": {
    "type": "vision_ocr",
    "languages": ["zh-Hans", "en"]
  }
}
```

## Use Cases

- Recruitment platform candidate screening
- Legacy system data migration
- Content collection from apps without APIs
- Monitoring area content changes

## License

MIT

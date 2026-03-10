# Gazein

> Gaze into any GUI. Extract the data within.

A lightweight pipeline framework that transforms any desktop application without APIs into structured, consumable data.

## Features

- **Configuration-driven**: Different scenarios = different JSON configs, no code changes needed
- **Pipeline architecture**: Modular design with replaceable components
- **Native macOS**: Built with Swift, Vision Framework, and ScreenCaptureKit
- **Multi-AI support**: Supports DeepSeek, Kimi (Moonshot), OpenAI, and more
- **Data isolation**: Each profile has its own data directory
- **Setup wizard**: Guided flow for quick configuration creation

## Architecture

```
[Trigger] → [Capture] → [Extractor] → [Writer]
     ↓           ↓                        ↓
Key Simulation  Screenshot → OCR      SQLite DB
                                          ↓
                              [Processor] → [Exporter]
                            (AI Batch)      (CSV Export)
```

## Requirements

- macOS 14+
- Xcode 15+ / Swift 5.9+
- Permissions: Accessibility (key simulation), Screen Recording (screenshots)

## Installation

```bash
git clone https://github.com/linvie/Gazein.git
cd Gazein
swift build
swift run
```

### Build as App Bundle

```bash
swift build -c release
mkdir -p Gazein.app/Contents/MacOS
cp .build/release/Gazein Gazein.app/Contents/MacOS/
cp -r Resources/AppIcon.icns Gazein.app/Contents/Resources/
```

## Quick Start

### 1. Set up AI API Key

Set the environment variable for your chosen AI service:

```bash
# DeepSeek
export DEEPSEEK_API_KEY="sk-xxx"

# Kimi (Moonshot)
export MOONSHOT_API_KEY="sk-xxx"

# OpenAI
export OPENAI_API_KEY="sk-xxx"
```

Add to `~/.zshrc` or `~/.bashrc` for persistence.

### 2. Launch the App

```bash
swift run
```

The Gazein icon will appear in the menu bar.

### 3. Create a Profile

Two options:

**Option 1: Setup Wizard (Recommended)**
1. Click menu → "Setup Wizard"
2. Drag to select screen region
3. Press the trigger key
4. Profile is automatically generated

**Option 2: Manual Creation**
1. Create a JSON file in `~/.gazein/profiles/`
2. Refer to the configuration examples below

### 4. Start Collection

1. Select a profile
2. Click "Start Collection"
3. The app will automatically capture screenshots, perform OCR, and save to database
4. Click "Stop Collection" to end

### 5. AI Batch Processing

1. Click "Batch Process (AI)"
2. Select profile and processing mode
3. AI analyzes OCR results and generates structured data

### 6. Export Data

- "Export OCR Results" - Export raw OCR text
- "Export AI Results" - Export AI-processed structured data

## Configuration

Profiles are stored in `~/.gazein/profiles/` as JSON files.

### Full Configuration Example

```json
{
  "profile_name": "my_profile",
  "trigger": {
    "type": "key_simulation",
    "key": "arrow_down",
    "interval_ms": 2000,
    "jitter_ms": 500
  },
  "capture": {
    "region": {
      "x": 100,
      "y": 200,
      "width": 800,
      "height": 400
    },
    "change_threshold": 0.05,
    "save_screenshot": true
  },
  "extractor": {
    "type": "vision_ocr",
    "languages": ["zh-Hans", "en"]
  },
  "writer": {
    "type": "sqlite",
    "db_path": null,
    "screenshot_dir": null
  },
  "processor": {
    "provider": "deepseek",
    "model": "deepseek-chat",
    "system_prompt": "Your AI processing instructions...",
    "output_fields": ["name", "summary", "passed", "reason"]
  }
}
```

### Configuration Reference

#### trigger

| Field | Description | Example |
|-------|-------------|---------|
| type | Trigger type | `key_simulation` |
| key | Simulated key | `arrow_down`, `arrow_up`, `space`, `return` |
| interval_ms | Interval in milliseconds | `2000` |
| jitter_ms | Random jitter in milliseconds | `500` |

#### capture

| Field | Description | Example |
|-------|-------------|---------|
| region | Screenshot region coordinates | `{"x": 100, "y": 200, "width": 800, "height": 600}` |
| change_threshold | Change detection threshold | `0.05` (5%) |
| save_screenshot | Whether to save screenshots | `true` |

#### extractor

| Field | Description | Example |
|-------|-------------|---------|
| type | Extractor type | `vision_ocr` |
| languages | Recognition languages | `["zh-Hans", "en"]` |

#### processor

| Field | Description | Example |
|-------|-------------|---------|
| provider | AI provider | `deepseek`, `kimi`, `moonshot`, `openai` |
| model | Model name | See supported models below |
| system_prompt | System prompt | AI processing instructions |
| output_fields | Output fields | `["name", "summary", "passed"]` |

## Supported AI Services

### DeepSeek

```json
{
  "provider": "deepseek",
  "model": "deepseek-chat"
}
```

Environment variable: `DEEPSEEK_API_KEY`

API endpoint: `https://api.deepseek.com/v1/chat/completions`

### Kimi (Moonshot)

```json
{
  "provider": "kimi",
  "model": "moonshot-v1-8k"
}
```

Or use the latest k2 series:

```json
{
  "provider": "kimi",
  "model": "kimi-k2.5"
}
```

Environment variable: `MOONSHOT_API_KEY`

API endpoint: `https://api.moonshot.cn/v1/chat/completions`

Available models:
- `moonshot-v1-8k` - Standard model
- `moonshot-v1-32k` - Long context
- `moonshot-v1-128k` - Extra long context
- `kimi-k2.5` - Latest k2 series

### OpenAI

```json
{
  "provider": "openai",
  "model": "gpt-4o-mini"
}
```

Environment variable: `OPENAI_API_KEY`

API endpoint: `https://api.openai.com/v1/chat/completions`

Available models:
- `gpt-4o-mini` - Recommended, cost-effective
- `gpt-4o` - More capable
- `gpt-4-turbo` - Legacy
- `gpt-3.5-turbo` - Budget-friendly

## Data Directory Structure

Each profile stores data independently in `~/Gazein/{profile_name}/`:

```
~/Gazein/
├── profile_a/
│   ├── data.db           # SQLite database
│   └── screenshots/      # Screenshot files
├── profile_b/
│   ├── data.db
│   └── screenshots/
└── ...
```

### Direct Database Access

```bash
# Command line access
sqlite3 ~/Gazein/my_profile/data.db

# Common commands
.tables                          # List all tables
SELECT * FROM captures;          # View captured data
SELECT * FROM results;           # View AI results
DELETE FROM results WHERE id=5;  # Delete specific record
DELETE FROM results;             # Clear all AI results
```

Recommended GUI tool:
```bash
brew install --cask db-browser-for-sqlite
```

## Use Case Examples

### Information Screening

```json
{
  "profile_name": "screening",
  "processor": {
    "provider": "deepseek",
    "model": "deepseek-chat",
    "system_prompt": "Analyze the following information and determine if it meets the criteria.\n\nOutput JSON format:\n{\n  \"name\": \"Name\",\n  \"category\": \"Category\",\n  \"passed\": true or false,\n  \"reason\": \"Judgment reason\"\n}",
    "output_fields": ["name", "category", "passed", "reason"]
  }
}
```

### Data Scraping

```json
{
  "profile_name": "scraper",
  "processor": {
    "provider": "deepseek",
    "model": "deepseek-chat",
    "system_prompt": "Extract structured data from the following text, output JSON format:\n{\n  \"title\": \"Title\",\n  \"price\": \"Price\",\n  \"description\": \"Description\"\n}",
    "output_fields": ["title", "price", "description"]
  }
}
```

## Error Handling

### API Rate Limiting (429 Error)

Built-in automatic retry mechanism:
- Retries on 429 or 5xx errors
- Retry intervals: 5s → 10s → 15s
- Maximum 3 retries

### FAQ

**Q: Black screenshot?**
A: Check Screen Recording permission in System Settings → Privacy & Security → Screen Recording

**Q: Key simulation not working?**
A: Check Accessibility permission in System Settings → Privacy & Security → Accessibility

**Q: AI processing failed?**
A: Verify environment variables are set correctly and API key is valid

## Development

```bash
# Build
swift build

# Run
swift run

# Test
swift test

# Clean
swift package clean
```

## License

MIT

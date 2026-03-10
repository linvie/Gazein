# Gazein

> Gaze into any GUI. Extract the data within.

一个轻量级管道框架，将任意无 API 的桌面软件转化为可被程序消费的结构化数据。

## 功能特点

- **配置驱动**: 不同场景 = 不同 JSON 配置文件，无需改动代码
- **管道架构**: 模块化设计，组件可替换
- **原生 macOS**: 使用 Swift、Vision Framework、ScreenCaptureKit 构建
- **多 AI 支持**: 支持 DeepSeek、Kimi (Moonshot)、OpenAI 等多种 AI 服务
- **数据隔离**: 每个配置独立数据目录，互不干扰
- **配置向导**: 快速创建新配置的引导流程

## 架构

```
[Trigger] → [Capture] → [Extractor] → [Writer]
     ↓           ↓                        ↓
  按键模拟    屏幕截图 → OCR           SQLite DB
                                          ↓
                              [Processor] → [Exporter]
                            (AI 批处理)      (CSV 导出)
```

## 系统要求

- macOS 14+
- Xcode 15+ / Swift 5.9+
- 权限: Accessibility (按键模拟), Screen Recording (屏幕截图)

## 安装

```bash
git clone https://github.com/your-username/Gazein.git
cd Gazein
swift build
swift run
```

## 快速开始

### 1. 设置 AI API Key

根据你使用的 AI 服务，设置对应的环境变量:

```bash
# DeepSeek
export DEEPSEEK_API_KEY="sk-xxx"

# Kimi (Moonshot)
export MOONSHOT_API_KEY="sk-xxx"

# OpenAI
export OPENAI_API_KEY="sk-xxx"
```

建议添加到 `~/.zshrc` 或 `~/.bashrc` 中永久生效。

### 2. 启动应用

```bash
swift run
```

菜单栏会出现 Gazein 图标。

### 3. 创建配置

两种方式:

**方式一: 配置向导 (推荐)**
1. 点击菜单 → "配置向导"
2. 拖拽选择屏幕区域
3. 按下触发按键
4. 自动生成配置文件

**方式二: 手动创建**
1. 在 `~/.gazein/profiles/` 目录创建 JSON 文件
2. 参考下方配置示例

### 4. 开始采集

1. 选择配置文件
2. 点击 "开始采集"
3. 应用会自动截图 + OCR 并保存到数据库
4. 点击 "停止采集" 结束

### 5. AI 批处理

1. 点击 "AI 批处理"
2. 选择配置和处理模式
3. AI 会分析 OCR 结果并生成结构化数据

### 6. 导出数据

- "导出 OCR 数据" - 导出原始 OCR 文本
- "导出 AI 结果" - 导出 AI 处理后的结构化数据

## 配置文件

配置文件位于 `~/.gazein/profiles/`，格式为 JSON。

### 完整配置示例

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
    "system_prompt": "你的 AI 处理指令...",
    "output_fields": ["name", "summary", "passed", "reason"]
  }
}
```

### 配置项说明

#### trigger (触发器)

| 字段 | 说明 | 示例 |
|------|------|------|
| type | 触发类型 | `key_simulation` |
| key | 模拟按键 | `arrow_down`, `arrow_up`, `space`, `return` |
| interval_ms | 间隔时间 (毫秒) | `2000` |
| jitter_ms | 随机抖动 (毫秒) | `500` |

#### capture (截图)

| 字段 | 说明 | 示例 |
|------|------|------|
| region | 截图区域坐标 | `{"x": 100, "y": 200, "width": 800, "height": 600}` |
| change_threshold | 变化检测阈值 | `0.05` (5%) |
| save_screenshot | 是否保存截图 | `true` |

#### extractor (OCR)

| 字段 | 说明 | 示例 |
|------|------|------|
| type | 提取器类型 | `vision_ocr` |
| languages | 识别语言 | `["zh-Hans", "en"]` |

#### processor (AI 处理)

| 字段 | 说明 | 示例 |
|------|------|------|
| provider | AI 服务商 | `deepseek`, `kimi`, `moonshot`, `openai` |
| model | 模型名称 | 见下方支持的模型列表 |
| system_prompt | 系统提示词 | AI 处理指令 |
| output_fields | 输出字段 | `["name", "summary", "passed"]` |

## 支持的 AI 服务

### DeepSeek

```json
{
  "provider": "deepseek",
  "model": "deepseek-chat"
}
```

环境变量: `DEEPSEEK_API_KEY`

API 端点: `https://api.deepseek.com/v1/chat/completions`

### Kimi (Moonshot)

```json
{
  "provider": "kimi",
  "model": "moonshot-v1-8k"
}
```

或使用最新的 k2 系列模型:

```json
{
  "provider": "kimi",
  "model": "kimi-k2.5"
}
```

环境变量: `MOONSHOT_API_KEY`

API 端点: `https://api.moonshot.cn/v1/chat/completions`

可用模型:
- `moonshot-v1-8k` - 标准模型
- `moonshot-v1-32k` - 长上下文
- `moonshot-v1-128k` - 超长上下文
- `kimi-k2.5` - 最新 k2 系列

### OpenAI

```json
{
  "provider": "openai",
  "model": "gpt-4o-mini"
}
```

环境变量: `OPENAI_API_KEY`

API 端点: `https://api.openai.com/v1/chat/completions`

可用模型:
- `gpt-4o-mini` - 推荐，性价比高
- `gpt-4o` - 更强能力
- `gpt-4-turbo` - 旧版本
- `gpt-3.5-turbo` - 经济实惠

## 数据目录结构

每个配置的数据独立存储在 `~/Gazein/{profile_name}/`:

```
~/Gazein/
├── profile_a/
│   ├── gazein.db         # SQLite 数据库
│   └── screenshots/      # 截图文件
├── profile_b/
│   ├── gazein.db
│   └── screenshots/
└── ...
```

## 使用场景示例

### 信息筛选

```json
{
  "profile_name": "screening",
  "processor": {
    "provider": "deepseek",
    "model": "deepseek-chat",
    "system_prompt": "分析以下信息，判断是否符合条件。\n\n输出 JSON 格式:\n{\n  \"name\": \"名称\",\n  \"category\": \"分类\",\n  \"passed\": true或false,\n  \"reason\": \"判断理由\"\n}",
    "output_fields": ["name", "category", "passed", "reason"]
  }
}
```

### 数据抓取

```json
{
  "profile_name": "scraper",
  "processor": {
    "provider": "deepseek",
    "model": "deepseek-chat",
    "system_prompt": "从以下文本中提取结构化数据，输出 JSON 格式:\n{\n  \"title\": \"标题\",\n  \"price\": \"价格\",\n  \"description\": \"描述\"\n}",
    "output_fields": ["title", "price", "description"]
  }
}
```

## 错误处理

### API 限流 (429 错误)

应用内置自动重试机制:
- 遇到 429 或 5xx 错误时自动重试
- 重试间隔: 5s → 10s → 15s
- 最多重试 3 次

### 常见问题

**Q: 截图黑屏?**
A: 检查 Screen Recording 权限，在系统设置 → 隐私与安全性 → 屏幕录制 中授权

**Q: 按键模拟无效?**
A: 检查 Accessibility 权限，在系统设置 → 隐私与安全性 → 辅助功能 中授权

**Q: AI 处理失败?**
A: 检查环境变量是否正确设置，API Key 是否有效

## 开发

```bash
# 构建
swift build

# 运行
swift run

# 测试
swift test

# 清理
swift package clean
```

## License

MIT

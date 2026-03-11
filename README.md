# Gazein

> Gaze into any GUI. Extract the data within.
>
> 凝视任意界面，提取其中数据。

一个轻量级管道框架，将任意无 API 的桌面软件转化为可被程序消费的结构化数据。

A lightweight pipeline framework that transforms any desktop application without APIs into structured, consumable data.

## 功能特性 / Features

- **配置驱动**: 不同场景 = 不同 JSON 配置，无需修改代码
- **管道架构**: 模块化设计，组件可替换
- **原生 macOS**: 基于 Swift、Vision Framework、ScreenCaptureKit 构建
- **多 AI 支持**: 支持 DeepSeek、Kimi (Moonshot)、OpenAI 等
- **数据隔离**: 每个配置独立的数据目录
- **配置向导**: 引导式流程快速创建配置
- **数据管理**: 支持数据归档和清空，归档数据可恢复

## 架构 / Architecture

```
[Trigger] → [Capture] → [Extractor] → [Writer]
     ↓           ↓                        ↓
按键模拟      截图 → OCR              SQLite DB
                                          ↓
                              [Processor] → [Exporter]
                              (AI 批处理)    (CSV 导出)
```

## 环境要求 / Requirements

- macOS 14+
- Xcode 15+ / Swift 5.9+
- 权限: 辅助功能 (按键模拟)、屏幕录制 (截图)

## 安装 / Installation

```bash
git clone https://github.com/linvie/Gazein.git
cd Gazein
swift build
swift run
```

### 构建为 App Bundle

```bash
./Scripts/build-app.sh
# 输出: build/Gazein.app

# 复制到应用程序文件夹
cp -R build/Gazein.app /Applications/
```

## 快速开始 / Quick Start

### 1. 设置 AI API Key

**方式一: 应用内配置 (推荐)**

1. 启动应用后，点击菜单 → "配置 API Key..."
2. 在打开的 `secrets.json` 文件中填入你的 API Key：

```json
{
  "DEEPSEEK_API_KEY": "sk-xxx",
  "MOONSHOT_API_KEY": "",
  "OPENAI_API_KEY": ""
}
```

3. 保存文件即可

**方式二: 环境变量**

```bash
# DeepSeek (推荐，性价比高)
export DEEPSEEK_API_KEY="sk-xxx"

# Kimi (Moonshot)
export MOONSHOT_API_KEY="sk-xxx"

# OpenAI
export OPENAI_API_KEY="sk-xxx"
```

添加到 `~/.zshrc` 或 `~/.bashrc` 以持久化。

> 注: 应用会优先读取环境变量，其次读取 `~/.gazein/secrets.json`

### 2. 启动应用

```bash
swift run
# 或
open /Applications/Gazein.app
```

Gazein 图标将出现在菜单栏。

### 3. 创建配置

两种方式:

**方式一: 配置向导 (推荐)**
1. 点击菜单 → "开始配置..."
2. 拖拽选择截图区域
3. 按下触发按键
4. 配置自动生成

**方式二: 手动创建**
1. 在 `~/.gazein/profiles/` 创建 JSON 文件
2. 参考下方配置示例

### 4. 开始采集

1. 选择配置
2. 点击 "开始采集"
3. 应用将自动截图、OCR、保存到数据库
4. 点击 "停止采集" 结束

### 5. AI 批量处理

1. 点击 "批量处理 (AI)..."
2. 选择配置和处理模式
3. AI 分析 OCR 结果并生成结构化数据

### 6. 导出数据

- "导出 OCR 结果" - 导出原始 OCR 文本
- "导出 AI 结果" - 导出 AI 处理后的结构化数据

### 7. 数据清理

点击 "清理数据..." 可以:

- **归档数据**: 数据保留在数据库，但不出现在导出和后续处理中
- **清空数据**: 永久删除所有数据（可选择先导出）

## 配置说明 / Configuration

配置目录结构：

```
~/.gazein/
├── profiles/           # 场景配置 (可分享)
│   ├── resume.json
│   └── scraper.json
└── secrets.json        # API Keys (不要分享)
```

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

### 配置项参考

#### trigger (触发器)

| 字段 | 说明 | 示例 |
|-----|------|-----|
| type | 触发类型 | `key_simulation` |
| key | 模拟按键 | `arrow_down`, `arrow_up`, `space`, `return` |
| interval_ms | 间隔毫秒 | `2000` |
| jitter_ms | 随机抖动毫秒 | `500` |

#### capture (截图)

| 字段 | 说明 | 示例 |
|-----|------|-----|
| region | 截图区域坐标 | `{"x": 100, "y": 200, "width": 800, "height": 600}` |
| change_threshold | 变化检测阈值 | `0.05` (5%) |
| save_screenshot | 是否保存截图 | `true` |

#### extractor (提取器)

| 字段 | 说明 | 示例 |
|-----|------|-----|
| type | 提取器类型 | `vision_ocr` |
| languages | 识别语言 | `["zh-Hans", "en"]` |

#### processor (处理器)

| 字段 | 说明 | 示例 |
|-----|------|-----|
| provider | AI 服务商 | `deepseek`, `kimi`, `moonshot`, `openai` |
| model | 模型名称 | 见下方支持的模型 |
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

### Kimi (Moonshot)

```json
{
  "provider": "kimi",
  "model": "moonshot-v1-8k"
}
```

或使用最新的 k2 系列:

```json
{
  "provider": "kimi",
  "model": "kimi-k2.5"
}
```

环境变量: `MOONSHOT_API_KEY`

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

可用模型:
- `gpt-4o-mini` - 推荐，性价比高
- `gpt-4o` - 更强能力
- `gpt-4-turbo` - 旧版
- `gpt-3.5-turbo` - 经济型

## 数据目录结构

每个配置的数据独立存储在 `~/Gazein/{配置名}/`:

```
~/Gazein/
├── profile_a/
│   ├── data.db           # SQLite 数据库
│   ├── screenshots/      # 截图文件
│   └── exports/          # 导出文件
├── profile_b/
│   ├── data.db
│   ├── screenshots/
│   └── exports/
└── ...
```

### 直接访问数据库

```bash
# 命令行访问
sqlite3 ~/Gazein/my_profile/data.db

# 常用命令
.tables                          # 列出所有表
SELECT * FROM captures;          # 查看采集数据
SELECT * FROM results;           # 查看 AI 结果
```

推荐 GUI 工具:
```bash
brew install --cask db-browser-for-sqlite
```

### 恢复归档数据

归档的数据不会被删除，只是标记为 `archived = 1`。如需恢复，可直接操作数据库:

```sql
-- 查看归档数据
SELECT * FROM captures WHERE archived = 1;
SELECT * FROM results WHERE archived = 1;

-- 恢复所有归档数据
UPDATE captures SET archived = 0 WHERE archived = 1;
UPDATE results SET archived = 0 WHERE archived = 1;

-- 恢复指定时间段的数据
UPDATE captures SET archived = 0
WHERE archived = 1 AND captured_at > '2024-01-01';
```

## 使用场景示例

### 信息筛选

```json
{
  "profile_name": "screening",
  "processor": {
    "provider": "deepseek",
    "model": "deepseek-chat",
    "system_prompt": "分析以下信息，判断是否符合条件。\n\n输出 JSON 格式:\n{\n  \"name\": \"名称\",\n  \"category\": \"类别\",\n  \"passed\": true 或 false,\n  \"reason\": \"判断原因\"\n}",
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
    "system_prompt": "从以下文本提取结构化数据，输出 JSON 格式:\n{\n  \"title\": \"标题\",\n  \"price\": \"价格\",\n  \"description\": \"描述\"\n}",
    "output_fields": ["title", "price", "description"]
  }
}
```

## 错误处理

### API 限流 (429 错误)

内置自动重试机制:
- 遇到 429 或 5xx 错误自动重试
- 重试间隔: 5s → 10s → 15s
- 最多重试 3 次

### 常见问题

**Q: 截图全黑?**
A: 检查屏幕录制权限: 系统设置 → 隐私与安全 → 屏幕录制

**Q: 按键模拟无效?**
A: 检查辅助功能权限: 系统设置 → 隐私与安全 → 辅助功能

**Q: AI 处理失败?**
A: 点击菜单 "配置 API Key..." 确认 API Key 已正确填写

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

# 打包 App
./Scripts/build-app.sh
```

## 许可证 / License

MIT

# Gazein

> Gaze into any GUI. Extract the data within.

一个轻量级管道框架，将任意无 API 的桌面软件转化为可被程序消费的结构化数据。

## 项目概述

- **语言**: Swift
- **平台**: macOS 12.3+
- **架构**: 配置驱动的管道模型

## 核心管道

```
[Trigger] → [Capture] → [Extractor] → [Writer] → SQLite → [Processor] → [Exporter]
```

## 目录结构

```
Gazein/
├── App/           # 入口，菜单栏应用
├── Core/          # Protocol 定义，管道调度
├── Modules/       # 各模块实现
│   ├── Trigger/   # 触发器 (按键模拟/定时器)
│   ├── Capture/   # 截图捕获
│   ├── Extractor/ # OCR 提取
│   ├── Writer/    # 数据写入
│   └── Processor/ # AI 批处理
├── Storage/       # 数据库封装
├── Config/        # 配置加载
│   └── Profiles/  # 场景配置模板
├── UI/            # 区域选择、按键捕获等 UI
└── Export/        # 数据导出
```

## 技术栈

| 模块 | 技术 |
|------|------|
| 截图 | ScreenCaptureKit |
| OCR | Vision Framework |
| 模拟操作 | CGEvent |
| 变化检测 | 像素哈希对比 |
| 存储 | SQLite + GRDB.swift |
| AI | Anthropic Claude API |
| 配置 | JSON |

## 开发规范

- 使用 Swift Concurrency (async/await)
- 所有模块遵循 Protocol 定义
- 配置文件路径: `~/.gazein/profiles/`
- 数据存储路径: `~/Gazein/`

## 权限要求

- **Accessibility**: CGEvent 模拟按键
- **Screen Recording**: ScreenCaptureKit 截图

## 构建与运行

```bash
# 使用 Swift Package Manager
swift build
swift run

# 或使用 Xcode 打开 Package.swift
```

## 常用命令

```bash
# 运行测试
swift test

# 清理构建
swift package clean
```

# Zoosy - 主动思考记录

> "Zoosy"取自"主思"的谐音，意为**主动思考**。在信息爆炸的时代，帮助你建立独立思考的闭环习惯。

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)
![License](https://img.shields.io/badge/License-MIT-green)
[![Version](https://img.shields.io/badge/version-1.13.7-blue)](https://github.com/hwt3202958058-arch/zoosy)

</div>

## 功能特性

### 核心功能
- **思考记录** - 标题、内容、标签、图片（最多9张），自动生成时间戳
- **日历视图** - 周历组件，左右滑动切换周，点击日期筛选当日思考
- **全部思考** - 按日期分组，时间倒序展示所有记录
- **思考详情** - AI 摘要、收藏、分享（文字/图片）、图片全屏浏览
- **搜索** - 关键词 + 标签联合筛选，支持搜索历史

### 智能功能
- **AI 摘要** - 自动生成思考反思总结
- **语音输入** - 语音转文字，快速记录想法
- **桌面小组件** - 实时显示思考统计、最近记录
- **智能推送** - 温馨的思考邀请，而非打扰式通知

### 工具功能
- **数据备份/恢复** - 本地数据安全存储
- **多语言** - 中文、英文、繁体、日韩等 9 种语言
- **深色模式** - 跟随系统或手动切换
- **主题定制** - 多种主题色可选
- **权限管理** - 精细化权限控制

## 技术架构

```
lib/
  main.dart              # 应用入口
  config.dart            # 应用配置
  models/                # 数据模型
    reflection.dart      # 思考记录模型
  screens/               # 界面（按功能模块分类）
    auth/                # 认证相关
    home/                # 主界面
    thoughts/            # 思考功能
    settings/            # 设置
    profile/             # 个人资料
    about/               # 关于
    stats/               # 统计
    notifications/       # 通知
  services/              # 服务层
  utils/                 # 工具类
  widgets/               # 公共组件
```

## 技术栈

| 技术 | 用途 |
|------|------|
| Flutter + Dart | 跨平台框架 |
| Material 3 | UI 设计语言 |
| SharedPreferences | 本地数据存储 |
| MMKV | 高性能 KV 存储 |
| http | 网络请求 |
| flutter_local_notifications | 本地通知 |
| home_widget | 桌面小组件 |
| speech_to_text | 语音识别 |
| image_picker | 图片选择 |

## 构建

```bash
# 安装依赖
flutter pub get

# 开发模式运行
flutter run

# 构建 Release APK（仅 arm64，体积最小）
flutter build apk --target-platform android-arm64

# 构建 Release APK（兼容 arm32 + arm64）
flutter build apk
```

APK 输出路径：`build/app/outputs/flutter-apk/app-release.apk`

## 检查更新

版本信息托管在 GitHub 仓库的 `version.json` 文件中。发布新版本时：

1. 更新 `pubspec.yaml` 中的版本号
2. 更新 `version.json` 中的版本号和下载链接
3. 提交并推送到 GitHub

## 开源协议

MIT License

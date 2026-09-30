# Zoosy - 主动思考记录

> "Zoosy"取自"主思"的谐音，意为**主动思考**。在信息爆炸的时代，帮助你建立独立思考的闭环习惯。

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)
![License](https://img.shields.io/badge/License-MIT-green)
[![Version](https://img.shields.io/badge/version-1.18.1-blue)](https://github.com/theohowie/zoosy)

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

# 开发模式运行（注入 QQ 邮箱 SMTP 配置，密钥勿写入代码）
flutter run --dart-define=QQ_EMAIL=your_email@qq.com --dart-define=QQ_AUTH_CODE=your_code

# 构建 Release APK（仅 arm64，体积最小；Dart 混淆 + 符号表外置）
flutter build apk --target-platform android-arm64 --obfuscate --split-debug-info=build/symbols

# 构建 Release APK（兼容 arm32 + arm64）
flutter build apk --obfuscate --split-debug-info=build/symbols
```

APK 输出路径：`build/app/outputs/flutter-apk/app-release.apk`

## 签名与版本发布

### 为什么需要签名密钥轮换

Android 只允许**签名一致**的 APK 覆盖安装。本项目经历过一次签名密钥变更：

| 版本区间 | 签名密钥 | 说明 |
|---|---|---|
| <= v1.15.0 | `debug.keystore`（`CN=Android Debug`） | 早期正式包误用了调试密钥 |
| v1.16.0 ~ v1.17.5 | `upload-keystore.jks`（`CN=theohowie`） | 换用正式 upload 密钥 |

因此 <= v1.15.0 的老用户升级到 v1.16.0+ 时会报「**签名冲突 / 应用未安装**」。

### 解决办法：APK Signature Scheme v3 密钥轮换

v1.18.1 起，正式包在 **v3 签名块**中携带 `debug -> upload` 的轮换证明
（`android/keystores/lineage-debug-to-upload.bin`），Android 9（API 28）及以上
校验 lineage 后即可直接覆盖安装。

| 已安装版本 | Android 7.0-8.1 (API 24-27) | Android 9+ (API 28+) |
|---|---|---|
| <= v1.15.0（debug 签名） | ✅ v2 用 debug 密钥签名 | ✅ v3 lineage 放行 |
| v1.16.0 ~ v1.17.5（upload 签名） | ⚠️ 需卸载重装（仅此区间） | ✅ 同签名直接升级 |

> Android 7.x / 8.x 只认 v2 签名，而 v2 签名块只能有一个密钥（v2 不支持轮换），
> 因此这两个系统版本上「v1.16.0+ 用户」需要卸载重装一次，之后永久正常。

### 发布正式包

```powershell
pwsh -File tool/build-release.ps1          # 构建 + 轮换签名 + 自检 + 归档
pwsh -File tool/verify-signing.ps1 -ApkDir build/app/outputs/flutter-apk
```

`tool/build-release.ps1` 会调用 `flutter build apk --release`，随后用 `apksigner`
写入轮换签名，并校验：

- API 24-27 的 **v2 签名**必须是旧 debug 密钥（老用户升级路径）
- API 28+ 的 **v3 签名**必须是 upload 密钥（已升级用户的升级路径）

### 签名文件清单

| 文件 | 是否入库 | 说明 |
|---|---|---|
| `android/app/upload-keystore.jks` | 否 | 正式 upload 密钥（私钥） |
| `android/keystores/legacy-debug.jks` | 否 | 旧版 debug 密钥，仅用于生成 lineage |
| `android/keystores/lineage-debug-to-upload.bin` | 是 | 轮换证明，只含公钥信息 |
| `android/key.properties` | 否 | 密钥口令与路径配置 |

重建 lineage（换机器时）：

```powershell
apksigner rotate --out android\keystores\lineage-debug-to-upload.bin `
  --old-signer --ks android\keystores\legacy-debug.jks --ks-key-alias androiddebugkey --ks-pass pass:android --key-pass pass:android `
  --new-signer --ks android\app\upload-keystore.jks --ks-key-alias upload --ks-pass pass:<storePassword> --key-pass pass:<keyPassword>
```

`android/key.properties` 模板：

```properties
storePassword=<upload 密钥库口令>
keyPassword=<upload 私钥口令>
keyAlias=upload
storeFile=upload-keystore.jks

legacyStoreFile=../keystores/legacy-debug.jks
legacyKeyAlias=androiddebugkey
legacyStorePassword=android
legacyKeyPassword=android

lineageFile=../keystores/lineage-debug-to-upload.bin
```

## 检查更新

版本信息托管在 GitHub 仓库的 `version.json` 文件中。发布新版本时：

1. 更新 `pubspec.yaml` 中的版本号
2. 更新 `version.json` 中的版本号和下载链接
3. 提交并推送到 GitHub

## 开源协议

MIT License

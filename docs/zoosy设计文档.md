# Zoosy 设计文档（整合版）

版本：v0.3
日期：2026-06-12

\---

## 一、UI/UX 设计文档

### 1\. 设计原则

* 温和低负担：视觉柔和、留白充足、操作步骤少（核心记录30秒\~2分钟）。
* 朋友式陪伴：文案亲切，图标圆润，动画轻量反馈。
* 隐私尊重：权限请求界面清晰说明，并提供关闭入口。
* 响应式：适配手机、折叠屏、平板，支持深色模式。

### 2\. 色彩规范

|用途|色值（Light）|Dark 适配|
|-|-|-|
|主色调（思考/记录）|#6C63FF (紫罗兰)|#8A84FF|
|辅助色（成功/完成）|#4CD964 (绿)|#34C759|
|警示/删除|#FF3B30|#FF453A|
|背景（一级）|#FFFFFF|#000000|
|背景（二级）|#F2F2F7|#1C1C1E|
|文字主要|#1C1C1E|#FFFFFF|
|文字次要|#8E8E93|#8E8E93|

### 3\. 字体规范

* 英文字体：SF Pro Text / Roboto
* 中文字体：系统默认（思源黑/PingFang SC）
* 字号：标题 20sp，正文 16sp，辅助说明 13sp

### 4\. 核心页面线框图（文字描述）

#### 4.1 首页（思考足迹）

* 顶部栏：左侧“Zoosy”图标+文字，右侧设置入口。
* 统计卡片：连续打卡 X 天 · 本月已记录 Y 条。背景浅渐变。
* 时间轴列表：按日期分组，每条卡片显示：类别图标+事件名称、简短思考预览（一行）、记录时间。
* 悬浮按钮：圆形紫色按钮，点击后展开四个类别选项（影视阅读、运动健康、待办任务、舆论热点）。长按可切换“一句话模式”。

#### 4.2 新建思考卡页（分两步）

步骤一：选类别（若从悬浮按钮选择则跳过此页）

* 显示四个大卡片，每个卡片包含图标+类别名+典型场景示例。
* 底部可选“一句话快速记录”开关。

步骤二：填写内容

* 事件名称：输入框（必填）。
* 发生时间：默认“今天”，可修改（日期选择器）。
* 思考模板：展示该类别的2\~5个问题，每个问题下方有文本框。可折叠，默认展开第一个问题。
* 自由记录：大文本框，支持文字+图片添加。
* 心情/评分：5颗星或5个表情，可选。
* 标签：可输入多个标签，用逗号分隔。
* 保存按钮：固定在底部。

一句话模式：只显示事件名称+一个文本框（“一句话记录你的想法”），保存即完成。

#### 4.3 通知推送样式

* 标题：Zooby 想你了
* 内容：hello，最近在干什么？需要停下来思考一下吗？
* 点击行为：唤起 App 并直接打开“类别选择”页面。

#### 4.4 设置页（重点）

* 账号区块：头像、昵称、登录/注册。
* 提醒设置：基础提醒（固定时间开关及时间选择）、智能感知推送（总开关+子开关）、勿扰模式时段。
* 隐私与权限：使用情况访问权限、剪贴板读取权限、通知权限，每个都有解释说明。
* 外观：深色模式跟随系统/手动。

### 5\. 交互细节

* 记录成功后，显示“✅ 已存入思考足迹”轻提示，并自动返回首页。
* 连续打卡达到7/30/100天时，弹出祝贺动画（撒花+鼓励文案）。
* 删除思考卡需二次确认，避免误删。

\---

## 二、技术设计文档

### 1\. 技术栈

* 前端：Flutter (Dart)，状态管理使用 Riverpod 或 BLoC。
* 后端：Node.js + NestJS，数据库 PostgreSQL，缓存 Redis（可选）。
* 同步：本地 SQLite（使用 drift 或 sqflite），离线优先，增量同步采用基于时间戳的冲突解决（最后写入优先）。
* 推送：

  * Android：Firebase Cloud Messaging (国际) / 国内厂商通道（小米、华为等）。
  * iOS：APNs。
  * HarmonyOS：Push Kit。

### 2\. 数据库详细表结构

#### 2.1 User 表

SQL:
CREATE TABLE users (
id UUID PRIMARY KEY,
nickname VARCHAR(50),
avatar\_url TEXT,
settings JSONB, -- 推送配置、勿扰时段等
created\_at TIMESTAMP,
updated\_at TIMESTAMP
);

#### 2.2 Category 表（固定四类，不允许用户新增）

SQL:
CREATE TABLE categories (
id SERIAL PRIMARY KEY,
name VARCHAR(20) NOT NULL, -- 影视阅读/运动健康/待办任务/舆论热点
icon VARCHAR(50),
color VARCHAR(7),
question\_templates JSONB, -- 问题列表
sort\_order INT
);
-- 预置数据初始化

#### 2.3 ThoughtCard 表

SQL:
CREATE TABLE thought\_cards (
id UUID PRIMARY KEY,
user\_id UUID REFERENCES users(id),
category\_id INT REFERENCES categories(id),
title VARCHAR(200) NOT NULL,
event\_time TIMESTAMP,
record\_time TIMESTAMP DEFAULT CURRENT\_TIMESTAMP,
answers JSONB, -- \[{question: "", answer: ""}]
free\_note TEXT,
-- mood column removed
tags TEXT\[], -- 数组
attachments TEXT\[],
privacy VARCHAR(10) DEFAULT 'private', -- private/shared
updated\_at TIMESTAMP
);

#### 2.4 客户端本地表（与云端一致，额外增加 sync\_status）

SQL:
ALTER TABLE thought\_cards ADD COLUMN sync\_status INT DEFAULT 0;

#### 2.5 推送触发日志（客户端本地）

SQL:
CREATE TABLE local\_push\_log (
id INTEGER PRIMARY KEY AUTOINCREMENT,
trigger\_type TEXT, -- duration/action/clipboard/timehabit
trigger\_time TIMESTAMP,
user\_action TEXT -- clicked/dismissed
);

### 3\. API 接口设计（RESTful）

|端点|方法|说明|
|-|-|-|
|/api/auth/register|POST|注册|
|/api/auth/login|POST|登录|
|/api/cards|GET|拉取用户所有思考卡（分页）|
|/api/cards|POST|创建或更新思考卡（合并上传）|
|/api/cards/{id}|DELETE|删除|
|/api/sync|POST|批量同步（客户端发送本地上次同步后的变更）|
|/api/settings|GET/PUT|获取/更新用户设置|

### 4\. 本地智能推送算法伪代码

Python:

# 每次检测到可能的触发事件时调用

def should\_push(trigger\_type, last\_push\_time, consecutive\_dismiss, now):
# 抑制条件
if is\_do\_not\_disturb(now): return False
if now - last\_push\_time < 6 \* 3600: return False
if consecutive\_dismiss >= 3 and trigger\_type != "timehabit": return False
if has\_recorded\_in\_last\_hour(): return False

&#x20;   # 各触发源独立判断
    if trigger\_type == "duration":
        if last\_duration\_exit\_within\_2min() and usage\_time > 15:
            return True
    elif trigger\_type == "action":
        if deep\_interaction\_detected(): return True
    elif trigger\_type == "clipboard":
        if copied\_text\_length > 50 and not triggered\_recently(3600): return True
    elif trigger\_type == "timehabit":
        if in\_bedtime\_range() and today\_no\_record(): return True
    return False


# 推送文案固定，无个性化内容

push(title="Zooby 想你了", content="hello，最近在干什么？需要停下来思考一下吗？")

### 5\. 同步冲突解决策略

* 每条记录带 updated\_at 和客户端生成的 version。
* 服务端比较 updated\_at，保留最新的。
* 若出现相等（罕见），比较 version（UUID v1 时间戳部分）。
* 冲突时客户端弹出提示（可选）或静默保留服务端版本。

\---

## 三、产品功能设计文档

### 1\. 用户故事（User Stories）

#### 1.1 影视/阅读记录

> 作为用户，我希望在看完一部电影后，能快速记录我的真实感受，而不是被豆瓣评分影响，以便我形成自己的判断。

验收条件：

* 选择“影视阅读”类别后，看到预设问题（如“和网上说的不一样的点”）
* 支持一句话模式
* 保存后时间轴显示

#### 1.2 舆论冷静思考

> 作为经常刷微博的用户，我希望在参与一个热点讨论前，系统能适时提醒我先停下来思考一下，避免情绪化站队。

验收条件：

* 智能感知推送在浏览15分钟后出现
* 点击后进入“舆论热点”类别模板
* 模板包含情绪识别、事实厘清等问题
* 24小时后收到冷静期回访推送

#### 1.3 习惯养成与回顾

> 作为有反思习惯的用户，我希望看到我的连续记录天数，以及每月回顾报告，让我感受到积累的价值。

验收条件：

* 首页展示连续打卡天数
* 每月1日推送上月回顾报告（可点击查看）
* 时间轴支持按年/月筛选

### 2\. 业务流程图（文字描述）

#### 2.1 核心记录流程（手动）

\[用户打开App] → \[点击悬浮按钮] → \[选择类别] →
\[填写事件名称+时间] → \[回答模板问题（可跳过）] →
\[可选: 自由记录/心情/标签] → \[点击保存] →
\[显示成功提示] → \[返回首页并刷新时间轴]

#### 2.2 智能推送触发流程

\[后台监听使用情况/剪贴板] → \[触发条件满足] →
\[检查抑制条件] → \[满足推送条件] →
\[发送本地通知] →
\[用户点击] → \[打开App并跳转到类别选择页] →
\[用户选择类别后进入新建思考卡页]

### 3\. 非功能需求

* 性能：App启动时间 < 2秒，记录保存响应 < 0.5秒。
* 隐私：所有感知数据不上传服务器；用户可随时清除本地日志。
* 兼容性：支持 Android 8.0+，iOS 13+，HarmonyOS 2.0+。
* 可用性：首次使用引导流程不超过3页，核心功能无需注册即可使用。

### 4\. 运营与增长功能（可选后续）

* 每周思考精选：用户可授权将一条匿名思考卡片分享到“思考广场”（需审核）。
* 挑战活动：如“7天独立思考挑战”，完成后获得徽章。
* 小组件：桌面显示本月记录进度条或随机一条历史思考。


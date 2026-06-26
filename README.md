# 星愿回声 ✨🌟

一个黑蓝主题的星空许愿网站，把愿望交给星星，让未来轻轻回应。

**🌐 永久网址：[dsasanim4-source.github.io/wish-upon-a-star](https://dsasanim4-source.github.io/wish-upon-a-star/)**

---

## 🎯 十大功能

### 1. 🌟 星座许愿系统
心愿按主题分类（爱情、梦想、家庭、健康、财富、学业、旅行等），同类心愿的星星会自动连接成星座图案，在星空中形成独特的视觉标识。

### 2. 💌 漂流瓶
留言仅对下一个人可见。打开后即消失，像漂流瓶一样神秘。支持实时同步，多人同时使用。

### 3. ⏳ 时光胶囊
设定未来的日期封存心愿。愿望会随时间推移逐渐"成熟"，到期后自动解锁，让你与过去的自己对话。

### 4. 🎵 星空音乐盒
点击任意已落定的星星，会发出不同的音符。不同区域的星星有不同的音色，整片星空就是你的乐器。

### 5. 🌠 流星雨许愿池
每 60 分钟自动触发一次流星雨事件。流星雨期间会出现大量流星，在线用户共同感受这场视觉盛宴。顶部会有倒计时提醒。

### 6. 🌌 星系地图
可视化查看所有心愿的分布。心愿按主题聚集成星系，支持缩放和平移，像一个迷你的愿望宇宙。

### 7. 🧚 AI 愿望精灵
内置智能精灵对话系统。向精灵诉说你的愿望，它会根据愿望类型给出个性化的温暖鼓励。

### 8. 🧭 愿望复盘
把原来的装饰性生长树升级为复盘面板：只统计本设备写下或保存过的愿望，展示心愿总数、完成率、待回访、祝福数、进度分布、最近心愿和已实现心愿，帮助用户真正回头管理自己的愿望。

### 9. 🌅 日出许愿 + 日落回顾
根据当地时间自动切换主题色调：
- 🌅 日出模式（5:00-7:00）— 暖紫调
- ☀️ 白天模式（7:00-17:00）— 明亮蓝调
- 🌇 日落模式（17:00-19:00）— 暖橙调
- 🌙 深夜模式（19:00-5:00）— 深邃蓝黑调

### 10. 🔮 多人协作星座绘制
开启绘制模式后，可以在星空中自由放置星星并连线，创造出独一无二的星座图案。支持保存到本地。

---

## 快速开始

### 1. 配置 Supabase（后端数据库）

1. 注册 [supabase.com](https://supabase.com) → 创建项目
2. 进入项目 → **SQL Editor** → 粘贴 `schema.sql` 全部内容 → 点击 **Run**
3. 进入项目 → **Settings → API** → 复制 **Project URL** 和 **anon public key**
4. 打开 `index.html`，找到 `CONFIG` 对象，替换：
   ```js
   supabaseUrl: 'YOUR_SUPABASE_URL',
   supabaseKey: 'YOUR_SUPABASE_ANON_KEY',
   ```
5. 进入项目 → **Authentication → URL Configuration**，把网站地址加入允许跳转地址，例如：
   `https://dsasanim4-source.github.io/wish-upon-a-star/`

### 管理员登录

管理员邮箱默认是 `2507997974@qq.com`。打开愿望精灵后输入 `管理员登录`，系统会向默认邮箱发送 6 位验证码；也可以输入 `管理员登录 your@gmail.com` 给指定管理员邮箱发送验证码。收到后直接在愿望精灵输入验证码即可进入管理员模式。云端删除公共愿望需要先执行最新版 `schema.sql`，并确保该邮箱已加入 `admin_users` 表。

如果想让邮件里显示验证码，请在 **Authentication → Email Templates → Magic Link** 里加入 `{{ .Token }}`，例如：`你的管理员验证码是：{{ .Token }}`。如果邮件里只有链接，也可以直接点击链接回到网站。

如果发送失败，页面会显示 Supabase 返回的具体原因。常见处理：
- 提示请求太频繁：等待 1 分钟后再试。
- 提示 redirect / URL：在 **Authentication → URL Configuration** 加入 `https://dsasanim4-source.github.io/wish-upon-a-star/`。
- 提示 email disabled：在 **Authentication → Providers → Email** 启用 Email provider。
- 提示 SMTP / mailer / 未成功发送邮件：检查 **Authentication → SMTP Settings**。
- 使用 Resend SMTP 时：Gmail 只能作为收件邮箱，不能作为发件邮箱。Supabase 的 Sender email 必须是 Resend 已验证域名下的地址，例如 `noreply@你的域名`；SMTP Host 用 `smtp.resend.com`，Port 用 `465`，Username 用 `resend`，Password 用 Resend API Key。
- 如果你没有 Resend 验证域名：先关闭 Supabase 的 Custom SMTP，改用 Supabase 默认邮件服务。验证码方式也必须先能成功发出邮件。

### 2. 部署到 GitHub Pages

1. Fork 或 Push 本项目到你的 GitHub 仓库
2. 进入仓库 → **Settings → Pages**
3. Source 选择 `master` 分支，根目录 `/` → Save
4. 等待几分钟，访问 `https://你的用户名.github.io/仓库名/`

---

## 项目结构

```
wish/
├── index.html    # 主页面（HTML + CSS + JS，所有功能）
├── schema.sql    # Supabase 数据库初始化脚本
└── README.md     # 本文件
```

## 技术栈

- 前端：原生 HTML/CSS/JS（Canvas 星空动画）
- 后端：Supabase（PostgreSQL + Realtime）
- 托管：GitHub Pages
- 音频：Web Audio API
- AI：本地智能响应引擎

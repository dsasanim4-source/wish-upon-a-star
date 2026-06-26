# 星愿回声 ✨🌟

一个黑蓝主题的星空许愿网站，把愿望交给星星，让未来轻轻回应。

**🌐 永久网址：[dsasanim4-source.github.io/wish-upon-a-star](https://dsasanim4-source.github.io/wish-upon-a-star/)**

---

## 🎯 十大功能

### 1. 🌟 星座许愿系统
心愿按主题分类（爱情、梦想、家庭、健康、财富、学业、旅行等），同类心愿的星星会自动连接成星座图案，在星空中形成独特的视觉标识。

### 2. 💌 漂流瓶
留言仅对下一个人可见。打开后即消失，并会在星空中点亮一颗“回声星”。支持实时同步，多人同时使用。

### 3. ⏳ 时光胶囊
设定未来的日期封存心愿。愿望会随时间推移逐渐"成熟"，到期后以星门弹窗解锁，读完可直接写一封回信给未来的自己。

### 4. 🎵 星空音乐盒
点击任意已落定的星星，会发出不同的音符。不同区域的星星有不同的音色，整片星空就是你的乐器。

### 5. 🌠 流星雨许愿池
每 60 分钟自动触发一次流星雨事件。流星雨期间会出现大量流星，在线用户共同感受这场视觉盛宴。顶部会有倒计时提醒。

### 6. 🌌 星系地图
可视化查看所有心愿的分布。心愿按主题聚集成星系，支持缩放和平移；星图导出支持多种模板与年度总结样式。

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
### 管理员登录

管理员模式使用 30 秒一变的 TOTP 动态密码，不依赖邮箱、Resend 或短信。先执行最新版 `schema.sql`，然后在 Supabase SQL Editor 里设置你的动态密钥：

```sql
INSERT INTO public.admin_totp_settings (id, secret_base32, updated_at)
VALUES (TRUE, '把这里换成你的BASE32密钥', NOW())
ON CONFLICT (id)
DO UPDATE SET secret_base32 = EXCLUDED.secret_base32, updated_at = NOW();
```

把同一个 BASE32 密钥手动添加到 Google Authenticator、Microsoft Authenticator 或 1Password。网站里打开愿望精灵，输入 `管理员登录`，再输入验证器显示的 6 位动态密码即可进入管理员模式；也可以直接输入 `管理员登录 123456`。

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

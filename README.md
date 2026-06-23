# 祈愿·天天开心 ✨

一个黑蓝主题的祈愿网站，带有漂流瓶留言功能。

**🌐 永久网址：[dsasanim4-source.github.io/wish-upon-a-star](https://dsasanim4-source.github.io/wish-upon-a-star/)**

---

## 功能

- **✨ 许愿** — 写下心愿，化为星辰飞向心形星座。所有心愿公开可见，实时同步。
- **💌 漂流瓶留言** — 留言仅对下一个人可见。打开后即消失，像漂流瓶一样神秘。

## 配色

黑蓝高级配色，适合 22 岁成年人审美。深空背景 + 蓝色星光 + 毛玻璃卡片。

## 快速开始

### 1. 配置 Supabase（后端数据库）

1. 注册 [supabase.com](https://supabase.com) → 创建项目
2. 进入项目 → **SQL Editor** → 粘贴 `schema.sql` 全部内容 → 点击 **Run**
3. 进入项目 → **Settings → API** → 复制 **Project URL** 和 **anon public key**
4. 打开 `index.html`，找到 `CONFIG` 对象，替换：
   ```js
   supabaseUrl: 'YOUR_SUPABASE_URL',      // 改为你的 Project URL
   supabaseKey: 'YOUR_SUPABASE_ANON_KEY',  // 改为你的 anon key
   ```

### 2. 部署到 GitHub Pages

1. Fork 或 Push 本项目到你的 GitHub 仓库
2. 进入仓库 → **Settings → Pages**
3. Source 选择 `master` 分支，根目录 `/` → Save
4. 等待几分钟，访问 `https://你的用户名.github.io/仓库名/`

---

## 项目结构

```
wish/
├── index.html    # 主页面（HTML + CSS + JS）
├── schema.sql    # Supabase 数据库初始化脚本
└── README.md     # 本文件
```

## 技术栈

- 前端：原生 HTML/CSS/JS（Canvas 星空动画）
- 后端：Supabase（PostgreSQL + Realtime）
- 托管：GitHub Pages
-- ============================================================
-- 祈愿 · 天天开心 — Supabase 数据库初始化脚本 v2
-- 新增: 标签分类、时光胶囊、星座协作
-- ============================================================
-- 使用方法:
--   1. 登录 supabase.com → 进入你的项目 → SQL Editor
--   2. 粘贴此文件全部内容 → 点击 Run
--   （可重复执行，不会报错）
-- ============================================================

-- ── 心愿表 ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS wishes (
  id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  text      TEXT NOT NULL,
  tag       TEXT DEFAULT 'general',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── 如果 wishes 表已存在但没有 tag 列，则添加 ────
ALTER TABLE wishes ADD COLUMN IF NOT EXISTS tag TEXT DEFAULT 'general';

-- ── 留言表 ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS messages (
  id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  text      TEXT NOT NULL,
  revealed  BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── 如果 messages 表已存在但没有 revealed 列，则添加 ────
ALTER TABLE messages ADD COLUMN IF NOT EXISTS revealed BOOLEAN DEFAULT FALSE;

-- ── 时光胶囊表 ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS time_capsules (
  id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  text       TEXT NOT NULL,
  reveal_date TIMESTAMPTZ NOT NULL,
  revealed   BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── 星座协作表 ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS constellations (
  id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name       TEXT NOT NULL,
  stars_data JSONB DEFAULT '[]',
  lines_data JSONB DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── 开启实时同步（Realtime） ────────────────────────────
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE wishes;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE messages;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE time_capsules;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE constellations;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
END $$;

-- ── 开启行级安全（RLS） ─────────────────────────────────
ALTER TABLE wishes ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE time_capsules ENABLE ROW LEVEL SECURITY;
ALTER TABLE constellations ENABLE ROW LEVEL SECURITY;

-- ── 删除旧策略（如有）再重建 ────────────────────────────
DROP POLICY IF EXISTS "允许任何人读取心愿" ON wishes;
DROP POLICY IF EXISTS "允许任何人读取留言" ON messages;
DROP POLICY IF EXISTS "允许任何人写入心愿" ON wishes;
DROP POLICY IF EXISTS "允许任何人写入留言" ON messages;
DROP POLICY IF EXISTS "允许任何人更新留言" ON messages;
DROP POLICY IF EXISTS "允许任何人读取时光胶囊" ON time_capsules;
DROP POLICY IF EXISTS "允许任何人写入时光胶囊" ON time_capsules;
DROP POLICY IF EXISTS "允许任何人更新时光胶囊" ON time_capsules;
DROP POLICY IF EXISTS "允许任何人读取星座" ON constellations;
DROP POLICY IF EXISTS "允许任何人写入星座" ON constellations;

-- ── 公开读取 ────────────────────────────────────────────
CREATE POLICY "允许任何人读取心愿" ON wishes
  FOR SELECT USING (true);

CREATE POLICY "允许任何人读取留言" ON messages
  FOR SELECT USING (true);

CREATE POLICY "允许任何人读取时光胶囊" ON time_capsules
  FOR SELECT USING (true);

CREATE POLICY "允许任何人读取星座" ON constellations
  FOR SELECT USING (true);

-- ── 公开写入 ────────────────────────────────────────────
CREATE POLICY "允许任何人写入心愿" ON wishes
  FOR INSERT WITH CHECK (true);

CREATE POLICY "允许任何人写入留言" ON messages
  FOR INSERT WITH CHECK (true);

CREATE POLICY "允许任何人写入时光胶囊" ON time_capsules
  FOR INSERT WITH CHECK (true);

CREATE POLICY "允许任何人写入星座" ON constellations
  FOR INSERT WITH CHECK (true);

-- ── 允许更新 ────────────────────────────────────────────
CREATE POLICY "允许任何人更新留言" ON messages
  FOR UPDATE USING (true) WITH CHECK (true);

CREATE POLICY "允许任何人更新时光胶囊" ON time_capsules
  FOR UPDATE USING (true) WITH CHECK (true);
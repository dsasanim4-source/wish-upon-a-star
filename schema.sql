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
  blessing_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── 如果 wishes 表已存在但没有 tag 列，则添加 ────
ALTER TABLE wishes ADD COLUMN IF NOT EXISTS tag TEXT DEFAULT 'general';
ALTER TABLE wishes ADD COLUMN IF NOT EXISTS blessing_count INTEGER DEFAULT 0;
UPDATE wishes SET blessing_count = 0 WHERE blessing_count IS NULL;

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
DROP POLICY IF EXISTS "allow_admin_delete_wishes" ON wishes;
DROP POLICY IF EXISTS "允许任何人更新留言" ON messages;
DROP POLICY IF EXISTS "允许任何人读取时光胶囊" ON time_capsules;
DROP POLICY IF EXISTS "允许任何人写入时光胶囊" ON time_capsules;
DROP POLICY IF EXISTS "允许任何人更新时光胶囊" ON time_capsules;
DROP POLICY IF EXISTS "允许任何人读取星座" ON constellations;
DROP POLICY IF EXISTS "允许任何人写入星座" ON constellations;
DROP FUNCTION IF EXISTS admin_delete_wish(TEXT, BIGINT);
DROP FUNCTION IF EXISTS bless_wish(BIGINT);

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

-- 公开心愿祝福计数（只允许通过函数累加）
CREATE OR REPLACE FUNCTION bless_wish(wish_id BIGINT)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  next_count INTEGER;
BEGIN
  UPDATE wishes
  SET blessing_count = COALESCE(blessing_count, 0) + 1
  WHERE id = wish_id
  RETURNING blessing_count INTO next_count;

  IF next_count IS NULL THEN
    RAISE EXCEPTION 'wish not found';
  END IF;

  RETURN next_count;
END;
$$;

GRANT EXECUTE ON FUNCTION bless_wish(BIGINT) TO anon;
GRANT EXECUTE ON FUNCTION bless_wish(BIGINT) TO authenticated;

-- ── 允许更新 ────────────────────────────────────────────
CREATE POLICY "允许任何人更新留言" ON messages
  FOR UPDATE USING (true) WITH CHECK (true);

CREATE POLICY "允许任何人更新时光胶囊" ON time_capsules
  FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================================
-- Admin dynamic password migration
-- Re-run safe. Uses a TOTP code from an authenticator app.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.admin_totp_settings (
  id BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (id),
  secret_base32 TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.admin_sessions (
  token_hash TEXT PRIMARY KEY,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.admin_totp_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_sessions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.admin_totp_settings FROM anon, authenticated;
REVOKE ALL ON public.admin_sessions FROM anon, authenticated;
REVOKE DELETE ON public.wishes FROM anon, authenticated;

DROP POLICY IF EXISTS "allow_admin_delete_wishes" ON public.wishes;

CREATE OR REPLACE FUNCTION public.base32_decode(input TEXT)
RETURNS BYTEA
LANGUAGE plpgsql
IMMUTABLE
STRICT
SET search_path = public
AS $$
DECLARE
  alphabet CONSTANT TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  clean TEXT := UPPER(REGEXP_REPLACE(input, '[^A-Z2-7]', '', 'g'));
  bits TEXT := '';
  out_bytes BYTEA := DECODE('', 'hex');
  ch TEXT;
  val INTEGER;
  byte_bits TEXT;
  byte_val INTEGER;
  i INTEGER;
BEGIN
  FOR i IN 1..LENGTH(clean) LOOP
    ch := SUBSTRING(clean FROM i FOR 1);
    val := POSITION(ch IN alphabet) - 1;
    IF val < 0 THEN
      RAISE EXCEPTION 'invalid base32 secret';
    END IF;
    bits := bits || (val::BIT(5))::TEXT;
  END LOOP;

  WHILE LENGTH(bits) >= 8 LOOP
    byte_bits := SUBSTRING(bits FROM 1 FOR 8);
    bits := SUBSTRING(bits FROM 9);
    byte_val := byte_bits::BIT(8)::INTEGER;
    out_bytes := out_bytes || DECODE(LPAD(TO_HEX(byte_val), 2, '0'), 'hex');
  END LOOP;

  RETURN out_bytes;
END;
$$;

CREATE OR REPLACE FUNCTION public.bigint_to_big_endian(value BIGINT)
RETURNS BYTEA
LANGUAGE sql
IMMUTABLE
STRICT
SET search_path = public
AS $$
  SELECT DECODE(LPAD(TO_HEX(value), 16, '0'), 'hex');
$$;

CREATE OR REPLACE FUNCTION public.totp_code(secret_base32 TEXT, counter_value BIGINT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
STRICT
SET search_path = public
AS $$
DECLARE
  mac BYTEA;
  hmac_offset INTEGER;
  binary_code INTEGER;
BEGIN
  mac := HMAC(public.bigint_to_big_endian(counter_value), public.base32_decode(secret_base32), 'sha1');
  hmac_offset := GET_BYTE(mac, OCTET_LENGTH(mac) - 1) & 15;
  binary_code :=
    ((GET_BYTE(mac, hmac_offset) & 127) << 24) |
    ((GET_BYTE(mac, hmac_offset + 1) & 255) << 16) |
    ((GET_BYTE(mac, hmac_offset + 2) & 255) << 8) |
    (GET_BYTE(mac, hmac_offset + 3) & 255);

  RETURN LPAD((binary_code % 1000000)::TEXT, 6, '0');
END;
$$;

CREATE OR REPLACE FUNCTION public.verify_admin_session(admin_token TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  hash TEXT;
BEGIN
  DELETE FROM public.admin_sessions WHERE expires_at <= NOW();
  IF admin_token IS NULL OR LENGTH(admin_token) < 20 THEN
    RETURN FALSE;
  END IF;
  hash := ENCODE(DIGEST(admin_token, 'sha256'), 'hex');
  RETURN EXISTS (
    SELECT 1
    FROM public.admin_sessions
    WHERE token_hash = hash
      AND expires_at > NOW()
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.verify_admin_code(admin_code TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  normalized TEXT := REGEXP_REPLACE(COALESCE(admin_code, ''), '\D', '', 'g');
  secret TEXT;
  counter_value BIGINT := FLOOR(EXTRACT(EPOCH FROM NOW()) / 30)::BIGINT;
  skew INTEGER;
  session_token TEXT;
BEGIN
  SELECT secret_base32 INTO secret
  FROM public.admin_totp_settings
  WHERE id = TRUE
  LIMIT 1;

  IF secret IS NULL OR LENGTH(REGEXP_REPLACE(secret, '[^A-Z2-7]', '', 'gi')) < 16 THEN
    RAISE EXCEPTION 'admin totp secret not configured';
  END IF;

  IF LENGTH(normalized) <> 6 THEN
    RAISE EXCEPTION 'invalid admin code';
  END IF;

  FOR skew IN -1..1 LOOP
    IF public.totp_code(secret, counter_value + skew) = normalized THEN
      session_token := ENCODE(GEN_RANDOM_BYTES(32), 'hex');
      INSERT INTO public.admin_sessions (token_hash, expires_at)
      VALUES (ENCODE(DIGEST(session_token, 'sha256'), 'hex'), NOW() + INTERVAL '30 minutes');
      RETURN session_token;
    END IF;
  END LOOP;

  RAISE EXCEPTION 'invalid admin code';
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_logout(admin_token TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.admin_sessions
  WHERE token_hash = ENCODE(DIGEST(COALESCE(admin_token, ''), 'sha256'), 'hex');
  RETURN TRUE;
END;
$$;

DROP FUNCTION IF EXISTS public.admin_delete_wish(TEXT, BIGINT);
DROP FUNCTION IF EXISTS public.admin_delete_wish(BIGINT);
DROP FUNCTION IF EXISTS public.admin_delete_wish(BIGINT, TEXT);

CREATE OR REPLACE FUNCTION public.admin_delete_wish(wish_id BIGINT, admin_token TEXT)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  IF NOT public.verify_admin_session(admin_token) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  DELETE FROM public.wishes WHERE id = wish_id;
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$;

REVOKE ALL ON FUNCTION public.base32_decode(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.bigint_to_big_endian(BIGINT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.totp_code(TEXT, BIGINT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.verify_admin_session(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.verify_admin_code(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_logout(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_delete_wish(BIGINT, TEXT) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.verify_admin_session(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.verify_admin_code(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_logout(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_wish(BIGINT, TEXT) TO anon, authenticated;

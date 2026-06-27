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
ALTER TABLE wishes ADD COLUMN IF NOT EXISTS moderation_status TEXT DEFAULT 'visible';
ALTER TABLE wishes ADD COLUMN IF NOT EXISTS hidden_at TIMESTAMPTZ;
ALTER TABLE wishes ADD COLUMN IF NOT EXISTS hidden_reason TEXT;
UPDATE wishes SET blessing_count = 0 WHERE blessing_count IS NULL;
UPDATE wishes SET moderation_status = 'visible' WHERE moderation_status IS NULL;

-- ── 留言表 ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS messages (
  id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  text      TEXT NOT NULL,
  revealed  BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── 如果 messages 表已存在但没有 revealed 列，则添加 ────
ALTER TABLE messages ADD COLUMN IF NOT EXISTS revealed BOOLEAN DEFAULT FALSE;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS moderation_status TEXT DEFAULT 'visible';
ALTER TABLE messages ADD COLUMN IF NOT EXISTS hidden_at TIMESTAMPTZ;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS hidden_reason TEXT;
UPDATE messages SET moderation_status = 'visible' WHERE moderation_status IS NULL;

-- ── 时光胶囊表 ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS time_capsules (
  id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  text       TEXT NOT NULL,
  reveal_date TIMESTAMPTZ NOT NULL,
  revealed   BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE time_capsules ADD COLUMN IF NOT EXISTS moderation_status TEXT DEFAULT 'visible';
ALTER TABLE time_capsules ADD COLUMN IF NOT EXISTS hidden_at TIMESTAMPTZ;
ALTER TABLE time_capsules ADD COLUMN IF NOT EXISTS hidden_reason TEXT;
UPDATE time_capsules SET moderation_status = 'visible' WHERE moderation_status IS NULL;

-- ── 管理员操作日志 ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  action       TEXT NOT NULL,
  content_type TEXT NOT NULL,
  content_id   BIGINT,
  content_text TEXT,
  metadata     JSONB DEFAULT '{}'::JSONB,
  created_at   TIMESTAMPTZ DEFAULT NOW()
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
ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;

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
  FOR SELECT USING (COALESCE(moderation_status, 'visible') = 'visible');

CREATE POLICY "允许任何人读取留言" ON messages
  FOR SELECT USING (COALESCE(moderation_status, 'visible') = 'visible');

CREATE POLICY "允许任何人读取时光胶囊" ON time_capsules
  FOR SELECT USING (COALESCE(moderation_status, 'visible') = 'visible');

CREATE POLICY "允许任何人读取星座" ON constellations
  FOR SELECT USING (true);

-- ── 公开写入 ────────────────────────────────────────────
CREATE POLICY "允许任何人写入心愿" ON wishes
  FOR INSERT WITH CHECK (COALESCE(moderation_status, 'visible') = 'visible');

CREATE POLICY "允许任何人写入留言" ON messages
  FOR INSERT WITH CHECK (COALESCE(moderation_status, 'visible') = 'visible');

CREATE POLICY "允许任何人写入时光胶囊" ON time_capsules
  FOR INSERT WITH CHECK (COALESCE(moderation_status, 'visible') = 'visible');

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
  FOR UPDATE USING (COALESCE(moderation_status, 'visible') = 'visible')
  WITH CHECK (COALESCE(moderation_status, 'visible') = 'visible');

CREATE POLICY "允许任何人更新时光胶囊" ON time_capsules
  FOR UPDATE USING (COALESCE(moderation_status, 'visible') = 'visible')
  WITH CHECK (COALESCE(moderation_status, 'visible') = 'visible');

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
REVOKE ALL ON public.admin_audit_logs FROM anon, authenticated;
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
SET search_path = public, extensions
AS $$
DECLARE
  mac BYTEA;
  hmac_offset INTEGER;
  binary_code INTEGER;
BEGIN
  mac := HMAC(public.bigint_to_big_endian(counter_value), public.base32_decode(secret_base32), 'sha1'::TEXT);
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
SET search_path = public, extensions
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
SET search_path = public, extensions
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
SET search_path = public, extensions
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
DROP FUNCTION IF EXISTS public.admin_set_content_status(TEXT, BIGINT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.admin_delete_content(TEXT, BIGINT, TEXT);
DROP FUNCTION IF EXISTS public.admin_write_audit_log(TEXT, TEXT, BIGINT, TEXT, JSONB);
DROP FUNCTION IF EXISTS public.admin_list_content(TEXT, TEXT);
DROP FUNCTION IF EXISTS public.admin_list_audit_logs(TEXT, INTEGER);

CREATE OR REPLACE FUNCTION public.admin_write_audit_log(
  admin_action TEXT,
  admin_content_type TEXT,
  admin_content_id BIGINT,
  admin_content_text TEXT,
  admin_metadata JSONB DEFAULT '{}'::JSONB
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_id BIGINT;
BEGIN
  INSERT INTO public.admin_audit_logs (action, content_type, content_id, content_text, metadata)
  VALUES (
    admin_action,
    admin_content_type,
    admin_content_id,
    LEFT(COALESCE(admin_content_text, ''), 500),
    COALESCE(admin_metadata, '{}'::JSONB)
  )
  RETURNING id INTO new_id;
  RETURN new_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_list_content(requested_content_type TEXT, admin_token TEXT)
RETURNS TABLE (
  content_type TEXT,
  id BIGINT,
  text TEXT,
  tag TEXT,
  blessing_count INTEGER,
  revealed BOOLEAN,
  reveal_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ,
  moderation_status TEXT,
  hidden_at TIMESTAMPTZ,
  hidden_reason TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  normalized_type TEXT := LOWER(COALESCE(requested_content_type, 'wishes'));
BEGIN
  IF NOT public.verify_admin_session(admin_token) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  IF normalized_type = 'wishes' THEN
    RETURN QUERY
      SELECT 'wishes'::TEXT, w.id, w.text, w.tag, w.blessing_count,
             NULL::BOOLEAN, NULL::TIMESTAMPTZ, w.created_at,
             COALESCE(w.moderation_status, 'visible'), w.hidden_at, w.hidden_reason
      FROM public.wishes w
      ORDER BY
        CASE COALESCE(w.moderation_status, 'visible') WHEN 'hidden' THEN 0 ELSE 1 END,
        w.created_at DESC
      LIMIT 160;
  ELSIF normalized_type = 'messages' THEN
    RETURN QUERY
      SELECT 'messages'::TEXT, m.id, m.text, NULL::TEXT, NULL::INTEGER,
             m.revealed, NULL::TIMESTAMPTZ, m.created_at,
             COALESCE(m.moderation_status, 'visible'), m.hidden_at, m.hidden_reason
      FROM public.messages m
      ORDER BY
        CASE COALESCE(m.moderation_status, 'visible') WHEN 'hidden' THEN 0 ELSE 1 END,
        m.created_at DESC
      LIMIT 160;
  ELSIF normalized_type IN ('capsules', 'time_capsules') THEN
    RETURN QUERY
      SELECT 'capsules'::TEXT, c.id, c.text, NULL::TEXT, NULL::INTEGER,
             c.revealed, c.reveal_date, c.created_at,
             COALESCE(c.moderation_status, 'visible'), c.hidden_at, c.hidden_reason
      FROM public.time_capsules c
      ORDER BY
        CASE COALESCE(c.moderation_status, 'visible') WHEN 'hidden' THEN 0 ELSE 1 END,
        c.created_at DESC
      LIMIT 160;
  ELSE
    RAISE EXCEPTION 'invalid content type';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_list_audit_logs(admin_token TEXT, limit_count INTEGER DEFAULT 80)
RETURNS TABLE (
  id BIGINT,
  action TEXT,
  content_type TEXT,
  content_id BIGINT,
  content_text TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.verify_admin_session(admin_token) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  RETURN QUERY
    SELECT l.id, l.action, l.content_type, l.content_id, l.content_text, l.metadata, l.created_at
    FROM public.admin_audit_logs l
    ORDER BY l.created_at DESC
    LIMIT LEAST(GREATEST(COALESCE(limit_count, 80), 1), 200);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_content_status(
  content_type TEXT,
  content_id BIGINT,
  next_status TEXT,
  admin_token TEXT,
  reason TEXT DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  normalized_type TEXT := LOWER(COALESCE(content_type, ''));
  normalized_status TEXT := LOWER(COALESCE(next_status, ''));
  changed_count INTEGER := 0;
  old_text TEXT;
BEGIN
  IF NOT public.verify_admin_session(admin_token) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;
  IF normalized_status NOT IN ('visible', 'hidden') THEN
    RAISE EXCEPTION 'invalid moderation status';
  END IF;

  IF normalized_type = 'wishes' THEN
    SELECT text INTO old_text FROM public.wishes WHERE id = content_id;
    UPDATE public.wishes
    SET moderation_status = normalized_status,
        hidden_at = CASE WHEN normalized_status = 'hidden' THEN NOW() ELSE NULL END,
        hidden_reason = CASE WHEN normalized_status = 'hidden' THEN COALESCE(reason, '管理员隐藏') ELSE NULL END
    WHERE id = content_id;
    GET DIAGNOSTICS changed_count = ROW_COUNT;
  ELSIF normalized_type = 'messages' THEN
    SELECT text INTO old_text FROM public.messages WHERE id = content_id;
    UPDATE public.messages
    SET moderation_status = normalized_status,
        hidden_at = CASE WHEN normalized_status = 'hidden' THEN NOW() ELSE NULL END,
        hidden_reason = CASE WHEN normalized_status = 'hidden' THEN COALESCE(reason, '管理员隐藏') ELSE NULL END
    WHERE id = content_id;
    GET DIAGNOSTICS changed_count = ROW_COUNT;
  ELSIF normalized_type IN ('capsules', 'time_capsules') THEN
    normalized_type := 'capsules';
    SELECT text INTO old_text FROM public.time_capsules WHERE id = content_id;
    UPDATE public.time_capsules
    SET moderation_status = normalized_status,
        hidden_at = CASE WHEN normalized_status = 'hidden' THEN NOW() ELSE NULL END,
        hidden_reason = CASE WHEN normalized_status = 'hidden' THEN COALESCE(reason, '管理员隐藏') ELSE NULL END
    WHERE id = content_id;
    GET DIAGNOSTICS changed_count = ROW_COUNT;
  ELSE
    RAISE EXCEPTION 'invalid content type';
  END IF;

  IF changed_count > 0 THEN
    PERFORM public.admin_write_audit_log(
      CASE WHEN normalized_status = 'hidden' THEN 'hide' ELSE 'restore' END,
      normalized_type,
      content_id,
      old_text,
      JSONB_BUILD_OBJECT('reason', reason)
    );
  END IF;
  RETURN changed_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_delete_content(content_type TEXT, content_id BIGINT, admin_token TEXT)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  normalized_type TEXT := LOWER(COALESCE(content_type, ''));
  deleted_count INTEGER := 0;
  old_text TEXT;
BEGIN
  IF NOT public.verify_admin_session(admin_token) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  IF normalized_type = 'wishes' THEN
    SELECT text INTO old_text FROM public.wishes WHERE id = content_id;
    DELETE FROM public.wishes WHERE id = content_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
  ELSIF normalized_type = 'messages' THEN
    SELECT text INTO old_text FROM public.messages WHERE id = content_id;
    DELETE FROM public.messages WHERE id = content_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
  ELSIF normalized_type IN ('capsules', 'time_capsules') THEN
    normalized_type := 'capsules';
    SELECT text INTO old_text FROM public.time_capsules WHERE id = content_id;
    DELETE FROM public.time_capsules WHERE id = content_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
  ELSE
    RAISE EXCEPTION 'invalid content type';
  END IF;

  IF deleted_count > 0 THEN
    PERFORM public.admin_write_audit_log('delete', normalized_type, content_id, old_text, '{}'::JSONB);
  END IF;
  RETURN deleted_count;
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
  deleted_count := public.admin_delete_content('wishes', wish_id, admin_token);
  RETURN deleted_count;
END;
$$;

REVOKE ALL ON FUNCTION public.base32_decode(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.bigint_to_big_endian(BIGINT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.totp_code(TEXT, BIGINT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.verify_admin_session(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.verify_admin_code(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_logout(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_write_audit_log(TEXT, TEXT, BIGINT, TEXT, JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_list_content(TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_list_audit_logs(TEXT, INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_set_content_status(TEXT, BIGINT, TEXT, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_delete_content(TEXT, BIGINT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_delete_wish(BIGINT, TEXT) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.verify_admin_session(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.verify_admin_code(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_logout(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_content(TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_audit_logs(TEXT, INTEGER) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_content_status(TEXT, BIGINT, TEXT, TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_content(TEXT, BIGINT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_wish(BIGINT, TEXT) TO anon, authenticated;

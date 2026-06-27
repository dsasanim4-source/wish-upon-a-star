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

-- ── 云端内容审核兜底 ────────────────────────────────────
-- 前端会先做体验友好的拦截；这里负责防止绕过页面直接写入公开数据表。
CREATE OR REPLACE FUNCTION public.normalize_moderation_text(input_text TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
DECLARE
  clean TEXT := LOWER(COALESCE(input_text, ''));
BEGIN
  clean := TRANSLATE(clean, '０１２３４５６７８９', '0123456789');
  clean := REPLACE(clean, '0', 'o');
  clean := REPLACE(clean, '1', 'i');
  clean := REPLACE(clean, '!', 'i');
  clean := REPLACE(clean, '！', 'i');
  clean := REPLACE(clean, '|', 'i');
  clean := REPLACE(clean, '3', 'e');
  clean := REPLACE(clean, '4', 'a');
  clean := REPLACE(clean, '@', 'a');
  clean := REPLACE(clean, '5', 's');
  clean := REPLACE(clean, '$', 's');
  clean := REPLACE(clean, '7', 't');
  RETURN REGEXP_REPLACE(clean, '[[:space:][:punct:]，。！？、；：“”‘’（）【】《》〈〉「」『』·…￥]+', '', 'g');
END;
$$;

CREATE OR REPLACE FUNCTION public.find_blocked_content_reason(input_text TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
DECLARE
  raw TEXT := LOWER(COALESCE(input_text, ''));
  compact TEXT := public.normalize_moderation_text(input_text);
BEGIN
  IF compact = '' THEN
    RETURN NULL;
  END IF;

  IF compact ~ '(.)\1{5,}' OR compact ~ '(.{2,6})\1{3,}' THEN
    RETURN '重复刷屏';
  END IF;

  IF compact ~ '(傻[逼屄比b]|煞笔|沙比|shabi|草泥马|艹你|肏|操你|操他|操她|操蛋|我操|卧槽|你妈|他妈|妈的|nmsl|cnm|fuck|shit|bitch|asshole|dick|cunt|fck|wtf)' THEN
    RETURN '脏话粗口';
  END IF;

  IF compact ~ '(去死|死全家|滚蛋|滚开|废物|垃圾|弱智|智障|脑残|低能|白痴|蠢货|贱人|贱货|婊|丑逼|舔狗|人渣|混蛋|王八蛋|杂种|畜生|废柴|欠揍|找打|恶心人|不要脸|没教养|活该)' THEN
    RETURN '侮辱攻击';
  END IF;

  IF compact ~ '(涉政|政治|政府|政权|党派|党员|共产党|中共|共党|国民党|民进党|主席|总统|总理|人大|政协|两会|选举|投票|罢免|游行|示威|罢工|革命|政变|独裁|专制|民主运动|言论自由|人权|宪法|公安|武警|军队|警察|台独|港独|藏独|疆独|台湾独立|法轮功|天安门|六四|8964|习近平|毛泽东|邓小平|江泽民|胡锦涛|蔡英文|赖清德|特朗普|拜登|普京|泽连斯基)' THEN
    RETURN '涉政敏感';
  END IF;

  IF compact ~ '(纳粹|恐怖主义|恐怖分子|isis|圣战|极端组织|种族灭绝|灭族|仇恨|歧视|黑鬼|支那|小日本|地域黑|女权癌)' OR compact ~ '杀光.{0,6}(人|族)' THEN
    RETURN '仇恨极端';
  END IF;

  IF compact ~ '(色情|黄色网站|黄片|a片|av女优|porn|sex|约炮|裸聊|卖淫|嫖|强奸|强暴|口交|肛交|阴茎|阴道|鸡巴|自慰|约p)' THEN
    RETURN '色情低俗';
  END IF;

  IF compact ~ '(杀人|杀了|弄死|砍死|捅死|打死|炸弹|爆炸|枪支|手枪|毒品|吸毒|贩毒|赌博|博彩|报复社会|自杀|割腕|跳楼|血腥|虐待)' THEN
    RETURN '暴力违法';
  END IF;

  IF raw ~ '(https?://|www\.|\.com|\.cn|\.net|\.org|\.vip|\.xyz|\.top)' OR compact ~ '(加微信|加微|vx|qq|二维码|刷单|贷款|返利|兼职|代写|代考|引流|推广|广告)' OR raw ~ '(\+?86)?1[3-9][0-9]{9}|[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}' THEN
    RETURN '广告引流';
  END IF;

  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.enforce_content_moderation()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  content_text TEXT;
  reason TEXT;
BEGIN
  IF TG_TABLE_NAME = 'constellations' THEN
    content_text := NEW.name;
  ELSE
    content_text := NEW.text;
  END IF;

  reason := public.find_blocked_content_reason(content_text);
  IF reason IS NOT NULL THEN
    RAISE EXCEPTION 'content rejected by star moderation: %', reason
      USING ERRCODE = '22023',
            HINT = '请换成更友善、更适合放进星空的表达。';
  END IF;

  RETURN NEW;
END;
$$;

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

DROP TRIGGER IF EXISTS enforce_wishes_content_moderation ON public.wishes;
CREATE TRIGGER enforce_wishes_content_moderation
  BEFORE INSERT OR UPDATE OF text ON public.wishes
  FOR EACH ROW EXECUTE FUNCTION public.enforce_content_moderation();

DROP TRIGGER IF EXISTS enforce_messages_content_moderation ON public.messages;
CREATE TRIGGER enforce_messages_content_moderation
  BEFORE INSERT OR UPDATE OF text ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.enforce_content_moderation();

DROP TRIGGER IF EXISTS enforce_time_capsules_content_moderation ON public.time_capsules;
CREATE TRIGGER enforce_time_capsules_content_moderation
  BEFORE INSERT OR UPDATE OF text ON public.time_capsules
  FOR EACH ROW EXECUTE FUNCTION public.enforce_content_moderation();

DROP TRIGGER IF EXISTS enforce_constellations_content_moderation ON public.constellations;
CREATE TRIGGER enforce_constellations_content_moderation
  BEFORE INSERT OR UPDATE OF name ON public.constellations
  FOR EACH ROW EXECUTE FUNCTION public.enforce_content_moderation();

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
REVOKE ALL ON FUNCTION public.normalize_moderation_text(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.find_blocked_content_reason(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.enforce_content_moderation() FROM PUBLIC;
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

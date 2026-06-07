-- ============================================================
-- OGD 甘特图 - 数据库迁移脚本 V2
-- 在 Supabase SQL Editor 中运行
-- ============================================================

-- 1. 先删除旧函数（如果已存在），避免返回类型冲突
DROP FUNCTION IF EXISTS admin_create_profile(uuid,text,text,text,text);
DROP FUNCTION IF EXISTS admin_update_user_status(uuid,text);

-- 2. 添加 status 列到 profiles 表（如尚无）
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active';

-- 3. 放宽 company CHECK 约束
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_company_check;

-- 4. 创建 RPC 函数：管理员创建档案（绕过 RLS）
CREATE OR REPLACE FUNCTION admin_create_profile(
  p_id UUID, p_email TEXT, p_name TEXT, p_company TEXT, p_role TEXT
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO profiles (id, email, name, company, role, status)
  VALUES (p_id, p_email, p_name, p_company, p_role, 'pending')
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    name = EXCLUDED.name,
    company = EXCLUDED.company,
    role = EXCLUDED.role;
END;
$$;

-- 5. 创建 RPC 函数：管理员更新用户状态（绕过 RLS）
CREATE OR REPLACE FUNCTION admin_update_user_status(
  user_id UUID, new_status TEXT
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  UPDATE profiles SET status = new_status WHERE id = user_id;
END;
$$;

-- 6. 更新 handle_new_user 触发器函数，加入 status 列
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, name, company, role, status)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'company', ''),
    COALESCE(NEW.raw_user_meta_data->>'role', 'member'),
    'active'
  );
  RETURN NEW;
END;
$$;


-- 7b. 添加缺失的 RLS 策略
-- activity_log insert（允许所有登录用户记录操作）
CREATE POLICY IF NOT EXISTS "activity_log_insert" ON activity_log FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- activity_log select（允许所有用户查看日志）
CREATE POLICY IF NOT EXISTS "activity_log_select" ON activity_log FOR SELECT
  USING (true);

-- profiles insert（允许管理员添加新档案）
CREATE POLICY IF NOT EXISTS "profiles_insert_admin" ON profiles FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role IN ('super_admin','admin'))
  );

-- 7. 修复已有数据的 status（如为 NULL 则设为 active）
UPDATE profiles SET status = 'active' WHERE status IS NULL;

-- 8. 验证
SELECT '✅ 迁移完成' as 状态;
SELECT id, email, name, company, role, status FROM profiles ORDER BY created_at;

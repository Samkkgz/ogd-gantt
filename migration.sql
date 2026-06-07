-- ============================================================
-- OGD 甘特图 - 数据库迁移脚本
-- 在现有数据库上运行，无需删表
-- ============================================================

-- 1. 添加 status 列到 profiles 表（如尚无）
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active';

-- 2. 放宽 company CHECK 约束
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_company_check;

-- 3. 创建 RPC 函数：管理员创建档案（绕过 RLS）
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

-- 4. 创建 RPC 函数：管理员更新用户状态（绕过 RLS）
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

-- 5. 更新 handle_new_user 触发器函数，加入 status 列
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

-- 6. 修复已有数据的 status（如为 NULL 则设为 active）
UPDATE profiles SET status = 'active' WHERE status IS NULL;

-- 7. 验证
SELECT '✅ 迁移完成' as 状态;
SELECT id, email, name, company, role, status FROM profiles ORDER BY created_at;

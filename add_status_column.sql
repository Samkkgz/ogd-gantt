-- ============================================================
-- 添加 status 字段到 profiles 表
-- ============================================================
-- 值说明:
--   pending  → 已邀请但未完成注册
--   active   → 已完成注册
--   inactive → 管理员停用

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending'
  CHECK (status IN ('pending', 'active', 'inactive'));

-- 不强制更新已有 profile
-- 已登录用户下次打开页面时 loadProfile() 会自动设为 active
-- 被邀请但未注册的用户保持 pending

-- 更新触发器：新用户通过邀请创建时 status = 'pending'
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, name, company, role, status)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data ->> 'name', split_part(NEW.email, '@', 1), 'New User'),
    COALESCE(NEW.raw_user_meta_data ->> 'company', 'ECS'),
    COALESCE(NEW.raw_user_meta_data ->> 'role', 'member'),
    'pending'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

SELECT '✅ status 字段已添加' as 结果;

-- ============================================================
-- OGD 项目数据库完整初始化脚本
-- 在 Supabase SQL Editor 中运行（一键执行）
-- ============================================================
-- 说明：此脚本包含所有表的创建、RLS 策略、触发器
-- 如果之前已运行过部分脚本，IDEMPOTENT（可重复执行）

-- ============================================================
-- 1. 创建 profiles 表（用户档案）
-- ============================================================
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  email TEXT,
  name TEXT DEFAULT '',
  company TEXT DEFAULT 'ECS',
  role TEXT DEFAULT 'member' CHECK (role IN ('super_admin', 'admin', 'member')),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'inactive')),
  avatar_url TEXT
);

-- 启用 RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- profiles 的 RLS 策略
DROP POLICY IF EXISTS "profiles_select_all" ON profiles;
DROP POLICY IF EXISTS "profiles_insert_self" ON profiles;
DROP POLICY IF EXISTS "profiles_update_admin" ON profiles;

-- 所有登录用户可查看所有 profile（用于选择上传者和团队成员列表）
CREATE POLICY "profiles_select_all" ON profiles FOR SELECT USING (true);
-- 用户可以插入自己的 profile（首次登录时自动创建）
CREATE POLICY "profiles_insert_self" ON profiles FOR INSERT
  WITH CHECK (id = auth.uid());
-- 管理员可以更新任何 profile（邀请/角色管理）
CREATE POLICY "profiles_update_admin" ON profiles FOR UPDATE
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('super_admin', 'admin')));

-- ============================================================
-- 2. 创建 file_metadata 表（文件元数据）
-- ============================================================
CREATE TABLE IF NOT EXISTS file_metadata (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now(),
  filename TEXT NOT NULL,
  original_name TEXT NOT NULL,
  file_size BIGINT NOT NULL,
  mime_type TEXT DEFAULT 'application/octet-stream',
  storage_path TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT '其他',
  uploaded_at TIMESTAMPTZ DEFAULT now(),
  uploaded_by UUID REFERENCES profiles(id) ON DELETE SET NULL
);

-- 启用 RLS
ALTER TABLE file_metadata ENABLE ROW LEVEL SECURITY;

-- file_metadata 的 RLS 策略
DROP POLICY IF EXISTS "files_read_all" ON file_metadata;
DROP POLICY IF EXISTS "files_insert_all" ON file_metadata;
DROP POLICY IF EXISTS "files_delete_admin" ON file_metadata;

CREATE POLICY "files_read_all" ON file_metadata FOR SELECT USING (true);
CREATE POLICY "files_insert_all" ON file_metadata FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "files_delete_admin" ON file_metadata FOR DELETE
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('super_admin', 'admin')));

-- ============================================================
-- 3. 创建 activity_log 表（操作日志）
-- ============================================================
CREATE TABLE IF NOT EXISTS activity_log (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  user_name TEXT,
  company TEXT,
  action TEXT NOT NULL,
  detail TEXT
);

ALTER TABLE activity_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "activity_log_insert_all" ON activity_log;
DROP POLICY IF EXISTS "activity_log_select_admin" ON activity_log;

CREATE POLICY "activity_log_insert_all" ON activity_log
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "activity_log_select_admin" ON activity_log
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('super_admin', 'admin'))
  );

-- ============================================================
-- 4. 创建 project_files 存储桶
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM storage.buckets WHERE name = 'project_files') THEN
    INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    VALUES ('project_files', 'project_files', false, 52428800, null);
    RAISE NOTICE '✅ project_files 存储桶已创建';
  ELSE
    RAISE NOTICE 'ℹ️ project_files 存储桶已存在';
  END IF;
END $$;

-- 删除旧存储桶策略
DROP POLICY IF EXISTS "storage_insert_admin" ON storage.objects;
DROP POLICY IF EXISTS "storage_delete_admin" ON storage.objects;
DROP POLICY IF EXISTS "storage_read_all" ON storage.objects;
DROP POLICY IF EXISTS "storage_insert_all" ON storage.objects;

-- 创建新存储桶策略
CREATE POLICY "storage_read_all" ON storage.objects FOR SELECT
  USING (bucket_id IN (SELECT id FROM storage.buckets WHERE name = 'project_files'));

CREATE POLICY "storage_insert_all" ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id IN (SELECT id FROM storage.buckets WHERE name = 'project_files')
    AND auth.role() = 'authenticated'
  );

CREATE POLICY "storage_delete_admin" ON storage.objects FOR DELETE
  USING (
    bucket_id IN (SELECT id FROM storage.buckets WHERE name = 'project_files')
    AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('super_admin', 'admin'))
  );

-- ============================================================
-- 5. 创建首次登录自动创建 profile 的触发器
-- ============================================================
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

-- 删除已有的触发器避免重复
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- 创建触发器：当新用户注册时自动创建 profile
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

SELECT '✅ OGD 数据库初始化完成' as 状态;
SELECT 'ℹ️ 现在所有登录用户都可以上传文件' as 提示;
SELECT 'ℹ️ 只有管理员可以删除文件' as 提示2;

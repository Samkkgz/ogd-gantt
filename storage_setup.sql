-- ============================================================
-- OGD 文件存储系统 - Supabase 设置
-- 在 Supabase SQL Editor 中运行
-- ============================================================

-- 1. 创建文件元数据表
CREATE TABLE IF NOT EXISTS file_metadata (
  id BIGSERIAL PRIMARY KEY,
  filename TEXT NOT NULL,
  original_name TEXT NOT NULL,
  file_size BIGINT NOT NULL,
  mime_type TEXT,
  storage_path TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('项目立项文件', '执行标准', '会议纪要', '周期性报告', '其他')),
  uploaded_by UUID REFERENCES profiles(id),
  uploaded_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE file_metadata ENABLE ROW LEVEL SECURITY;

-- 2. RLS 策略
CREATE POLICY "files_read_all" ON file_metadata FOR SELECT USING (true);
CREATE POLICY "files_insert_admin" ON file_metadata FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('super_admin', 'admin')));
CREATE POLICY "files_delete_admin" ON file_metadata FOR DELETE
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('super_admin', 'admin')));

-- 3. 存储桶 RLS 策略（需要在创建桶后运行）
-- 先在 Supabase → Storage → 创建 bucket "project_files"（公开）
-- 然后运行以下 SQL：

-- 所有人可下载
CREATE POLICY "storage_read_all" ON storage.objects FOR SELECT
  USING (bucket_id = 'project_files');

-- 管理员可上传
CREATE POLICY "storage_insert_admin" ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'project_files' 
    AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('super_admin', 'admin'))
  );

-- 管理员可删除
CREATE POLICY "storage_delete_admin" ON storage.objects FOR DELETE
  USING (
    bucket_id = 'project_files'
    AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('super_admin', 'admin'))
  );

SELECT '✅ 文件存储系统已就绪' as 状态;

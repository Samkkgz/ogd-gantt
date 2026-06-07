-- ============================================================
-- 🚀 OGD 甘特图 - 一键设置脚本
-- 复制整个文件内容，粘贴到 Supabase SQL Editor 运行
-- ============================================================

-- 先清理（如果已存在则删除）
DROP TABLE IF EXISTS activity_log;
DROP TABLE IF EXISTS tasks;
DROP TABLE IF EXISTS profiles;
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- ============================================================
-- 1. 创建表
-- ============================================================

-- 用户档案表
CREATE TABLE profiles (
  id UUID REFERENCES auth.users PRIMARY KEY,
  email TEXT,
  name TEXT,
  company TEXT CHECK (company IN ('ECS', '嘉顿', 'admin')),
  role TEXT CHECK (role IN ('member', 'admin', 'super_admin')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 任务表
CREATE TABLE tasks (
  id BIGSERIAL PRIMARY KEY,
  phase TEXT NOT NULL,
  content TEXT NOT NULL,
  deliverable TEXT NOT NULL,
  company TEXT,
  responsible TEXT,
  start_date DATE,
  end_date DATE,
  status TEXT DEFAULT '',
  milestone BOOLEAN DEFAULT FALSE,
  created_by UUID REFERENCES profiles(id),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 操作日志表
CREATE TABLE activity_log (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES profiles(id),
  user_name TEXT,
  action TEXT,
  detail TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 2. 自动创建用户档案
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, name, company, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'company', ''),
    COALESCE(NEW.raw_user_meta_data->>'role', 'member')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- 3. 开启行级安全
-- ============================================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_log ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 4. 权限策略
-- ============================================================

-- --- 档案策略 ---
CREATE POLICY "profiles_read_all" ON profiles FOR SELECT USING (true);
CREATE POLICY "profiles_update_super" ON profiles FOR UPDATE
  USING (auth.uid() IN (SELECT id FROM profiles WHERE role = 'super_admin'))
  WITH CHECK (auth.uid() IN (SELECT id FROM profiles WHERE role = 'super_admin'));
CREATE POLICY "profiles_update_company_admin" ON profiles FOR UPDATE
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin' AND p.company = profiles.company))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin' AND p.company = profiles.company));

-- --- 任务策略 ---
CREATE POLICY "tasks_read_all" ON tasks FOR SELECT USING (true);
CREATE POLICY "tasks_all_super" ON tasks FOR ALL
  USING (auth.uid() IN (SELECT id FROM profiles WHERE role = 'super_admin'))
  WITH CHECK (auth.uid() IN (SELECT id FROM profiles WHERE role = 'super_admin'));
CREATE POLICY "tasks_admin_company" ON tasks FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role IN ('admin','super_admin') AND (p.company = tasks.company OR tasks.company IS NULL OR tasks.company = '')))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role IN ('admin','super_admin') AND (p.company = tasks.company OR tasks.company IS NULL OR tasks.company = '')));
CREATE POLICY "tasks_member_update" ON tasks FOR UPDATE
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'member' AND (p.company = tasks.company OR tasks.company = '嘉顿/ECS')))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'member' AND (p.company = tasks.company OR tasks.company = '嘉顿/ECS')));
CREATE POLICY "tasks_member_insert" ON tasks FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'member' AND (p.company = tasks.company OR tasks.company = '嘉顿/ECS')));

-- ============================================================
-- 5. 初始种子数据（36项任务）
-- ============================================================

INSERT INTO tasks (phase, content, deliverable, company, responsible, start_date, end_date, status, milestone) VALUES
('准备阶段', '业务机会分析', '确定目标城市', '嘉顿', 'Lori', '2026-06-02', '2026-06-02', '完成', TRUE),
('准备阶段', '业务机会分析', '渠道及门店清单', 'ECS', 'Lilia', '2026-06-03', '2026-06-15', '进行中', FALSE),
('准备阶段', '业务机会分析', '确定目标门店清单', '嘉顿', 'Lori/何纪辉', '2026-06-15', '2026-06-30', '', FALSE),
('准备阶段', '项目策略', '渠道及产品策略', '嘉顿', 'Lim/Carlson制定，Lori确认', '2026-06-03', '2026-06-10', '进行中', TRUE),
('准备阶段', '供应链流程', '确定供应链具体对接方案', '嘉顿', '蒋大方', '2026-06-08', '2026-06-12', '', FALSE),
('准备阶段', '财务对接流程', '确定财务具体对接方案', '嘉顿', '张振兴', '2026-06-08', '2026-06-12', '', FALSE),
('准备阶段', '项目目标', '确定分销产品清单', '嘉顿', 'Lim/Carlson制定，Lori确认', NULL, '2026-06-10', '进行中', TRUE),
('准备阶段', '项目目标', '分销目标', '嘉顿', 'Lori/何纪辉', '2026-06-15', '2026-06-30', '', FALSE),
('准备阶段', '项目目标', '门店活跃率目标', '嘉顿', 'Lori/何纪辉', '2026-06-15', '2026-06-30', '', FALSE),
('准备阶段', '项目目标', '门店上翻目标', '嘉顿', 'Lori/何纪辉', '2026-06-15', '2026-06-30', '', FALSE),
('准备阶段', '项目目标', 'AAM指标及衡量标准', '嘉顿/ECS', 'Joanne/Sam', '2026-06-03', '2026-06-15', '进行中', FALSE),
('准备阶段', '执行标准', '确定渠道门店分销标准', '嘉顿', 'Lim/Carlson制定，Lori确认', '2026-06-03', '2026-06-10', '进行中', FALSE),
('准备阶段', '执行标准', '确定渠道陈列标准', '嘉顿', 'Lim/Carlson', '2026-06-03', '2026-06-10', '进行中', FALSE),
('准备阶段', '执行标准', '确定渠道销售套餐', '嘉顿', 'Lim/Carlson', '2026-06-03', '2026-06-10', '进行中', FALSE),
('准备阶段', '项目奖励机制', '销售团队奖励机制', '嘉顿', 'Lim/Carlson', '2026-06-03', '2026-06-10', '进行中', FALSE),
('准备阶段', '项目奖励机制', '客户奖励机制', '嘉顿', 'Lim/Carlson', '2026-06-03', '2026-06-10', '进行中', FALSE),
('准备阶段', '项目流程', '确定供应链流程', '嘉顿/ECS', 'Lim/Lila', '2026-06-03', '2026-06-10', '', FALSE),
('准备阶段', '项目流程', '确定财务流程', '嘉顿/ECS', 'Lim/Lila', '2026-06-03', '2026-06-10', '', FALSE),
('准备阶段', '项目预算', '项目预估', '嘉顿', 'Lori/Lim', '2026-06-11', '2026-06-25', '', FALSE),
('准备阶段', '项目预算', '制定项目预算', '嘉顿', 'Lori/Lim', '2026-06-11', '2026-06-25', '', FALSE),
('准备阶段', '项目预算', '确定项目预算', '嘉顿', 'Lori/Lim', '2026-06-11', '2026-06-25', '', TRUE),
('准备阶段', '项目流程', '确认服务形式及费用', '嘉顿/ECS', 'Lori/Sam', '2026-06-10', '2026-06-15', '', FALSE),
('准备阶段', '项目流程', '完成合同签署', '嘉顿/ECS', 'Lori/Sam', '2026-06-15', '2026-06-30', '', TRUE),
('准备阶段', '团队沟通', '一线团队培训', 'ECS', 'Lila', '2026-07-03', '2026-07-03', '', TRUE),
('准备阶段', '可持续机制', '商城活动', 'ECS', 'Lila', '2026-06-16', '2026-06-26', '', FALSE),
('准备阶段', '可持续机制', '商城内容', 'ECS', 'Lila', '2026-06-16', '2026-06-30', '', FALSE),
('准备阶段', '技术解决方案', '系统配置', 'ECS', 'Lila', '2026-07-01', '2026-07-06', '进行中', FALSE),
('准备阶段', '技术解决方案', '商城配置', 'ECS', 'Lila', '2026-07-01', '2026-07-06', '进行中', FALSE),
('项目实施', '项目上线', '项目正式启动', '嘉顿/ECS', 'Lori/Lilia', '2026-07-10', '2026-07-10', '', TRUE),
('实施阶段', '拓店管理', '销售拓、店内执行及活跃率管理', 'ECS', 'Lila', NULL, NULL, '', FALSE),
('实施阶段', '拓店管理', '订货商城运营', 'ECS', 'Lila', NULL, NULL, '', FALSE),
('实施阶段', '建立项目追踪体系', '每日项目进度追踪报告', 'ECS', 'Lila', NULL, NULL, '', FALSE),
('实施阶段', '建立项目追踪体系', '每周项目进度回顾及调优', 'ECS', 'Lila', NULL, NULL, '', FALSE),
('回顾阶段', '项目回顾及调优', '项目周期性评估（每月）', 'ECS', 'Lila', '2026-08-01', '2026-08-10', '', TRUE),
('回顾阶段', '项目回顾及调优', 'AAM指标评估', 'ECS', 'Sam', '2026-08-01', '2026-08-10', '', FALSE),
('回顾阶段', '项目回顾及调优', '项目调优建议', 'ECS', 'Sam', '2026-08-01', '2026-08-10', '', FALSE),
('回顾阶段', '项目回顾及调优', '制定调优行动方案', 'ECS', 'Sam', '2026-08-01', '2026-08-10', '', FALSE);

SELECT setval('tasks_id_seq', (SELECT MAX(id) FROM tasks));
SELECT '✅ 数据库设置完成！' as 状态;
SELECT COUNT(*) || ' 条任务已导入' as 结果 FROM tasks;

-- ============================================================
-- OGD Gantt Web App - Supabase Schema
-- Run this in Supabase SQL Editor after creating your project
-- ============================================================

-- 1. Profiles (auto-created on signup via trigger)
CREATE TABLE IF NOT EXISTS profiles (
  id UUID REFERENCES auth.users PRIMARY KEY,
  email TEXT,
  name TEXT,
  company TEXT,
  role TEXT CHECK (role IN ('member', 'admin', 'super_admin')),
  status TEXT DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- 2. Tasks
CREATE TABLE IF NOT EXISTS tasks (
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

ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- 3. Activity log (track who changed what)
CREATE TABLE IF NOT EXISTS activity_log (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES profiles(id),
  user_name TEXT,
  action TEXT,
  detail TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE activity_log ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- AUTO-CREATE PROFILE ON SIGNUP
-- ============================================================
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

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- ROW LEVEL SECURITY POLICIES
-- ============================================================

-- --- PROFILES ---
CREATE POLICY "profiles_read_all"
  ON profiles FOR SELECT
  USING (true);

CREATE POLICY "profiles_update_super_admin"
  ON profiles FOR UPDATE
  USING (auth.uid() IN (SELECT id FROM profiles WHERE role = 'super_admin'))
  WITH CHECK (auth.uid() IN (SELECT id FROM profiles WHERE role = 'super_admin'));

CREATE POLICY "profiles_update_company_admin"
  ON profiles FOR UPDATE
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin' AND p.company = profiles.company))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin' AND p.company = profiles.company));

-- --- RPC FUNCTIONS ---
CREATE OR REPLACE FUNCTION admin_create_profile(
  p_id UUID, p_email TEXT, p_name TEXT, p_company TEXT, p_role TEXT
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
  INSERT INTO profiles (id, email, name, company, role, status)
  VALUES (p_id, p_email, p_name, p_company, p_role, 'pending')
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email, name = EXCLUDED.name, company = EXCLUDED.company, role = EXCLUDED.role, status = 'pending';
$$;

CREATE OR REPLACE FUNCTION admin_update_user_status(user_id UUID, new_status TEXT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
  UPDATE profiles SET status = new_status WHERE id = user_id;
$$;


-- --- ACTIVITY LOG POLICIES ---
CREATE POLICY "activity_log_insert"
  ON activity_log FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "activity_log_select"
  ON activity_log FOR SELECT
  USING (true);

-- --- PROFILES INSERT ---
CREATE POLICY "profiles_insert_admin"
  ON profiles FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role IN ('super_admin','admin'))
  );

-- --- TASKS ---
CREATE POLICY "tasks_read_all"
  ON tasks FOR SELECT
  USING (true);

CREATE POLICY "tasks_all_super_admin"
  ON tasks FOR ALL
  USING (auth.uid() IN (SELECT id FROM profiles WHERE role = 'super_admin'))
  WITH CHECK (auth.uid() IN (SELECT id FROM profiles WHERE role = 'super_admin'));

CREATE POLICY "tasks_admin_company"
  ON tasks FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role IN ('admin', 'super_admin') AND (p.company = tasks.company OR tasks.company IS NULL OR tasks.company = '')))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role IN ('admin', 'super_admin') AND (p.company = tasks.company OR tasks.company IS NULL OR tasks.company = '')));

CREATE POLICY "tasks_member_update"
  ON tasks FOR UPDATE
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'member' AND (p.company = tasks.company OR tasks.company = '嘉顿/ECS')))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'member' AND (p.company = tasks.company OR tasks.company = '嘉顿/ECS')));

CREATE POLICY "tasks_member_insert"
  ON tasks FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'member' AND (p.company = tasks.company OR tasks.company = '嘉顿/ECS')));

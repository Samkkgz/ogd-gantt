# 🏗️ OGD 分销拓展项目 — 团队协作甘特图

多公司、多角色协作的项目甘特图工具。基于 GitHub Pages + Supabase 构建，零服务器运维。

## 🎯 适用场景

- 项目涉及 **多个公司/团队** 协作（如本项目的嘉顿 & ECS）
- 需要 **简单权限管理**：每个公司只能编辑自己的任务
- 团队成员通过 **邮箱链接** 登录，无需密码

## 🏗️ 技术架构

```
GitHub Pages (前端)  ←→  Supabase (数据库 + 认证 + 权限)
```

| 组件 | 用途 | 费用 |
|---|---|---|
| GitHub Pages | 托管网页 | 免费 |
| Supabase | PostgreSQL 数据库、邮箱认证、行级权限 | 免费套餐足够 |

## ⚙️ 部署步骤

### 第一步：创建 GitHub 仓库

1. 在 GitHub 新建仓库，命名为 `ogd-gantt`（公开或私有均可）
2. 将本目录的所有文件推送到该仓库

### 第二步：创建 Supabase 项目

1. 打开 [supabase.com](https://supabase.com) → 点击 **Start your project**
2. 创建项目（选 Free 套餐，Region 选 Singapore 或 Tokyo 对中国访问更快）
3. 创建完成后，去到 **Project Settings → API**，复制：
   - `Project URL` → 这就是 `SUPABASE_URL`
   - `anon public key` → 这就是 `SUPABASE_ANON_KEY`
4. 在 `index.html` 文件开头的配置区填入这两个值

### 第三步：配置数据库

1. 在 Supabase 面板 → **SQL Editor**
2. 复制 `schema.sql` 全部内容，粘贴运行
3. 运行成功后，你有 `profiles` 和 `tasks` 两张表

### 第四步：创建管理员账号

1. 在 Supabase 面板 → **Authentication → Users** → **Add User**
2. 输入你的邮箱（Sam），创建用户
3. **Authentication → Settings** 确保 **Email Auth** 已开启
4. 回到 **SQL Editor**，运行以下 SQL 将你的账号设为超级管理员：
   ```sql
   UPDATE profiles SET role = 'super_admin', company = 'admin' WHERE email = '你的邮箱@xxx.com';
   ```

### 第五步：部署到 GitHub Pages

1. 在你 GitHub 仓库 → **Settings → Pages**
2. Source 选 **Deploy from branch**，Branch 选 `main`，目录选 `/`(root)
3. 等待几分钟，你会得到类似 `https://你的用户名.github.io/ogd-gantt/` 的网址

### 第六步：配置 Supabase 的重定向 URL

1. Supabase 面板 → **Authentication → URL Configuration**
2. 在 **Site URL** 填入你的 GitHub Pages 网址
3. 在 **Redirect URLs** 添加：`https://你的用户名.github.io/ogd-gantt/**`

### 第七步：邀请团队成员

1. 用管理员邮箱打开部署好的网址 → 输入邮箱 → 点击发送登录链接
2. 在邮箱中点击链接登录
3. 点击右上角 **⚙️ 管理** → 在邀请表单中添加团队成员邮箱
4. 系统会向成员邮箱发送登录链接

## 👥 权限说明

| 角色 | 能力 |
|---|---|
| 🛠️ **超级管理员 (Sam)** | 完全控制，管理所有公司和成员 |
| 🔧 **公司管理员 (Lilia / Lori)** | 管理本公司成员，编辑本公司任务 |
| 👤 **成员** | 编辑本公司任务（增/改），不能删除 |

## 📁 项目文件说明

```
ogd-gantt-web/
├── index.html       # 主应用（单页应用）
├── schema.sql       # Supabase 数据库建表语句
└── README.md        # 本说明文件
```

## 🔄 用于其他项目

1. 复制本仓库到新仓库
2. 清空 `tasks` 表数据
3. 修改 `index.html` 中的项目名称和初始数据
4. 重新部署即可

## ⚠️ 注意事项

- Supabase 免费套餐包含 50000 条记录/月，完全够用
- 邮箱登录链接有效期 1 小时，过期需重新发送
- 所有数据存储在 Supabase 云端，换设备登录数据依然在

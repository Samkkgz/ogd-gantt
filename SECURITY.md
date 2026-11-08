# 安全策略

## 支持的版本

| 版本 | 支持状态 |
| --- | --- |
| `main`（当前线上版本） | ✅ 支持 |
| 历史提交与未合并分支 | ❌ 不单独维护安全修复 |

## 安全模型

本项目是「GitHub Pages 静态前端 + Supabase」架构：

- 前端代码和 Supabase `anon` / `publishable` key 都是公开信息，**不是密钥**。
- 真正的权限边界是 Supabase 的 **Row Level Security (RLS)**、数据库函数权限和 Storage 策略。
- `service_role` key、数据库密码、JWT secret 只能保存在服务端或本地环境变量中，**绝对禁止**写入 HTML、JavaScript、SQL 种子文件或提交到仓库。
- 前端不是可信执行环境：任何权限判断都必须在数据库侧再校验一次。

## 报告安全问题

请通过 GitHub 的私密漏洞报告功能提交：

<https://github.com/Samkkgz/ogd-gantt/security/advisories/new>

请勿在公开 Issue 中披露可利用细节、真实用户数据或密钥。收到报告后会在 72 小时内确认，并在修复发布后致谢（如你愿意公开署名）。

## 部署安全基线

上线或重新部署前，请逐项确认：

1. `public` schema 中所有业务表均已启用 RLS，且默认拒绝未登录访问。
2. 前端只使用 `anon` / `publishable` key；仓库与构建产物中不存在 `service_role` key。
3. 如非必须，关闭 Supabase 的公开注册（Allow new users to sign up），账号由管理员创建或邀请。
4. `project_files` Storage bucket 保持 **private**；下载与上传策略只对已登录用户开放。
5. GitHub Pages 只发布前端运行所需文件，不发布 `*.sql`、种子数据、`AGENTS.md`、脚本和内部文档。
6. 所有用户可控文本在写入 `innerHTML` 前必须转义；优先使用 `textContent`。
7. 外部 CDN 依赖固定版本并启用 SRI；生产环境建议增加 CSP。
8. 项目迁移、密钥轮换或人员变动后，复核 RLS 策略、Storage 策略和管理员名单。
9. 生产数据导入、删除或批量修正前先备份，并在 `VERSIONS.md` / 发布记录中登记。

## 依赖与供应链

- 前端通过 CDN 加载 `@supabase/supabase-js`，应固定到明确版本并校验完整性。
- GitHub Actions 仅使用必要权限；发布产物应排除数据库脚本和内部文档。
- 发现依赖漏洞时，优先升级到官方修复版本，并重新执行部署验证。

## 许可证

本项目采用 [MIT License](LICENSE)。

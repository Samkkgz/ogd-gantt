# ogd-gantt 开发规则

## 分支策略
- **永远不要在 main 分支上直接开发**
- 从 develop 创建功能分支: feat/<功能名>
- 所有变更必须先通过本地验证

## 验证闸门
在 git push 之前，必须运行:
```bash
bash scripts/dev-validate.sh
```

## 提交流程
功能分支 → develop → PR → main → 自动部署到 GitHub Pages

## 禁止
- ❌ 未测试的代码推送到 main
- ❌ 硬编码密钥
- ❌ 跳过验证步骤

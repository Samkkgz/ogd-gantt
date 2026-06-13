#!/usr/bin/env bash
set -e
echo "=== ogd-gantt 本地验证闸门 ==="
ERRORS=0

echo "[1/3] 检查 HTML 文件..."
for f in *.html; do
  [ -f "$f" ] || continue
  grep -q '<!DOCTYPE html>' "$f" && echo "  ✅ $f DOCTYPE 正确" || { echo "  ❌ $f 缺少 DOCTYPE"; ((ERRORS++)); }
  grep -q '</html>' "$f" && echo "  ✅ $f 闭合标签正确" || { echo "  ❌ $f 缺少闭合标签"; ((ERRORS++)); }
done

echo "[2/3] 检查硬编码密钥..."
if grep -r --include='*.html' --include='*.js' --include='*.sql' \
  -E '(api[_-]?key|secret|password|token)\s*[:=]\s*["'"'"']' . --exclude-dir=.git --exclude-dir=.github 2>/dev/null; then
  echo "  ❌ 发现可能的硬编码密钥"
  ((ERRORS++))
else
  echo "  ✅ 无明显密钥泄露"
fi

echo "[3/3] 检查 Git 分支..."
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$BRANCH" = "main" ]; then
  echo "  ⚠️  你在 main 分支上开发！建议切换到 develop 或功能分支"
fi

if [ $ERRORS -gt 0 ]; then
  echo "❌ 验证未通过，$ERRORS 个错误"
  exit 1
fi
echo "✅ 全部验证通过"

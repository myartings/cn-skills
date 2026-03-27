#!/usr/bin/env bash
# cn-skills 安装脚本
# 将所有 skill 克隆到 ~/.claude/skills/，供 Claude Code 使用
set -e

REPOS="doubanskill:douban v2exskill:v2ex zhihuskill:zhihu jikeskill:jike wechatskill:wechat"
BASE="$HOME/.claude/skills"

mkdir -p "$BASE"

for entry in $REPOS; do
  repo="${entry%:*}"
  name="${entry#*:}"
  target="$BASE/$name"

  if [ -d "$target" ]; then
    echo "[$name] 已存在，跳过（如需更新请运行 cd $target && git pull）"
  else
    echo "[$name] 克隆中..."
    git clone "https://github.com/myartings/$repo" "$target"
    echo "[$name] 完成"
  fi
done

echo ""
echo "安装完成！首次使用每个 skill 时，按提示运行 setup.sh 初始化。"

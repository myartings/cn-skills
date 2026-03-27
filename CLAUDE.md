# Self Skills 开发标准

本仓库统一管理所有自研 OpenClaw Skill 项目。以下是从现有项目（douban、v2ex、zhihu、jike、wechat）中提炼的共同开发标准，新 skill 应遵循这些约定。

## 两种 Skill 架构

### 类型 A：Python CLI Skill（douban、v2ex、zhihu）

纯 Python 3 标准库实现，零第三方依赖，通过 CLI 命令调用。

```
<skill-name>/
├── CLAUDE.md                    # 架构文档（给开发者看）
├── SKILL.md                     # OpenClaw 根 skill 定义（YAML frontmatter）
├── scripts/
│   ├── setup.sh                 # 初始化脚本
│   └── <name>_client.py         # CLI 客户端（唯一入口）
└── skills/                      # 子 skill 目录
    ├── <name>-search/SKILL.md
    ├── <name>-xxx/SKILL.md
    └── ...
```

### 类型 B：Go MCP Server Skill（jike、wechat）

Go 实现的 MCP Server，提供 MCP + REST 双接口。

```
<skill-name>/
├── CLAUDE.md                    # 架构文档
├── SKILL.md                     # OpenClaw 根 skill 定义
├── README.md                    # 用户文档
├── go.mod / go.sum
├── main.go                      # 入口，CLI flags（--port）
├── app_server.go                # AppServer 容器（service + mcp server）
├── service.go                   # 业务层（代理到 client 包）
├── mcp_server.go                # MCP tool 注册
├── mcp_handlers.go              # MCP handler 实现
├── routes.go                    # REST API 路由
├── <name>/                      # API 客户端包
│   ├── client.go                # HTTP 客户端
│   ├── types.go                 # 数据类型
│   └── <功能>.go                # 按功能拆分
├── scripts/
│   ├── setup.sh                 # 编译 + 启动
│   └── <name>_client.py         # Python CLI 封装（调用 REST API）
└── skills/                      # 子 skill 目录
    └── ...
```

---

## SKILL.md 规范

根 SKILL.md 使用 YAML frontmatter，格式：

```yaml
---
name: <skill-name>
description: |
  一句话功能描述。
  触发关键词列举（用户提到这些词时激活 skill）。
---

# 规则

1. **只用下面的命令，禁止用 curl、wget 或其他方式。**
2. 首次使用先运行初始化：`cd ~/.openclaw/skills/<name> && bash scripts/setup.sh`
3. （如需登录）未登录时引导用户导入 Cookie / 扫码登录

# 命令

`P` 代表 `python3 ~/.openclaw/skills/<name>/scripts/<name>_client.py`。

## 无需登录

| 功能 | 命令 |
|------|------|
| xxx  | `P xxx "参数"` |

## 需要登录

| 功能 | 命令 |
|------|------|
| xxx  | `P xxx <参数>` |

# 示例

（给出 2-3 个典型用例的完整命令）
```

### 子 Skill SKILL.md

每个子 skill 聚焦单一功能类别，格式更简洁：

```yaml
---
name: <parent>-<category>
description: |
  具体功能描述。当用户想要 xxx 时使用。
---

# 规则
（同根 skill 的命令约束）

# 命令
（只列本类别的命令）

# 展示格式
（指导 AI 如何格式化输出）
```

---

## CLAUDE.md 规范

面向开发者的架构文档，包含以下章节：

```markdown
# <Skill Name>

一句话定位。

## 架构

- 技术选型说明（纯 Python / Go + MCP SDK 等）
- 数据来源与接口说明
- 反爬/鉴权策略

## 项目结构

（目录树 + 各文件说明）

## 数据来源

| 功能 | 数据来源 | 需要登录 |
|------|----------|----------|
| ...  | ...      | 是/否    |

## 添加新功能

（分步骤说明扩展流程）

## 测试

（手动测试命令示例）
```

---

## Python CLI 客户端约定（类型 A）

### 依赖
- **仅用 Python 3 标准库**：urllib、json、re、hashlib、html 等
- 禁止引入第三方包

### 代码结构
```python
#!/usr/bin/env python3
"""<name> CLI client."""

import sys, os, json, re, urllib.request, urllib.parse, urllib.error

# === 常量 ===
SKILL_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COOKIE_FILE = os.path.join(SKILL_DIR, "cookies.json")
HEADERS = { "User-Agent": "...", "Accept": "...", "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8" }

# === 工具函数 ===
def fetch(url, headers=None): ...
def fetch_json(url, params=None): ...
def strip_html(text): ...
def truncate(text, length=200): ...

# === 命令函数 ===
def cmd_search(keyword): ...
def cmd_xxx(arg1): ...

# === 入口 ===
def main():
    commands = {
        "search":  (cmd_search, 1),   # (函数, 参数个数)
        "xxx":     (cmd_xxx, 1),
    }
    if len(sys.argv) < 2 or sys.argv[1] not in commands:
        print("用法: ... <command> [args]")
        print("可用命令:", ", ".join(sorted(commands)))
        sys.exit(1)

    name = sys.argv[1]
    func, nargs = commands[name]
    args = sys.argv[2:2+nargs]
    if len(args) < nargs:
        print(f"错误: {name} 需要 {nargs} 个参数")
        sys.exit(1)
    func(*args)

if __name__ == "__main__":
    main()
```

### 命名约定
- 命令函数：`cmd_<name>(arg1, arg2, ...)`
- 内部辅助函数：`_helper_name()`
- CLI 命令名：小写连字符 `search-movie`、`node-topics`

### 搜索策略
- 优先使用平台自身 API
- 备选方案：DuckDuckGo `site:xxx.com` 搜索
- 双通道容错：主通道失败自动切到备选

### Cookie 管理
- 文件格式：JSON 数组（Cookie-Editor 浏览器扩展导出格式）
- 存放路径：`<skill-dir>/cookies.json`
- 字段：name、value、domain、path、secure、expirationDate、httpOnly

### 错误处理
- HTTP 401 → "需要登录"
- HTTP 403 → "访问被限制，可能触发了频率限制"
- HTTP 404 → "未找到"
- 网络超时：15 秒

### 输出格式
- 纯文本，简洁格式化
- 编号列表 + 缩进详情
- 摘要默认截断 150-200 字符
- 包含 ID/链接方便后续操作

---

## Go MCP Server 约定（类型 B）

### 依赖
- Web 框架：`github.com/gin-gonic/gin`
- MCP SDK：`github.com/modelcontextprotocol/go-sdk`
- 按需引入：goquery（HTML 解析）、go-qrcode（二维码）等

### 分层架构
```
main.go          → CLI flags + 启动
app_server.go    → 容器（组装 service + mcp server）
service.go       → 业务层（薄代理，委托给 client 包）
mcp_server.go    → MCP tool 注册（inputSchema 定义）
mcp_handlers.go  → MCP handler 实现
routes.go        → REST API 路由（Gin）
<name>/          → API 客户端包
```

### MCP Handler 模式
```go
func (s *AppServer) handleXxx(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
    args := parseArgs(req)
    param := getStringArg(args, "param_name")
    if param == "" {
        return errorResult(fmt.Errorf("缺少参数: param_name")), nil
    }
    result, err := s.service.Xxx(ctx, param)
    if err != nil {
        return errorResult(err), nil
    }
    return textResult(toJSON(result)), nil
}
```

### 辅助函数（所有项目共用模式）
```go
func parseArgs(req mcp.CallToolRequest) map[string]any { ... }
func getStringArg(args map[string]any, key string) string { ... }
func getIntArg(args map[string]any, key string, def int) int { ... }
func toJSON(v any) string { ... }           // json.MarshalIndent
func textResult(text string) *mcp.CallToolResult { ... }
func errorResult(err error) *mcp.CallToolResult { ... }  // IsError: true
```

### REST API 约定
- 路由前缀：`/api/v1/`
- 查询用 POST + JSON body，状态检查用 GET
- 响应格式：`{"data": ...}` 或 `{"error": "..."}`
- MCP 端点：`/mcp`（SSE）

### 错误处理
- 错误携带上下文：`fmt.Errorf("operation: %w", err)`
- MCP 返回 `errorResult(err)`（IsError=true）
- REST 返回 HTTP 错误码 + JSON error

### Token/认证管理
- Token 文件权限 0600
- 线程安全（sync.RWMutex）
- 自动刷新（401 时重试）

---

## setup.sh 标准模板

### 类型 A（Python）
```bash
#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== <Name> Skill 初始化 ==="

if ! command -v python3 &>/dev/null; then
    echo "错误: 需要 python3，请先安装"
    exit 1
fi
echo "python3: $(python3 --version)"

echo "测试客户端 ..."
python3 "$SCRIPT_DIR/<name>_client.py" 2>&1 | head -3

echo "初始化完成!"
```

### 类型 B（Go）
```bash
#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
BIN="$SKILL_DIR/<name>-mcp"
PORT=<默认端口>

# 编译（源码比二进制新时重新编译）
if [ ! -f "$BIN" ] || [ "$(find "$SKILL_DIR" -name '*.go' -newer "$BIN" 2>/dev/null)" ]; then
    echo "编译中 ..."
    cd "$SKILL_DIR" && go build -o "$BIN" .
fi

# 启动（未运行时启动）
if ! lsof -i ":$PORT" &>/dev/null; then
    nohup "$BIN" --port "$PORT" > /tmp/<name>-mcp.log 2>&1 &
    sleep 1
fi

# 验证
python3 "$SCRIPT_DIR/<name>_client.py" status
echo "初始化完成!"
```

---

## 新 Skill 开发流程

1. 在 `selfskills/` 下创建目录：`<name>skill/`
2. 根据平台特性选择类型 A 或 B
3. 创建 `CLAUDE.md`（架构文档）
4. 创建根 `SKILL.md`（OpenClaw 定义）
5. 实现客户端代码（Python CLI 或 Go MCP Server）
6. 创建 `scripts/setup.sh`
7. 按功能类别拆分子 skill 到 `skills/` 目录
8. 手动测试所有命令
9. 安装到 `~/.openclaw/skills/<name>/`（符号链接或复制）

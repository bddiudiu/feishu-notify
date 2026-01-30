#!/bin/bash
# 飞书 Webhook 推送脚本 - 软件开发增强版
# 支持从 stdin 读取 hook 事件的 JSON 数据，提取详细信息

WEBHOOK_URL="WEBHOOK_URL"

# 参数
EVENT_TYPE="${1:-通知}"      # 事件类型
COLOR="${2:-blue}"           # 卡片颜色

# 获取系统信息
HOSTNAME=$(hostname 2>/dev/null || echo "未知")
USER_NAME=$(whoami 2>/dev/null || echo "未知")
CURRENT_DIR=$(pwd 2>/dev/null || echo "未知")
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# 从 stdin 读取 JSON（如果有的话）
STDIN_DATA=""
if [ ! -t 0 ]; then
    STDIN_DATA=$(cat)
fi

# 调试日志
echo "[$(date '+%Y-%m-%d %H:%M:%S')] EVENT: $EVENT_TYPE" >> /tmp/feishu-hook.log
echo "STDIN: $STDIN_DATA" >> /tmp/feishu-hook.log
echo "---" >> /tmp/feishu-hook.log

# 解析 stdin JSON 数据
TOOL_NAME=""
TOOL_INPUT=""
TOOL_RESULT=""
USER_PROMPT=""
SESSION_ID=""
CWD=""
STOP_REASON=""

if [ -n "$STDIN_DATA" ] && command -v jq &> /dev/null; then
    TOOL_NAME=$(echo "$STDIN_DATA" | jq -r '.tool_name // empty' 2>/dev/null)
    TOOL_INPUT=$(echo "$STDIN_DATA" | jq -r 'if .tool_input then (.tool_input | tostring) else empty end' 2>/dev/null | head -c 500)
    TOOL_RESULT=$(echo "$STDIN_DATA" | jq -r 'if .tool_result then (.tool_result | tostring) else empty end' 2>/dev/null | head -c 300)
    USER_PROMPT=$(echo "$STDIN_DATA" | jq -r '.prompt // .user_prompt // .message // .content // empty' 2>/dev/null | head -c 500)
    SESSION_ID=$(echo "$STDIN_DATA" | jq -r '.session_id // .sessionId // empty' 2>/dev/null)
    CWD=$(echo "$STDIN_DATA" | jq -r '.cwd // .workingDirectory // empty' 2>/dev/null)
    STOP_REASON=$(echo "$STDIN_DATA" | jq -r '.reason // .stop_reason // empty' 2>/dev/null)

    [ -n "$CWD" ] && CURRENT_DIR="$CWD"
fi

# 转义 JSON 特殊字符
escape_json() {
    local text="$1"
    # 使用 python3 进行可靠的 JSON 转义
    if command -v python3 &> /dev/null; then
        printf '%s' "$text" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read())[1:-1])'
    else
        printf '%s' "$text" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g' | tr '\n' ' '
    fi
}

# ========== 获取开发环境信息 ==========

# 获取 Git 信息
get_git_info() {
    local dir="${1:-$CURRENT_DIR}"
    if [ -d "$dir/.git" ] || git -C "$dir" rev-parse --git-dir &>/dev/null 2>&1; then
        local branch=$(git -C "$dir" branch --show-current 2>/dev/null)
        local uncommitted=$(git -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
        local repo_name=$(basename "$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)")

        echo "BRANCH:$branch"
        echo "UNCOMMITTED:$uncommitted"
        echo "REPO:$repo_name"
    fi
}

# 获取项目类型
get_project_type() {
    local dir="${1:-$CURRENT_DIR}"
    local types=""
    [ -f "$dir/package.json" ] && types="${types}Node.js "
    [ -f "$dir/pom.xml" ] && types="${types}Maven "
    [ -f "$dir/build.gradle" ] || [ -f "$dir/build.gradle.kts" ] && types="${types}Gradle "
    [ -f "$dir/Cargo.toml" ] && types="${types}Rust "
    [ -f "$dir/go.mod" ] && types="${types}Go "
    [ -f "$dir/requirements.txt" ] || [ -f "$dir/pyproject.toml" ] && types="${types}Python "
    [ -f "$dir/Podfile" ] && types="${types}iOS "
    [ -f "$dir/docker-compose.yml" ] || [ -f "$dir/Dockerfile" ] && types="${types}Docker "
    echo "${types:-未知}"
}

# 解析 Git 信息
GIT_INFO=$(get_git_info "$CURRENT_DIR")
GIT_BRANCH=$(echo "$GIT_INFO" | grep "^BRANCH:" | cut -d: -f2-)
GIT_UNCOMMITTED=$(echo "$GIT_INFO" | grep "^UNCOMMITTED:" | cut -d: -f2-)
GIT_REPO=$(echo "$GIT_INFO" | grep "^REPO:" | cut -d: -f2-)
PROJECT_TYPE=$(get_project_type "$CURRENT_DIR")

# ========== 识别任务类型 ==========

detect_task_type() {
    local prompt="$1"

    if echo "$prompt" | grep -qiE '(build|compile|编译|构建|打包)'; then
        echo "🔨 编译构建"
    elif echo "$prompt" | grep -qiE '(test|测试|单元测试|集成测试|e2e)'; then
        echo "🧪 测试任务"
    elif echo "$prompt" | grep -qiE '(deploy|部署|发布|上线|release)'; then
        echo "🚀 部署发布"
    elif echo "$prompt" | grep -qiE '(fix|bug|修复|问题|error|错误)'; then
        echo "🐛 Bug修复"
    elif echo "$prompt" | grep -qiE '(refactor|重构|优化|改进)'; then
        echo "♻️ 代码重构"
    elif echo "$prompt" | grep -qiE '(add|新增|添加|实现|feature|功能)'; then
        echo "✨ 新功能"
    elif echo "$prompt" | grep -qiE '(doc|文档|readme|注释)'; then
        echo "📝 文档更新"
    elif echo "$prompt" | grep -qiE '(review|审查|检查|分析)'; then
        echo "🔍 代码审查"
    elif echo "$prompt" | grep -qiE '(install|安装|依赖|dependency|npm|yarn|pip)'; then
        echo "📦 依赖管理"
    elif echo "$prompt" | grep -qiE '(config|配置|设置|env|环境)'; then
        echo "⚙️ 配置修改"
    else
        echo "💻 开发任务"
    fi
}

# ========== 构建消息内容 ==========

build_content() {
    local content=""

    # Git 上下文
    local git_info=""
    if [ -n "$GIT_BRANCH" ]; then
        git_info="\\n\\n---\\n📂 **$GIT_REPO** · 🌿 \`$GIT_BRANCH\`"
        [ -n "$GIT_UNCOMMITTED" ] && [ "$GIT_UNCOMMITTED" != "0" ] && git_info="$git_info · 📝 $GIT_UNCOMMITTED 个待提交"
    fi

    case "$EVENT_TYPE" in
        "🚀 会话开始")
            content="**Claude Code 开发会话已启动**"
            [ -n "$SESSION_ID" ] && content="$content\\n\\n🔑 会话: \`${SESSION_ID:0:8}...\`"
            content="$content\\n🛠️ 项目类型: $PROJECT_TYPE"
            content="$content$git_info"
            ;;

        "📝 收到任务")
            # 任务详情优先显示
            if [ -n "$USER_PROMPT" ]; then
                local escaped_prompt=$(escape_json "$USER_PROMPT")
                local task_type=$(detect_task_type "$USER_PROMPT")
                content="**$task_type**\\n\\n"
                content="$content**📋 任务内容:**\\n\`\`\`\\n$escaped_prompt\\n\`\`\`"
            else
                content="**💻 收到新的开发任务**\\n\\n_(任务内容未获取到)_"
            fi
            content="$content\\n\\n🛠️ 项目: $PROJECT_TYPE"
            content="$content$git_info"
            ;;

        "🔧 执行工具")
            local tool_desc="执行操作"
            case "$TOOL_NAME" in
                "Bash") tool_desc="执行命令" ;;
                "Write") tool_desc="写入文件" ;;
                "Edit") tool_desc="编辑文件" ;;
                "Read") tool_desc="读取文件" ;;
                "Glob") tool_desc="搜索文件" ;;
                "Grep") tool_desc="搜索代码" ;;
                "Task") tool_desc="启动子任务" ;;
            esac
            content="**正在$tool_desc**"
            [ -n "$TOOL_NAME" ] && content="$content\\n\\n🔧 工具: \`$TOOL_NAME\`"
            if [ -n "$TOOL_INPUT" ]; then
                local escaped_input=$(escape_json "${TOOL_INPUT:0:300}")
                content="$content\\n📥 输入:\\n\`\`\`\\n$escaped_input\\n\`\`\`"
            fi
            ;;

        "📊 阶段完成")
            local tool_desc="操作完成"
            case "$TOOL_NAME" in
                "Bash") tool_desc="命令执行完成" ;;
                "Write") tool_desc="文件写入完成" ;;
                "Edit") tool_desc="文件修改完成" ;;
                "Task") tool_desc="子任务完成" ;;
            esac
            content="**$tool_desc**"
            [ -n "$TOOL_NAME" ] && content="$content\\n\\n🔧 工具: \`$TOOL_NAME\`"
            if [ -n "$TOOL_RESULT" ]; then
                local escaped_result=$(escape_json "${TOOL_RESULT:0:200}")
                content="$content\\n📤 结果:\\n\`\`\`\\n$escaped_result\\n\`\`\`"
            fi
            ;;

        "🔐 需要授权")
            content="**⚠️ 需要您的授权才能继续**"
            [ -n "$TOOL_NAME" ] && content="$content\\n\\n🔧 待授权工具: \`$TOOL_NAME\`"
            if [ -n "$TOOL_INPUT" ]; then
                local escaped_input=$(escape_json "${TOOL_INPUT:0:300}")
                content="$content\\n📋 操作内容:\\n\`\`\`\\n$escaped_input\\n\`\`\`"
            fi
            content="$content\\n\\n🚨 **请立即查看终端进行授权**"
            ;;

        "⏳ 等待输入")
            content="**Claude Code 正在等待您的输入**\\n\\n⏰ 已等待超过 60 秒"
            content="$content$git_info"
            content="$content\\n\\n🚨 **请查看终端并提供输入**"
            ;;

        "✅ 任务完成")
            content="**开发任务已完成**"
            if [ -n "$STOP_REASON" ]; then
                local escaped_reason=$(escape_json "$STOP_REASON")
                content="$content\\n\\n📋 完成说明:\\n$escaped_reason"
            fi
            if [ -n "$GIT_UNCOMMITTED" ] && [ "$GIT_UNCOMMITTED" != "0" ]; then
                content="$content\\n\\n📊 变更统计: $GIT_UNCOMMITTED 个文件待提交"
            fi
            content="$content$git_info"
            ;;

        "📦 子任务完成")
            content="**子任务执行完成**"
            if [ -n "$STOP_REASON" ]; then
                local escaped_reason=$(escape_json "$STOP_REASON")
                content="$content\\n\\n📋 说明: $escaped_reason"
            fi
            ;;

        "👋 会话结束")
            content="**Claude Code 开发会话已结束**"
            [ -n "$SESSION_ID" ] && content="$content\\n\\n🔑 会话: \`${SESSION_ID:0:8}...\`"
            if [ -n "$GIT_UNCOMMITTED" ] && [ "$GIT_UNCOMMITTED" != "0" ]; then
                content="$content\\n\\n⚠️ 注意: 还有 $GIT_UNCOMMITTED 个文件未提交"
            fi
            content="$content$git_info"
            ;;

        *)
            content="状态更新"
            ;;
    esac

    printf '%s' "$content"
}

CONTENT=$(build_content)

# 目录名和项目名
DIR_NAME="${CURRENT_DIR##*/}"
[ -z "$DIR_NAME" ] && DIR_NAME="$CURRENT_DIR"
DISPLAY_NAME="${GIT_REPO:-$DIR_NAME}"

# 构建底部字段
if [ -n "$GIT_BRANCH" ]; then
    FOOTER_FIELDS="{\"is_short\": true, \"text\": {\"tag\": \"lark_md\", \"content\": \"**主机**\\n$HOSTNAME\"}},
          {\"is_short\": true, \"text\": {\"tag\": \"lark_md\", \"content\": \"**分支**\\n$GIT_BRANCH\"}},
          {\"is_short\": true, \"text\": {\"tag\": \"lark_md\", \"content\": \"**项目**\\n$DISPLAY_NAME\"}}"
else
    FOOTER_FIELDS="{\"is_short\": true, \"text\": {\"tag\": \"lark_md\", \"content\": \"**主机**\\n$HOSTNAME\"}},
          {\"is_short\": true, \"text\": {\"tag\": \"lark_md\", \"content\": \"**用户**\\n$USER_NAME\"}},
          {\"is_short\": true, \"text\": {\"tag\": \"lark_md\", \"content\": \"**目录**\\n$DIR_NAME\"}}"
fi

# 发送飞书消息
curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{
    \"msg_type\": \"interactive\",
    \"card\": {
      \"header\": {
        \"title\": {\"tag\": \"plain_text\", \"content\": \"$EVENT_TYPE\"},
        \"template\": \"$COLOR\"
      },
      \"elements\": [
        {\"tag\": \"div\", \"text\": {\"tag\": \"lark_md\", \"content\": \"$CONTENT\"}},
        {\"tag\": \"hr\"},
        {\"tag\": \"div\", \"fields\": [
          $FOOTER_FIELDS
        ]},
        {\"tag\": \"note\", \"elements\": [{\"tag\": \"plain_text\", \"content\": \"Claude Code · $TIMESTAMP\"}]}
      ]
    }
  }" > /dev/null 2>&1

exit 0

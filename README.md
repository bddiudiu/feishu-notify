# 🔔 飞书通知 Skill for Claude Code

<div align="center">

**让 Claude Code 的开发进度实时推送到飞书**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude-Code-blue.svg)](https://github.com/anthropics/claude-code)

</div>

---

## 📖 简介

这是一个 Claude Code 的 Skill 插件，通过飞书机器人 Webhook 实时推送开发进度通知。当 Claude Code 完成任务、需要授权或等待输入时，自动发送精美的卡片消息到飞书群聊或私聊。

### ✨ 特性

- 🎯 **智能识别任务类型** - 自动识别编译、测试、部署、Bug修复等10+种任务类型
- 📊 **丰富的上下文信息** - 包含 Git 分支、项目类型、未提交文件数等开发环境信息
- 🎨 **精美的卡片消息** - 支持 Markdown 格式，多种颜色主题
- 🔔 **关键节点通知** - 任务完成、需要授权、等待输入时自动推送
- 🛠️ **开箱即用** - 简单配置即可使用
- 🐛 **调试日志** - 自动记录事件日志到 `/tmp/feishu-hook.log`，便于问题排查
- 🔄 **增强兼容性** - 支持多种 JSON 字段名变体，适配不同版本的 Claude Code

---

## 🚀 快速开始

### 第一步：获取飞书机器人 Webhook URL

#### 1. 创建飞书群聊机器人

1. 打开飞书，进入需要接收通知的**群聊**
2. 点击群聊右上角的 **设置** 图标
3. 选择 **群机器人** → **添加机器人**
4. 选择 **自定义机器人**（或 **Webhook**）
5. 设置机器人名称，例如：`Claude Code 通知`
6. 设置机器人头像（可选）
7. 点击 **添加**

#### 2. 获取 Webhook URL

添加成功后，会显示一个 Webhook 地址，格式如下：

```
https://open.feishu.cn/open-apis/bot/v2/hook/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

**⚠️ 重要：请妥善保管此 URL，不要泄露给他人！**

#### 3. 测试 Webhook（可选）

在终端执行以下命令测试 Webhook 是否正常：

```bash
curl -X POST "你的Webhook URL" \
  -H "Content-Type: application/json" \
  -d '{"msg_type":"text","content":{"text":"测试消息"}}'
```

如果群聊收到消息，说明配置成功！

---

### 第二步：安装 Skill

将此 Skill 安装到 Claude Code 的 skills 目录：

```bash
# 克隆仓库
git clone https://github.com/your-username/feishu-notify.git

# 复制到 Claude Code skills 目录
cp -r feishu-notify/feishu-notify ~/.claude/skills/
```

或者手动下载后解压到 `~/.claude/skills/feishu-notify/` 目录。

---

### 第三步：配置 Webhook URL

编辑通知脚本，填入你的 Webhook URL：

```bash
# 使用你喜欢的编辑器打开
nano ~/.claude/skills/feishu-notify/scripts/notify.sh

# 或者使用 vim
vim ~/.claude/skills/feishu-notify/scripts/notify.sh
```

找到第 5 行，将 `WEBHOOK_URL` 替换为你的实际 Webhook URL：

```bash
# 修改前
WEBHOOK_URL="WEBHOOK_URL"

# 修改后（示例）
WEBHOOK_URL="https://open.feishu.cn/open-apis/bot/v2/hook/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

保存并退出编辑器。

**⚠️ 安全提示：** 请勿将包含真实 Webhook URL 的脚本提交到公开仓库！

---

### 第四步：配置 Claude Code Hooks（可选）

如果你想让 Claude Code 在特定事件时自动发送通知，需要配置 hooks。

编辑 Claude Code 配置文件：

```bash
nano ~/.claude/settings.json
```

添加以下 hooks 配置：

```json
{
  "hooks": {
    "user-prompt-submit": "~/.claude/skills/feishu-notify/scripts/notify.sh '📝 收到任务' 'blue'",
    "tool-call-request": "~/.claude/skills/feishu-notify/scripts/notify.sh '🔧 执行工具' 'wathet'",
    "tool-call-result": "~/.claude/skills/feishu-notify/scripts/notify.sh '📊 阶段完成' 'green'",
    "permission-request": "~/.claude/skills/feishu-notify/scripts/notify.sh '🔐 需要授权' 'orange'",
    "session-start": "~/.claude/skills/feishu-notify/scripts/notify.sh '🚀 会话开始' 'blue'",
    "session-end": "~/.claude/skills/feishu-notify/scripts/notify.sh '👋 会话结束' 'grey'",
    "stop": "~/.claude/skills/feishu-notify/scripts/notify.sh '✅ 任务完成' 'green'"
  }
}
```

**注意：** 如果你的 `settings.json` 已有其他配置，请将 `hooks` 部分合并进去，不要覆盖整个文件。

---

## 📱 使用方法

### 自动通知

配置完成后，Claude Code 会在以下场景自动发送通知：

| 场景 | 说明 | 卡片颜色 |
|------|------|----------|
| 🚀 会话开始 | Claude Code 启动时 | 蓝色 |
| 📝 收到任务 | 用户提交新任务时 | 蓝色 |
| 🔧 执行工具 | Claude 调用工具时 | 浅蓝色 |
| 📊 阶段完成 | 工具执行完成时 | 绿色 |
| 🔐 需要授权 | 需要用户授权操作时 | 橙色 |
| ⏳ 等待输入 | 等待用户输入超过60秒 | 黄色 |
| ✅ 任务完成 | 任务执行完成时 | 绿色 |
| 👋 会话结束 | Claude Code 退出时 | 灰色 |

### 手动调用

你也可以在脚本或命令行中手动调用：

```bash
# 基本用法
~/.claude/skills/feishu-notify/scripts/notify.sh "事件类型" "颜色" "自定义内容"

# 示例：发送编译开始通知
~/.claude/skills/feishu-notify/scripts/notify.sh "🔨 编译构建" "blue" "正在编译项目..."

# 示例：发送测试完成通知
~/.claude/skills/feishu-notify/scripts/notify.sh "✅ 测试通过" "green" "所有单元测试已通过"

# 示例：发送错误通知
~/.claude/skills/feishu-notify/scripts/notify.sh "❌ 构建失败" "red" "编译过程中发现错误"
```

### 在 Claude Code 中使用 Skill

在 Claude Code 对话中，可以直接调用此 Skill：

```
/feishu-notify
```

---

## 🎨 消息样式

### 支持的任务类型

脚本会自动识别以下任务类型并显示对应图标：

| 任务类型 | 关键词 | 图标 |
|---------|--------|------|
| 编译构建 | build, compile, 编译, 构建, 打包 | 🔨 |
| 测试任务 | test, 测试, 单元测试, 集成测试, e2e | 🧪 |
| 部署发布 | deploy, 部署, 发布, 上线, release | 🚀 |
| Bug修复 | fix, bug, 修复, 问题, error, 错误 | 🐛 |
| 代码重构 | refactor, 重构, 优化, 改进 | ♻️ |
| 新功能 | add, 新增, 添加, 实现, feature, 功能 | ✨ |
| 文档更新 | doc, 文档, readme, 注释 | 📝 |
| 代码审查 | review, 审查, 检查, 分析 | 🔍 |
| 依赖管理 | install, 安装, 依赖, dependency, npm, yarn, pip | 📦 |
| 配置修改 | config, 配置, 设置, env, 环境 | ⚙️ |

### 支持的卡片颜色

| 颜色名称 | 适用场景 |
|---------|---------|
| `blue` | 常规信息、开始事件 |
| `wathet` | 进行中的操作 |
| `turquoise` | 数据相关操作 |
| `green` | 成功、完成 |
| `yellow` | 警告、等待 |
| `orange` | 需要注意、授权请求 |
| `red` | 错误、失败 |
| `carmine` | 严重错误 |
| `violet` | 特殊事件 |
| `purple` | 高优先级 |
| `indigo` | 系统事件 |
| `grey` | 结束、归档 |

### 消息内容

每条通知卡片包含以下信息：

**主要内容**
- **事件类型** - 标题显示当前事件
- **任务详情** - 具体的任务描述或操作内容
- **工具信息** - 使用的 Claude Code 工具名称
- **执行结果** - 工具执行的输出结果

**上下文信息**
- **📂 项目名称** - Git 仓库名称
- **🌿 Git 分支** - 当前工作分支
- **📝 未提交文件** - 待提交的文件数量
- **🛠️ 项目类型** - 自动识别（Node.js, Python, Go 等）
- **💻 主机名称** - 执行任务的机器
- **⏰ 时间戳** - 事件发生时间

---

## 🔧 高级配置

### 自定义通知频率

如果觉得通知太频繁，可以只保留关键事件：

```json
{
  "hooks": {
    "permission-request": "~/.claude/skills/feishu-notify/scripts/notify.sh '🔐 需要授权' 'orange'",
    "stop": "~/.claude/skills/feishu-notify/scripts/notify.sh '✅ 任务完成' 'green'"
  }
}
```

### 修改消息格式

编辑 `scripts/notify.sh` 文件，找到 `build_content()` 函数，可以自定义消息内容和格式。

### 支持多个 Webhook

如果需要发送到多个群聊，可以修改脚本支持多个 URL：

```bash
WEBHOOK_URLS=(
  "https://open.feishu.cn/open-apis/bot/v2/hook/xxxxxxxx-1"
  "https://open.feishu.cn/open-apis/bot/v2/hook/xxxxxxxx-2"
)

for url in "${WEBHOOK_URLS[@]}"; do
  curl -s -X POST "$url" -H "Content-Type: application/json" -d "..."
done
```

---

## 🐛 故障排查

### 1. 没有收到通知

**检查 Webhook URL 是否正确：**
```bash
# 查看配置的 URL
grep WEBHOOK_URL ~/.claude/skills/feishu-notify/scripts/notify.sh
```

**手动测试脚本：**
```bash
~/.claude/skills/feishu-notify/scripts/notify.sh "测试" "blue" "这是一条测试消息"
```

### 2. 提示权限错误

**确保脚本有执行权限：**
```bash
chmod +x ~/.claude/skills/feishu-notify/scripts/notify.sh
```

### 3. 消息格式错误

**检查是否安装了 jq（用于解析 JSON）：**
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# CentOS/RHEL
sudo yum install jq
```

### 4. Hooks 不生效

**验证 settings.json 格式：**
```bash
# 使用 jq 验证 JSON 格式
cat ~/.claude/settings.json | jq .
```

**重启 Claude Code：**
```bash
# 退出当前会话，重新启动 Claude Code
```

### 5. 查看调试日志

**脚本会自动记录事件到日志文件：**
```bash
# 查看最近的通知日志
tail -f /tmp/feishu-hook.log

# 查看完整日志
cat /tmp/feishu-hook.log
```

日志包含事件类型、接收到的 JSON 数据等信息，便于排查问题。

---

## 📚 参考资料

- [飞书开放平台 - 自定义机器人](https://open.feishu.cn/document/ukTMukTMukTM/ucTM5YjL3ETO24yNxkjN)
- [Claude Code 官方文档](https://github.com/anthropics/claude-code)
- [飞书消息卡片搭建工具](https://open.feishu.cn/tool/cardbuilder)

---

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

### 开发建议

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

---

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

---

## 💡 灵感来源

这个 Skill 的灵感来自于在使用 Claude Code 进行长时间开发任务时，需要实时了解任务进度的需求。通过飞书通知，可以在做其他事情时及时收到关键节点的提醒。

---

## 📮 联系方式

如有问题或建议，欢迎通过以下方式联系：

- 提交 [GitHub Issue](https://github.com/your-username/feishu-notify/issues)
- 发送邮件至：your-email@example.com

---

<div align="center">

**⭐ 如果这个项目对你有帮助，请给个 Star！**

Made with ❤️ for Claude Code users

</div>

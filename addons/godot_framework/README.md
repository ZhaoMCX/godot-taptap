# Godot Framework 0.1.0

将本目录放到项目的 `addons/godot_framework` 后即可使用。该 addon 是纯运行时脚本库，不需要在
Project Settings 中启用。

推荐项目使用 `game/applications`、`features`、`modules`、`tools`、`arts` 和 `docs`。一次运行只有
一个 Application 且只承担显式组合；Feature 是完整用户功能，Module 是内聚领域能力，`game/arts`
只保存纯美术。`game/tools` 是 GF Tool 职责，仓库自动化脚本应放在项目根 `tools`。详细判定见使用和
架构文档。

- 使用说明：`docs/usage.md`
- 架构规则：`docs/architecture.md`
- 功能插件开发：`docs/plugin_development.md`
- Agent 规则：`AGENTS.md`

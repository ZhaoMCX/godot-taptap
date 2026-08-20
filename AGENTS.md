# Agent 工作规则

本文件定义整个仓库共同遵守的规则。具体目录可以通过更近的 `AGENTS.md` 补充或收紧规则。

## 规则与结构

- 修改前从仓库根目录开始读取目标路径规则链上的全部 `AGENTS.md`。
- GF 项目统一使用复数职责目录：`applications`、`features`、`modules`、`tools`、`arts`、`docs`。
- 插件内部统一使用 `applications`、`features`、`modules`、`tools`；类型名称仍使用单数
  `Application`、`Feature`、`Module`、`Tool`。
- 框架插件自身的 `base` 与 `rules` 目录保持不变。

一级规则入口：

- TapTap 插件：`addons/godot_taptap/AGENTS.md`
- TapTap 测试游戏：`game/AGENTS.md`

## 通用约束

- 遵循 KISS、显式依赖、职责隔离和可测试性；不得顺带修改无关职责。
- 文件和资源路径使用小写 ASCII `snake_case`，场景节点名使用 `PascalCase`。
- 测试放在所属职责的 `tests` 子目录，功能修改必须运行实际影响范围内的测试。
- 文档和 Git 提交说明以中文为主体；提交使用 `type(scope): 中文摘要`。
- 不提交 `.godot`、`android`、`reports`、真实 `override.cfg` 或构建产物。
- Godot 操作依次选择 Godot AI MCP、Godot CLI、直接读写文件；普通 `.tscn` 修改后必须通过
  Godot AI MCP 重新打开并显式保存。

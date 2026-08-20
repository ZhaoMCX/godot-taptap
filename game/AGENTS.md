# Godot TapTap Test Agent 规则

本目录是 Godot TapTap 插件的独立消费测试游戏。

- 主入口固定为 `applications/godot_taptap_test_application.tscn`。
- 游戏按 `applications`、`features`、`modules`、`tools`、`arts`、`docs` 组织。
- `applications/tests/device` 只保存依赖 Android 真机和真实账号的端到端测试入口。
- `tools/build_android.ps1` 属于本消费游戏，不进入插件运行时。
- 游戏仅通过插件公开 Application、Feature、Module、Tool 契约接入，不访问插件内部实现。
- Sample Save 的格式、槽位和本地适配属于本游戏，不得进入 TapTap 插件。
- 修改组合场景时，至少运行 `game` 与 `addons/godot_taptap` 测试，并通过 Godot AI MCP 启动
  主场景检查日志。
- Android 构建使用本机忽略的 `override.cfg`；不得提交凭据、APK、`android` 或生成内容。

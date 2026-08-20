# Godot TapTap

基于 Godot Framework 的 TapSDK Android 源码仓库，包含插件与独立消费测试游戏。

本仓当前只维护源码，不发布 Release。开发时将 Godot Framework `v0.1.0` 的
`addons/godot_framework` 放在同一路径，随后运行本仓测试与 Android 验证。框架更新通过本地替换
插件目录及时反馈兼容性，不设置跨仓库 CI 或依赖锁。

目录采用 GF 复数标准：插件和游戏均使用 `applications`、`features`、`modules`、`tools`；
游戏还可按需使用 `arts` 与 `docs`。
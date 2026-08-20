# Godot TapTap Test

这是 TapTap 插件的消费测试游戏。目录遵循 GF 复数标准：

- `applications`：游戏组合根和真机入口。
- `features`：跨 Module 的用例协调。
- `modules`：拥有内聚游戏状态与行为。
- `tools`：构建等开发期辅助能力。
- `arts`：可选的项目视觉资源。
- `docs`：产品和项目资料。

跨项目美术包可按原路径复制到 `game/arts/core` 与 `game/arts/packs/<pack>`。游戏运行时代码不能
依赖其他仓库路径。

# Godot Framework Agent 规则

本文件规定框架核心插件子树的开发约束。公开使用方式见 `docs/usage.md`，完整架构见
`docs/architecture.md`，功能插件开发见 `docs/plugin_development.md`。

- KISS、Agent 友好、显式组合、模块隔离、CQRS 和可测试性是不可用局部便利换取的核心原则。
- 只为当前明确需求增加抽象；优先 Godot 原生、依赖显式、命名可搜索且可隔离验证的实现。
- 低魔法优先于少写代码，修改一个职责不应要求理解无关模块。
- 本插件的运行时脚本只能位于 `base` 或 `rules`；`tests` 是插件开发内容，不属于运行时发布包。
- `base` 定义架构基础类型，不包含具体游戏层实现。
- CQRS 等跨层契约放在 `rules`，不得放入 Tool。
- 不向核心插件加入具体游戏 Feature、Module、Tool 或业务逻辑。
- 基于 GF 的可复用功能插件可以提供自己的 `Application`、`Feature`、`Module` 和 `Tool`；插件目录只是物理分布，不是额外架构层。完整规则见 `docs/plugin_development.md`。
- Application 场景必须声明并拥有需要长期存在的 Module、Feature 或 Feature UI Node，通过类型化导出变量显式注入；不得用 `get_node`、`get_node_or_null`、`add_child` 或 `PackedScene.instantiate()` 重新解析这些已声明依赖。
- Tool、值对象和无场景所有权的配置辅助对象可以由代码创建；平台实现、适配器、原生 SDK、AAR、EditorExportPlugin 和桌面模拟器按职责归入 Tool，不建立顶层 `runtime`、`adapter` 或 `android_plugin`。
- Feature 的场景和资源归属 Feature，由 Application 场景挂载；Feature UI 只调用 Feature 公开 API，不直接访问 Module 内部或平台桥接。
- `GFApplication` 默认在 `_enter_tree()` 组合；导出 Node 引用需进入场景树后才能解析时，具体 Application 可以在 `_ready()` 组合，但必须先验证依赖完整性。
- 不引用其他职责单元的 `internal` 目录。
- 保持显式组合，不添加 autoload、服务定位器、全局消息总线或反射扫描。
- 每个独立职责类以及每个 Command、Event、Snapshot、API、Adapter、Validator 和测试替身单文件存放。
- Command 通过强类型 API 表达变更意图；Query 返回隔离快照；Signal 只传递 Event。
- 可联网消息只能包含数据值和稳定 ID，不得包含 Object、Node 或 NodePath 身份。
- 重试必须保留 `command_id`，派生 Event 使用 `causation_id` 建立关联。
- 每个已接受 Command 最终只产生一个完成事件，领域事件先于完成事件。
- 框架实际执行的公开行为、分支、不变量和 Bug 回归必须更新所属职责 `tests` 子目录下的
  GDUnit4 测试；Fixture 只属于该职责。
- 功能修改必须运行修改职责及其实际直接、间接消费者的测试。公开契约变化沿显式依赖向使用方传播；
  内部实现变化且公开行为不变时只验证所属职责，多处修改取影响范围并集。
- `base` 或 `rules` 的变化覆盖实际使用它们的框架与游戏职责；边界无法证明时扩大测试范围。
- 普通 getter、Marker 类型、静态文件规范和框架尚未执行的设计规定不写行为测试；后两者由
  本规则和架构文档表达。
- 运行时代码不得依赖 GDUnit4、Godot AI 或具体游戏代码。
- 插件文档以中文为主体；提交说明遵循 `type(scope): 中文摘要`。
- 涉及 Godot 编辑器、场景、资源、运行结果或截图时，优先使用 Godot AI MCP。

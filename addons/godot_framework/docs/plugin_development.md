# GF 功能插件开发规范

本文档规定基于 Godot Framework（GF）构建可复用功能插件时的目录、依赖、组合、测试和发布边界。
它把具体插件验证过的实践提炼为与业务无关的规则；核心插件只提供 `base` 和 `rules`，不把某个
功能插件的业务实现加入自身。

## 规范目标

- 使用显式的四层职责组织运行时代码：`Application -> Feature -> Module -> Tool`。
- 让依赖、场景组合、生命周期和通信契约可以沿文件路径定位和隔离验证。
- 优先 Godot 原生能力和简单组合，不以全局状态或隐式扫描隐藏依赖。
- 让功能插件可以独立运行，也可以被 GF 项目的 Application 显式组合。

## 插件与四层

四层是运行时代码的职责模型，不是核心插件或功能插件必须额外创建的物理目录。项目目录和插件
目录只是代码的物理分布；它们共同构成同一套运行时架构。

```text
Application -> Feature -> Module -> Tool
```

- **Application** 是组合根。它决定具体实现、拥有场景中的 Node、注入公开依赖并协调生命周期。
- **Feature** 编排两个或更多 Module 的用例，管理跨 Module 的信号和状态转换，不依赖其他 Feature。
- **Module** 拥有单一内聚能力和权威状态，只依赖 Tool 与框架规则，不依赖其他 Module 或 Feature。
- **Tool** 提供无领域状态的适配、平台实现、序列化、配置辅助或测试替身，不依赖更高层。

核心 `godot_framework` 插件自身只保留：

```text
base/       GFApplication、GFFeature、GFModule 等基础类型
rules/      所有层共享的契约，目前包含 rules/cqrs
```

可复用功能插件可以拥有自己的 `applications/`、`features/`、`modules/` 和 `tools/`。不得因为平台、
适配器、模拟器或运行时实现而新增顶层 `runtime/`、`adapter/`、`android_plugin/` 等架构层；这些
实现必须按实际职责放进对应的 Module 或 Tool。

## Application 组合与场景所有权

### Node 依赖由场景声明

Application 场景是 Application 所有 Node 的组合根。Module、Feature 和 Feature UI 等需要长期存在的
Node 应作为场景子节点或 PackedScene 实例声明，并通过类型化导出变量表达依赖：

```gdscript
@export var account_module: AccountModule
@export var account_feature: AccountFeature
@export var account_panel: AccountPanel
```

场景中的 `node_paths` 和 NodePath 只负责 Godot 的资源序列化，Application 代码通过已经解析的类型化
引用进行组合。对于这些已声明依赖，Application 不应在运行时使用 `get_node`、`get_node_or_null`、
`add_child` 或 `PackedScene.instantiate()` 重新查找或创建节点；缺少依赖时应明确报错并停止组合。

Tool 对象、值对象和无场景所有权的配置辅助对象可以由代码创建，例如 `RefCounted`、`Resource` 或
无领域状态的适配器。代码创建这些对象不改变 Node 的场景所有权规则。

### 组合时机与验证

`GFApplication` 默认在 `_enter_tree()` 调用 `compose()`，以便早于子节点的 `_ready()` 完成注入。
如果具体 Application 依赖的导出 Node 引用只有在进入场景树后才可用，可以显式覆盖生命周期，在
`_ready()` 调用 `compose()`；此时必须保持同样的显式依赖和完整性验证，不能用隐式查找替代。

组合过程应当：

1. 验证所有类型化场景依赖不为空且类型正确。
2. 创建必要的 Tool/值对象，并把它们注入 Module 或 Feature 的公开配置入口。
3. 按 `Application -> Feature -> Module -> Tool` 方向完成连接。
4. 让 Feature 连接自己拥有的信号，并在离开场景树时断开这些连接。

不得使用业务 Autoload、服务定位器、全局消息总线、反射扫描或共享可变单例来绕过组合根。

### Feature UI

Feature 的场景和资源放在该 Feature 的 `scenes/`、`assets/` 等目录中。UI 归属 Feature 的职责，
但由 Application 场景声明、挂载和注入；UI 只调用 Feature 的公开 API，不直接访问 Module 内部状态、
平台桥接或第三方 SDK。

## Module、Feature 与 Tool 边界

- Module 之间禁止直接引用或相互调用。跨 Module 行为由 Feature 协调。
- Feature 只能使用 Module 的公开 API，以及必要的 Tool 契约；不能读取 Module 的 `internal`。
- Module 只能依赖 Tool 和 GF 规则；Tool 不得反向依赖 Module、Feature 或 Application。
- 平台原生代码、AAR/SDK 二进制、EditorExportPlugin、回调适配器、序列化和桌面模拟桥接都属于
  Tool 实现细节，除非它们拥有明确的领域权威状态。
- 模拟器只模拟平台边界，不承担业务状态；业务分支仍由 Module 或 Feature 负责。

## 契约与敏感数据

- Command 表达不可变的变更意图，通过强类型 API 提交。
- Query 是同步只读读取，返回与内部状态隔离的 Snapshot。
- Event 表达已经发生的事实，通过专用强类型 Signal 传递。
- Command 提交只返回 `GFSubmitResult`，不把本地接受等同于权威执行成功。
- 每个被接受的 Command 最终只产生一个 `GFCommandCompletedEvent`；领域 Event 先于完成事件。
- 重试保留 `command_id`，派生 Event 使用 `causation_id` 建立关联。
- 可联网数据只能包含数据值和稳定 ID，不得包含 `Object`、`Node`、`Callable`、`RID` 或 `NodePath`。
- Access Token、Client Token、Mac Key 等凭据必须停留在 Tool 边界，不得进入日志、Event、Snapshot
  或公开状态。

## 文件、命名与测试

- 每个具有独立职责的类单独存放在一个文件中；`PascalCase` 类名对应 `snake_case.gd` 文件名。
- Command、Event、Snapshot、API、Adapter、Validator 和测试替身各自单文件存放，不创建
  `messages.gd`、`models.gd`、`utils.gd` 等聚合文件。
- 资源目录和文件名使用小写 ASCII `snake_case`；场景节点名使用 `PascalCase`。
- Feature 和 Module 的场景、预制体和资源放在所属职责目录；共享资源放在最近共同父目录的 `shared`，
  且不得反向依赖具体实体。
- 测试放在所属职责的 `tests/` 子目录；Fixture 只服务本职责测试，不跨职责共享。
- Android/平台回调顺序和序列化逻辑在对应平台测试中验证；真实第三方 SDK 行为通过 Debug 包和目标设备
  验证。
- 运行时代码不得依赖 GDUnit4、测试 Fixture、Godot AI 或具体游戏代码。
- 目录、命名、依赖方向和未由运行时执行的设计规定由本文档、架构文档和独立样例表达，不用测试替身
  制造虚假的运行时保障。

## 本地配置与发布包

- 本地凭据放在项目根目录的 `override.cfg` 或等效本地覆盖文件中，并加入 Git 忽略。
- 发布包只提供不含真实凭据的 `*.example` 配置模板；不得把 Client Token、Mac Key 等敏感值提交或打包。
- 正式插件包保留运行时代码、必要的二进制依赖、配置模板、用户文档和 LICENSE。
- `tests/`、`examples/`、平台构建源码、Gradle/IDE 缓存、报告和其他生成残留不属于正式运行时包。
- 第三方源包只作为导入输入；转换并验证完成后删除未使用的源包、`.import` 和生成残留。

## 变更与影响范围

功能修改先验证所属职责；如果修改公开 API、Command、Event、Snapshot、生命周期或场景组合，则沿
`Tool -> Module -> Feature -> Application` 的实际引用闭包覆盖直接和间接消费者。只改变内部实现且
公开行为不变时，不机械扩大测试范围；无法证明边界时扩大范围并运行全量测试。

提交说明使用 `type(scope): 中文摘要`，每个提交只承担一个明确职责。涉及 Godot 场景、资源、运行结果
或截图时优先使用 Godot AI MCP；纯静态检查和无界面测试可以使用命令行。

# Godot Framework 使用说明

Godot Framework 是面向 Godot 4.7+ 的轻量运行时架构 addon，只提供基础类型和共享规则。具体游戏或
功能插件使用 Application、Feature、Module、Tool 四种职责组织运行时代码，物理目录统一使用复数名称。

## 推荐项目结构

```text
game/
  applications/
  features/
  modules/
  tools/
  arts/
  docs/
```

目录按职责判定：

- `game/applications` 只保存入口脚本、入口场景、测试和规则文件。一次运行只有一个活动 Application，
  它只完成实现选择、依赖校验、显式注入和生命周期组合，不保存额外业务场景或资源。
- `game/features` 保存完整、用户可感知的功能切片。Feature 可以协调零个或多个 Module；
  `PlayerController` 是 Feature，而不是 Module 或 Tool。
- `game/modules` 保存内聚、独立可测试的领域能力和权威状态。
- `game/tools` 保存无领域状态的 GF Tool 实现，不是开发期杂项目录。生成、验证和构建脚本放在仓库根
  `tools`。
- `game/arts` 只保存纯视觉资源，不构成第五层。纯美术不得包含业务脚本、碰撞体、物理体或玩法状态，
  也不得反向依赖运行时职责。Feature/Module 引用纯美术并加入玩法节点后形成的游戏场景归所属职责的
  `scenes`。

只在存在实际内容时建立目录。

## 启用方式

将 `addons/godot_framework` 放入 Godot 项目后等待脚本导入即可使用。该插件不包含需要启用的
`EditorPlugin`，也不注册 autoload；导入完成后，`GF` 前缀的全局类可以直接引用。

## 核心入口

- `base`：`GFApplication`、`GFFeature`、`GFModule` 等架构基础类型。
- `rules`：所有层共享的契约，当前包含 `rules/cqrs`。
- `docs/architecture.md`：四层依赖、场景组合、CQRS 和测试边界。
- `docs/plugin_development.md`：基于 GF 开发可复用功能插件的完整规范。

框架核心自身不包含具体游戏的 Application、Feature、Module 或 Tool。游戏唯一入口继承
`GFApplication`，在场景中显式声明并注入需要长期存在的 Module、Feature 和 Feature UI；能够由
类型化导出引用表达的依赖不得通过 `get_node` 查找。

这一规则适用于所有场景脚本，而不仅是 Application：编辑期已知的固定 Node 使用带具体类型的
`@export var`，并由 `.tscn` 显式绑定；不得使用 `get_node`、`get_node_or_null`、`$Node`、
`%UniqueNode` 或基于这些路径的 `@onready`。只有运行时创建、数量不定、来自外部数据或设计期路径
不可知的 Node 才允许动态解析，且必须验证类型并处理缺失节点。

## CQRS 使用边界

- Command 是不可变的变更意图，通过显式强类型 API 提交。
- Query 是同步只读方法，返回与内部状态隔离的 Snapshot。
- Event 是已经发生的事实，通过专用强类型 Signal 传递。
- `GFSubmitResult` 只表示本地提交是否被接受；权威执行结果通过领域 Event 和唯一的
  `GFCommandCompletedEvent` 异步表达。

可能用于联网的消息只包含数据值和稳定字符串 ID，不包含 `Node`、`Object` 或 `NodePath` 身份。
完整生命周期与字段约束见 `architecture.md`。

## 测试

框架运行时代码不依赖 GDUnit4，因此正式插件可以在没有 GDUnit4 的项目中导入。开发测试命令与发布
方式见仓库根 `docs/development.md`。可运行的消费方演示由宿主项目维护，不属于框架插件子树或正式
归档；若只分发插件子树，以本目录内的架构文档和 Agent 规则为准。

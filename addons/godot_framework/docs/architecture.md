# 架构规则

## 设计哲学

以下原则是 Godot Framework 的设计核心，优先级高于局部实现便利。新增能力和重构必须能够说明
自己如何保持这些原则。

### KISS：保持简单

- 只解决已经存在且边界明确的问题，不为预测中的需求提前建设通用机制。
- 优先组合 Godot 原生能力；只有现有结构产生重复或无法建立稳定边界时才增加抽象。
- 抽象必须让依赖、数据流和失败方式更清楚，不能只把复杂度转移或隐藏。
- 不引入业务 autoload、服务定位器、全局消息总线、反射扫描等隐式机制。

### Agent 友好：让上下文可局部理解

- 命名和路径必须稳定、明确、可搜索，类名与单文件职责一一对应。
- 依赖、组合、生命周期和通信契约必须显式，不能依赖约定外的全局状态。
- 公开 API 与内部实现隔离；理解或修改一个职责时，不要求读取无关模块。
- 文档说明设计意图，测试说明可观察行为，两者与代码共同构成框架能力。
- 低魔法优先于少写几行代码，可验证性优先于调用便利性。

### 四层架构：职责不可互换

Application 是组合根，Feature 管理跨模块用例，Module 拥有内聚领域能力，Tool 提供无领域状态
的基础能力。四层是具体游戏代码的职责模型，不是核心插件内部必须建立的四个目录。

基于 GF 的可复用功能插件可以提供自己的四层运行时代码。项目和插件中的职责目录统一命名为
`applications`、`features`、`modules`、`tools`；类型与架构术语保持单数。项目纯美术资源统一放在
`game/arts`，它不构成第五层且不得反向依赖运行时职责。项目目录和插件目录只是物理分布，插件
目录不构成第五层；平台适配、原生 SDK、模拟器和导出实现应按职责归入 Tool 或对应 Module，而不
建立顶层 `runtime`、`adapter` 或 `android_plugin`。

Feature 和 Module 都不得相互依赖同层职责单元。跨 Module 行为只能由 Feature 通过公开 API
协调；模块通信只能使用明确的 Command、Query 和 Event 契约。不得通过跨层访问、共享可变状态
或全局消息总线绕过边界。

### CQRS 与联网一致性

Command 表达变更意图，Query 读取隔离快照，Event 表达已经发生的事实。Command 的同步返回值
只说明本次提交是否被接受，不携带业务执行结果；权威结果由后续 Event 表达。该语义必须在本地
与联网实现中保持一致，CQRS 核心不直接绑定具体 RPC 或传输协议。

### 测试是一等能力

公开行为必须能够脱离完整游戏流程进行隔离验证。框架或业务代码实际执行的行为、分支、不变量
和 Bug 回归必须更新对应的 GDUnit4 测试；普通 getter、Marker 类型、Godot 原生行为和资产视觉
结果不测试。目录、命名和依赖方向由规则文档与 Agent 静态检查保证；尚未由框架组件执行的设计
规定通过文档和独立消费方演示说明，不能用测试替身制造虚假的框架保障。

功能修改的测试范围由实际影响闭包决定：

- 修改职责自身的行为时，更新并运行该职责测试。
- 修改公开 API、Command、Event、Snapshot、生命周期或其他可观察行为时，继续覆盖所有实际直接、
  间接消费者。影响沿 Tool -> Module -> Feature -> Application 向使用方传播；框架 `base` 和
  `rules` 覆盖实际使用它们的框架与游戏职责。
- 只改变内部实现且公开行为不变时，仅验证所属职责；Bug 回归测试放在最早能观察问题的职责边界。
- 多处修改取各自影响范围并集。Agent 根据显式代码引用、场景组合和通信契约记录判断依据；无法
  证明边界时扩大范围，必要时运行全量测试。

受影响消费者的测试仍放在各自职责的 `tests` 中，不集中到被修改组件旁。独立消费方演示不属于框架
功能修改的影响测试范围，也不作为运行时兼容验证要求。

测试放在所属职责的 `tests` 子目录，Fixture 只能服务本职责测试。运行时代码不得依赖测试代码
或测试框架；正式插件包排除所有测试，使运行时在没有 GDUnit4 时仍可编译。

## 框架核心

核心插件包含两类运行时代码：

- `base` 定义 `GFApplication`、`GFFeature` 和 `GFModule`。
- `rules` 定义所有层共享的规则和契约；CQRS 位于此处，不属于 Tool。

这两个目录描述框架自身职责。Application、Feature、Module、Tool 四层描述使用框架构建的
具体游戏或能力代码。

## 四层依赖

```text
Application
  -> Feature
  -> Module
  -> Tool

Feature -> Module public API, Tool
Module  -> Tool
Tool    -> 不依赖更高层
```

Application 选择本地或远程 API 的具体实现并显式注入。Feature 负责跨 Module 行为和信号订阅。
Module 拥有内聚能力及其权威状态。Tool 是无领域状态的基础辅助代码。

独立 Module 之间的联动必须由游戏 Application 中的 Feature 负责。

## 公开边界与文件

具体 Feature 或 Module 按需包含 `public`、`internal` 和 `AGENTS.md`。`AGENTS.md` 应说明职责、依赖、
Command、Query、Event 与生命周期。职责外部只能引用 `public`。

每个具有独立职责的类单独存放在一个文件中，不创建 `messages.gd`、`models.gd`、`utils.gd`
这类聚合文件。没有独立行为的局部枚举、常量或私有辅助函数可以留在所属类中。

## 生命周期与场景组合

- Application 级管理器、Module、Feature 和 Feature UI 是 Application 场景拥有的 Node。
- Application 场景通过子节点或 PackedScene 实例声明这些依赖，具体 Application 使用类型化导出变量
  接收引用；不得用 `get_node`、`get_node_or_null`、`add_child` 或运行时实例化替代场景声明。
- 运行时实体是由所属场景实例化和管理的 PackedScene。
- Command、Event、Result 和 Snapshot 是轻量值对象。
- 可编辑的静态配置使用 Resource；无场景所有权的 Tool 和值对象可以由代码创建。

`GFApplication` 默认在 `_enter_tree()` 中执行 `compose()`，早于子节点 `_ready()`。如果导出 Node
引用必须等场景进入树后才能解析，具体 Application 可以显式延迟到 `_ready()`，但必须先验证所有
场景依赖并保持显式注入。Feature 在依赖注入后连接信号，并在离开场景树时断开自己拥有的连接。

Feature 的场景和资源归属该 Feature 的 `scenes/`、`assets/` 等目录，由 Application 场景挂载；UI
只能调用 Feature 公开 API，不得直接访问 Module 内部状态或平台桥接。

## Command 生命周期

1. 调用方使用稳定 `command_id` 创建强类型 Command。
2. 公开 API 验证 Command，并接受或拒绝本次提交。
3. 提交被拒绝时返回 `GFSubmitResult.accepted == false`，且不产生完成事件。
4. 提交被接受后，在本地执行或发送给权威端。
5. 执行成功时先发送领域 Event。
6. 每个已接受 Command 最后发送且只发送一个 `GFCommandCompletedEvent`。

完成失败表示业务拒绝；提交失败表示消息无效或适配器不可用。调用方不得把本地接受等同于
权威执行成功。

## Query 与联网

Query 是针对本地权威状态或复制状态的强类型同步读取方法，并返回隔离快照。远程请求/响应式
Query 不属于核心规则。

强类型 GDScript 消息只存在于本地 API 内。网络适配器可将其编码为数据包：

```text
Command = { type, command_id, payload }
Event   = { type, event_id, causation_id, payload }
```

实体引用使用稳定字符串 ID。可联网 payload 不允许包含 Object、Node、Callable、RID 或
NodePath 身份。

可复用功能插件的目录、场景组合、平台 Tool、测试、凭据和发布边界见
[`plugin_development.md`](plugin_development.md)。

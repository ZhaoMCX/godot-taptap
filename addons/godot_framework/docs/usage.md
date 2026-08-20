# Godot Framework 使用说明

Godot Framework 是面向 Godot 4.7+ 的轻量运行时架构 addon，只提供基础类型和共享规则。具体游戏或
功能插件使用 Application、Feature、Module、Tool 四层组织运行时代码，物理目录统一使用复数名称。

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

`game/arts` 保存纯视觉资源，不构成第五层，也不得反向依赖其他游戏职责。只在存在实际内容时建立目录。

## 启用方式

将 `addons/godot_framework` 放入 Godot 项目后等待脚本导入即可使用。该插件不包含需要启用的
`EditorPlugin`，也不注册 autoload；导入完成后，`GF` 前缀的全局类可以直接引用。

## 核心入口

- `base`：`GFApplication`、`GFFeature`、`GFModule` 等架构基础类型。
- `rules`：所有层共享的契约，当前包含 `rules/cqrs`。
- `docs/architecture.md`：四层依赖、场景组合、CQRS 和测试边界。
- `docs/plugin_development.md`：基于 GF 开发可复用功能插件的完整规范。

框架核心自身不包含具体游戏的 Application、Feature、Module 或 Tool。游戏入口继承
`GFApplication`，在场景中显式声明并注入需要长期存在的 Module、Feature 和 Feature UI。

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

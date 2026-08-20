# Godot TapTap 插件规则与使用契约

## 插件定位

本插件为 Godot 4.7+ 和 Godot Framework 提供 TapSDK Android 4.10.8 集成。当前版本包含统一初始化、
TapTap 登录、合规认证和云存档，不包含广告、支付、成就或排行榜。

本文档是插件能力、接入契约、维护规则与验收流程的唯一规范源。Agent 操作本插件目录中的代码、场景、
资源或构建配置前，必须加载并遵守本文档。

本文件规定 TapTap 插件子树的开发约束；面向使用方和发布包的说明保留在 `README.md`。

## 四层归属

本插件是基于 `godot_framework` 的可复用功能库，不是 GF 核心插件本身。插件中的运行时代码与项目代码
共同遵守以下依赖方向：

```text
Application -> Feature -> Module -> Tool
```

插件运行时代码按职责组织如下：

```text
applications/                 TapTapApplication 独立组合根
features/access/scenes/       TapTap 访问流程与标准交互面板
features/cloud_save/scenes/   通用云存档协调与玩家界面
modules/core/                 TapSDK 初始化与配置
modules/login/                登录、登出和账号状态
modules/compliance/           合规认证与结果
modules/cloud_save/           云存档 Command、Event、Snapshot 与 Module
tools/taptap/adapter/         TapSDK 桥接和回调适配
tools/taptap/contracts/       原生边界错误、结果和隐私参数
tools/taptap/cloud_save/      宿主本地存档接口与同步记录
tools/taptap/android_plugin/  Android 平台实现源码
tools/taptap/bin/             Debug/Release AAR
tools/taptap/simulator/       桌面 Debug TapSDK 模拟桥接
```

- `application` 是插件提供的独立组合根，可以直接运行，也可以由 GF 项目的 Application 继承或参考；
  它在场景中声明 Module、Feature 和 Feature UI，通过类型化导出引用完成注入，Tool 仍由代码创建。
- `feature` 只协调跨 Module 用例，必须继承 `GFFeature`，由使用方 Application 显式创建和注入。
- Feature 可以包含自己的 `scenes` 和 `assets`；标准交互面板由 Application 场景声明并挂载，只调用
  Feature 公开 API，不直接访问 Module 内部或 Android 桥接。
- `module` 中每个 TapSDK 能力对应一个 `GFModule`；Module 之间禁止直接依赖，只能通过公开 Command、
  Event、Snapshot 和 Tool 协作。
- `tools/taptap` 放置无领域状态的 TapSDK 适配、平台实现、配置辅助和边界契约；Android 源码、AAR 与
  EditorExportPlugin 都属于 Tool 实现细节。
- `tools/taptap/simulator` 放置桌面 Debug 所需的 TapSDK 模拟桥接；它不承担业务状态，面板通过可选
  依赖使用它。
- 不建立顶层 `runtime`、`adapter` 或 `android_plugin` 架构层。值对象按实际职责归入对应 Module 或
  Tool 契约目录。

`applications/tap_tap_application.tscn` 是可直接运行的组合根。GF 项目可以继承或参考其组合方式；场景
显式声明 Module、Feature 和标准面板，Application 通过类型化导出引用完成注入。

## TapSDK 能力规则

- TapSDK 统一初始化由 Core Module 负责；其他 Module 不得重复初始化 SDK，也不得相互调用。
- `TapTapAccessFeature` 负责协调初始化、账号恢复、登录、登出和合规认证，并由 Application 显式连接信号。
- Module 的命令提交只返回 `GFSubmitResult`；权威执行结果通过领域 Event 和唯一的
  `GFCommandCompletedEvent` 表达。
- Access Feature 只有收到合规 code `500` 才能发出 `access_granted`；未知结果必须拒绝访问。
- Access Token、Client Token、Mac Key 等敏感材料不得越过 Tool 边界，也不得进入日志、Event 或
  Snapshot。

## 云存档契约

`TapTapCloudSaveModule` 提供以下显式命令入口：

- `submit_create(TapCloudSaveCreateCommand)`
- `submit_list(TapCloudSaveListCommand)`
- `submit_download_data(TapCloudSaveDownloadDataCommand)`
- `submit_update(TapCloudSaveUpdateCommand)`
- `submit_delete(TapCloudSaveDeleteCommand)`
- `submit_download_cover(TapCloudSaveDownloadCoverCommand)`

上传与下载路径必须位于 `user://`。存档文件上限为 10 MiB，封面文件上限为 512 KiB；适配器必须在
调用原生 SDK 前校验上传文件。下载由 Android 端先写入临时文件，再替换目标文件，禁止把未完成内容
暴露给游戏。

```gdscript
var cloud_save := tap_tap_application.tap_tap_cloud_save_module
cloud_save.archive_created.connect(_on_archive_created)
cloud_save.command_completed.connect(_on_cloud_save_completed)

var metadata := TapCloudSaveMetadata.new("slot_1", "第一章营地", "", 3600)
var result := cloud_save.submit_create(
	TapCloudSaveCreateCommand.new(metadata, "user://saves/slot_1.save")
)
if not result.accepted:
	push_warning(result.message)
```

列表结果通过 `archive_list_received` 返回，下载完成分别通过 `data_downloaded` 和 `cover_downloaded`
返回，最终命令结果统一通过 `command_completed` 表达。`get_snapshot()` 可读取最近一次列表、忙碌状态、
当前操作类型和 SDK 状态码。

模块一次只执行一个云存档操作。它不得自动覆盖冲突、自动重试或静默选择远端或本地版本；游戏必须
根据存档时间、进度和自身产品规则显式决定更新、下载或保留哪一份。

删除成功响应的最低契约只保证 `uuid`。`name`、`file_id` 和其他存档字段均视为可选；游戏和测试替身
不得依赖删除响应补全这些字段。

桌面 Debug 使用内存模拟桥接，可验证完整 CRUD、下载替换和错误分支，但不连接 TapTap 服务。

## 通用存档界面与宿主接入

`TapTapCloudSaveFeature` 和 `TapTapCloudSavePanel` 提供固定槽位的手动云同步界面。登录与合规认证通过后，
`TapTapApplication` 自动隐藏访问面板并显示存档面板。界面只显示宿主声明的槽位，不显示 UUID、文件 ID
或无法识别的远端记录。

游戏通过继承 `TapCloudSaveLocalStore` 接入自身存档格式，并实现以下边界：

- `get_slot_definitions()` 返回稳定的 `slot_id`、合法 ASCII `archive_name` 和玩家可见名称。
- `read_slot()` 返回本机摘要、游玩时间、修改时间和内容指纹。
- `prepare_upload()` 生成位于 `user://` 的不可变上传文件与可选封面。
- `import_download()` 校验下载文件并原子替换本机槽位。
- `load_slot()` 让游戏立即应用已确认的本机槽位。

Application 场景必须显式注入 `TapTapCloudSaveFeature`、`TapTapCloudSavePanel` 和宿主的
`TapCloudSaveLocalStore` 节点。插件自带的基础 Store 返回空槽位；当前仓库的
`game/modules/sample_save` 提供三个 JSON 示例槽位，仅用于开发验证，不进入插件发布包。

第一版只自动刷新列表和异步封面，不得自动上传、下载或覆盖。首次同时发现本机和云端版本时显示冲突
选择；同步历史存在后，Feature 根据本机指纹及远端 UUID、文件 ID 和修改时间区分单边更新。云列表
失败时保留本机离线载入，并禁用上传与删除。

## 本地配置

将配置模板复制到项目根目录，并只在本机填写凭据：

```powershell
Copy-Item addons/godot_taptap/tools/taptap/config/override.cfg.example override.cfg
```

真实 `override.cfg` 必须被 Git 忽略。Android 导出必须显式包含该文件；Release 构建要求
`tap_sdk/enable_debug_log=false`。发布包只能包含
`tools/taptap/config/override.cfg.example`。

## 文件规则

- 每个独立职责类单独存放；Command、Event、Snapshot、Adapter、边界契约和测试替身不得合并成
  聚合文件。
- Adapter 测试放在 `tools/taptap/adapter/tests`；各 Module、Feature 和 Core 配置测试放在自身
  `tests` 子目录，Fixture 不得跨职责共享。

## 构建、测试与发布

```powershell
.\tools\build_android.ps1
.\tools\build_android.ps1 -DeviceTest
.\tools\package_godot_taptap.ps1
```

`build_android.ps1` 构建 Android 插件，将 AAR 输出到 `tools/taptap/bin`，然后导出 Android APK。

TapTap 能力必须按以下三层顺序验收：

1. 运行 GDUnit4 与 Android Kotlin 测试，覆盖状态机、异常分支、回调顺序、序列化、文件边界和
   Bug 回归。Android 回调顺序和序列化逻辑必须有 Kotlin 测试。
2. 使用 `-DeviceTest` 构建真机自动测试 APK，验证真实 TapSDK、Android 桥接、服务端交互和应用
   重启恢复。测试必须完成创建、刷新、下载导入、更新、计划重启、恢复后再次下载、仅返回 `uuid`
   的删除、确认远端已删除、重新创建并取得新 `uuid`，最后清理测试存档。
3. 安装不带 `-DeviceTest` 的普通 Debug APK，由人工验收存档界面的按钮、确认弹窗、状态反馈、文案
   和易用性。DeviceTest APK 会按测试流程主动退出，不用于人工 UI 验收。

真机自动测试只有在出现 `CLOUD_SAVE_DEVICE_TEST|restart_required` 后，才允许把中途退出认定为计划
重启；重新启动后必须出现 `CLOUD_SAVE_DEVICE_TEST|passed`。缺少最终通过标记、非计划退出、Java
异常、原生崩溃或 TapTap `400002` 均判定为失败。

自动模拟点击不是发布前强制步骤，也不得代替人工 UI 验收。验收记录必须分别标注“真机技术链路通过”
和“人工 UI 验收通过”；前者只证明 SDK、桥接、服务端操作与生命周期闭环通过，不代表界面已经完成
人工验收。

真实 TapTap 云存档必须在开发者中心为同一应用开通云存档，并使用匹配的 Client ID、包名与签名在
Android 真机验证。非真机测试只验证本地契约、序列化、文件边界和桥接调用，不代表服务端权限生效。

正式插件包保留四层运行时代码、AAR、配置模板、`AGENTS.md` 和 LICENSE，排除测试、Android 构建源码、
缓存、真实 `override.cfg` 和插件级 README。`AGENTS.md` 必须随包分发，作为下游 Agent 操作插件时的
唯一能力说明与规则入口。

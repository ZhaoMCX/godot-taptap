# Godot TapTap

本插件为 Godot 4.7+ 和 Godot Framework 提供 TapSDK Android 4.10.8 集成。当前版本包含统一初始化、TapTap 登录、合规认证和云存档，不包含广告、支付、成就或排行榜。

## 四层结构

TapTap 是可复用的 GF 功能插件，与具体游戏共同遵守同一套四层架构。项目代码和插件代码只是物理分布不同：

```text
Application -> Feature -> Module -> Tool
```

插件运行时代码按职责组织如下：

```text
applications/               TapTapApplication 独立组合根
features/                  跨 Module 用例协调
features/access/scenes/    TapTap 交互面板场景与脚本
features/cloud_save/       通用云存档协调与玩家界面
modules/core/              TapSDK 初始化与配置
modules/login/             登录、登出和账号状态
modules/compliance/        合规认证与结果
modules/cloud_save/        云存档 Command、Event 与 Snapshot
tools/taptap/adapter/      TapSDK 桥接和回调适配
tools/taptap/contracts/    原生边界的错误、结果和隐私参数
tools/taptap/cloud_save/   本地存档接口与同步记录
tools/taptap/android_plugin/ Android 平台实现源码
tools/taptap/bin/          Debug/Release AAR
tools/taptap/simulator/    桌面 Debug TapSDK 模拟桥接
```

没有顶层 `runtime`、`adapter` 或 `android_plugin` 架构层。Android 源码、AAR 和导出脚本都是 Tool 的实现细节；账号快照、合规结果和 Core 配置归属于各自 Module。

插件提供 `applications/tap_tap_application.tscn` 作为可直接运行的 TapTap 组合根。场景显式声明 Module、Feature 和交互面板，Application 通过类型化导出引用完成注入；Tool/`RefCounted` 对象仍由代码创建。由于导出 Node 引用在场景进入树后解析，TapTap Application 在 `_ready()` 完成组合，面板支持随后注入。非 GF 项目可以直接将它设置为主场景；GF 项目保留自己的 Application，并可继承或参考该组合方式。插件不注册业务 Autoload。Module 之间不直接依赖，Feature 通过公开 Command、Event 和 Snapshot 协调它们。

`features/access/scenes/taptap_access_panel.tscn` 是插件提供的标准交互面板，文件归属 Feature，并由 Application 场景声明、通过导出引用注入并挂载。它通过 `TapTapAccessFeature` 操作初始化、登录、登出、重试和合规流程；桌面 Debug 环境下可注入 `tools/taptap/simulator/TapSdkSimulatorBridge` 模拟结果。

## 本地配置

将配置模板复制到项目根目录，并只在本机填写凭据：

```powershell
Copy-Item addons/godot_taptap/tools/taptap/config/override.cfg.example override.cfg
```

真实 `override.cfg` 已被 Git 忽略。Android 导出必须显式包含该文件；Release 构建要求 `tap_sdk/enable_debug_log=false`。

## 构建、测试与发布

```powershell
.\tools\package_godot_taptap.ps1
```

具体游戏的 Android 构建由游戏分支自行维护。正式插件包保留 GF 与 TapTap 的运行时代码、AAR、配置模板、README 和 LICENSE，排除测试、Android 构建源码与缓存。

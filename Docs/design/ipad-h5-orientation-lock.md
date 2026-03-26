# iPad H5 广告方向锁定设计文档

> **Status**: In Progress
> **PR**: https://github.com/ParticleMedia/msp-ios-sdk/pull/555
> **Date**: 2026-03-21
> **Author**: Pengyu Gou

---

## 1. 问题描述

iPad 上展示 H5 插屏广告时，用户旋转设备会导致广告布局错乱。需要在广告展示期间锁定方向为展示时的方向。

### 根本原因

iPad 多任务机制（Split View / Slide Over）导致系统级限制：

| 条件 | 系统行为 |
|------|---------|
| `UIRequiresFullScreen = YES` | App 独占全屏，系统尊重 `supportedInterfaceOrientations`，`requestGeometryUpdate` 有效 |
| `UIRequiresFullScreen = NO`（默认） | App 参与多任务，方向由 WindowScene 决定，VC 的 `supportedInterfaceOrientations` 几乎无效 |

这是 Apple 的设计决策。在多任务模式下，系统会拒绝 `requestGeometryUpdate` 的锁定请求。

---

## 2. PR #551 现有实现的问题

Code Review 发现以下问题，已在方案 A 重构中全部解决：

### Issue 1: `handleDeviceOrientationChange` selector 签名不规范 (P2)

**文件**: `NovaInterstitialAdViewController.swift:219`

```swift
// 原始代码 — 缺少 Notification 参数
@objc private func handleDeviceOrientationChange() { ... }
```

**分析**: Objective-C 消息分发机制下，零参数 `@objc` 方法作为 `NotificationCenter` selector **不会 crash**（runtime 忽略多余参数）。但不符合 Apple 推荐的方法签名规范，且无法获取 notification 上下文。

**处理**: 方案 A 删除了整个 notification 机制，此问题不再存在。

### Issue 2: 缺少 `endGeneratingDeviceOrientationNotifications` (P1 - 资源泄漏)

**文件**: `NovaInterstitialAdViewController.swift:166`

```swift
// 原始代码 — 只有 begin，没有对应的 end
UIDevice.current.beginGeneratingDeviceOrientationNotifications()
```

**原因**: `beginGeneratingDeviceOrientationNotifications` 是引用计数 API。每次 `begin` 必须配对一次 `end`，否则加速度计持续运行，影响设备电量和性能。当前代码在 `viewDidDisappear` 中只 `removeObserver`，未调用 `endGeneratingDeviceOrientationNotifications()`。

**处理**: 方案 A 不使用 `beginGenerating` API，此问题不再存在。

### Issue 3: `UIRequiresFullScreen` 隐藏依赖未文档化 (P1)

**文件**: `Examples/MSPDemoApp/MSPDemoApp/Info.plist`

**原因**: DemoApp 的 Info.plist 添加了 `UIRequiresFullScreen = YES`，但 SDK 集成文档中没有说明此依赖。宿主 App 不设置此项则整套方向锁定方案在 iPad 上无效，且该设置会禁用 iPad 多任务功能。

**处理**: 方案 A 新增运行时检测 — 首次调用 `lockOrientationIfNeeded()` 时检查 `Bundle.main` 的 `UIRequiresFullScreen` 设置，未设置时输出 warning log。同时需在 SDK 集成文档中明确标注。

### Issue 4: iOS 15 无处理 (P3 - Known Limitation)

**文件**: `NovaInterstitialAdViewController.swift:164`

```swift
if #available(iOS 16.0, *) { ... }
// iOS 15 直接跳过，无降级处理
```

**原因**: `requestGeometryUpdate` 和 `setNeedsUpdateOfSupportedInterfaceOrientations` 是 iOS 16+ API。iOS 15 iPad 上 H5 广告仍会随设备旋转。

**处理**: 标注为 known limitation。iOS 15 市场占有率已很低（< 3%），长期可通过方案 B（JS 注入）覆盖。

---

## 3. 方案对比

| 方案 | iOS 15 | 不需 UIRequiresFullScreen | 宿主零侵入 | 复杂度 | 推荐度 |
|------|:------:|:------------------------:|:---------:|:-----:|:-----:|
| PR #551 原始方案（修 bug 后） | - | - | - | 中 | ** |
| **方案 A: viewWillTransition 替代** | - | - | - | 低 | *** |
| 方案 B: H5 层 JS 注入 | + | + | + | 中 | **** |
| 方案 C: AppDelegate 协作 | + | - | - | 中 | ** |

### 业界参考

| SDK | 策略 |
|-----|------|
| **Google AdMob** | 不锁定方向，依赖 creative 自身响应式设计 |
| **Unity Ads** | 要求宿主 App 设置 `UIRequiresFullScreen` |
| **AppLovin / MoPub** | 独立 UIWindow 展示全屏广告，iPad 多任务下同样无法锁定 |
| **Apple 官方立场** | iPad App 应支持多方向；需要锁定的场景应设置 `UIRequiresFullScreen` |

---

## 4. 确定方案

### 短期（当前版本）: 方案 A — viewWillTransition 替代

用系统回调 `viewWillTransition(to:with:)` 替代手动订阅 `UIDevice.orientationDidChangeNotification`，同时修复全部已知 bug。

#### 改动点

**NovaInterstitialAdItem.swift** — `requestToDisplay` 方法：
- 在 `init` 时从 `rootViewController` 捕获当前 orientation，作为初始锁定值

**NovaInterstitialAdViewController.swift** — 主要改动：

1. **删除** `UIDevice.current.beginGeneratingDeviceOrientationNotifications()` 及相关订阅（消除 Issue 1、Issue 2）
2. **删除** `handleDeviceOrientationChange` 方法
3. **`viewWillAppear`**: 兜底捕获 orientation（若 init 时未拿到）
4. **`viewDidAppear`**: 首次锁定 — 调用 `lockOrientationIfNeeded()`
5. **`viewWillTransition(to:with:)`**: 系统旋转回调中重新强制 geometry 回到锁定方向（替代 DeviceOrientationNotification）
6. **`viewWillDisappear`**: 恢复 `.all` + `setNeedsUpdateOfSupportedInterfaceOrientations()`，让宿主 App 接管
7. **`supportedInterfaceOrientations`**: iPad + H5 时返回 `lockedOrientationMask`
8. **`shouldAutorotate`**: H5 广告返回 `false`
9. **新增** `warnIfFullScreenNotRequired()` — 运行时检测宿主 App 是否设置 `UIRequiresFullScreen`，未设置时输出 warning log（仅触发一次）

#### 新增私有方法

```swift
private func lockOrientationIfNeeded() {
    guard case .html = interstitialAd.creativeType,
          UIDevice.current.userInterfaceIdiom == .pad else { return }
    warnIfFullScreenNotRequired()
    if #available(iOS 16.0, *) {
        let target = lockedOrientationMask ?? .portrait
        view.window?.windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: target))
        setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}

/// Logs a warning once if the host app has not set UIRequiresFullScreen = YES.
private func warnIfFullScreenNotRequired() {
    guard !Self.didWarnFullScreen else { return }
    let requiresFullScreen = Bundle.main.object(forInfoDictionaryKey: "UIRequiresFullScreen") as? Bool ?? false
    if !requiresFullScreen {
        Self.didWarnFullScreen = true
        print("[MSP-SDK] ⚠️ UIRequiresFullScreen is not set to YES in the host app's Info.plist. "
            + "iPad H5 ad orientation locking will not work without this setting.")
    }
}

private static var didWarnFullScreen = false
```

#### 对比 PR #551 原始方案的改进

| 改进 | 说明 |
|------|------|
| 消除资源泄漏 | 不再需要 `begin/endGeneratingDeviceOrientationNotifications` |
| 消除不规范 selector | 不再使用 `DeviceOrientationNotification` + 零参数 selector |
| 更可靠的时序 | `viewWillTransition` 是系统回调，时序由 UIKit 保证 |
| 运行时依赖检测 | 首次锁定时检查 `UIRequiresFullScreen`，未设置输出 warning log |
| 代码量减少约 40% | 删除 notification 订阅/清理/handler 相关代码 |

#### 前置条件

宿主 App 的 `Info.plist` 必须设置：

```xml
<key>UIRequiresFullScreen</key>
<true/>
```

**影响**: 禁用 iPad Split View 和 Slide Over。需在 SDK 集成文档中明确标注。

### 长期（下一版本）: 方案 B — H5 层 JS 注入

在 WebView 加载 H5 广告时注入 JavaScript，让 H5 内容在设备旋转时通过 CSS transform 自行保持布局。原生层无需任何 orientation API。

**优势**: 不需要 `UIRequiresFullScreen`、iOS 15/16+ 均支持、宿主 App 零侵入。

**待验证**: 需与广告侧对齐，确认 H5 creative 兼容 CSS transform 注入。

---

## 5. iPadOS 26 兼容 — prefersInterfaceOrientationLocked

### 背景

iPadOS 26 (WWDC 2025) 引入了以下变化：
- `UIRequiresFullScreen` Info.plist key **已被废弃**，未来版本将被忽略
- `shouldAutorotate` 不再被系统查询
- `requestGeometryUpdate` 在新窗口系统下不再可靠

Apple 在 WWDC 2025 Session 282 "Make your UIKit app more flexible" 中提供了新的替代 API。

### 新 API: `prefersInterfaceOrientationLocked` (iOS 26+)

Per-VC 级别的方向锁定，**不依赖 `UIRequiresFullScreen`**，不需要宿主 App 任何配置。

```swift
// 声明锁定偏好
override var prefersInterfaceOrientationLocked: Bool {
    return isOrientationLockActive
}

// 变更时通知系统
setNeedsUpdateOfPrefersInterfaceOrientationLocked()
```

### 分层兼容策略

| iPadOS 版本 | 方案 | API | 需要 UIRequiresFullScreen |
|------------|------|-----|:------------------------:|
| iPadOS 26+ | `prefersInterfaceOrientationLocked` | 新 API | 否 |
| iPadOS 16-25 | `requestGeometryUpdate` + `supportedInterfaceOrientations` | Legacy | 是 |
| iPadOS 15 | Known limitation | 无 | N/A |

### 实现

`activateOrientationLock()` / `deactivateOrientationLock()` 统一入口，内部按版本分发：
- iOS 26+: 设置 `isOrientationLockActive` + `setNeedsUpdateOfPrefersInterfaceOrientationLocked()`
- iOS 16-25: `legacyLockOrientationIfNeeded()` → `requestGeometryUpdate`

### 参考

- [WWDC 2025 Session 282](https://developer.apple.com/videos/play/wwdc2025/282/)
- [TN3192: Migrating from UIRequiresFullScreen](https://developer.apple.com/documentation/technotes/tn3192-Migrating-your-app-from-the-deprecated-UIRequiresFullScreen-key)

---

## 6. Known Limitations

| 限制 | 原因 | 缓解措施 |
|------|------|----------|
| 需要宿主 App 设置 `UIRequiresFullScreen = YES` | Apple 设计决策：iPad 多任务模式下系统拒绝 `requestGeometryUpdate` | SDK 运行时检测并输出 warning log；集成文档明确标注 |
| iOS 15 iPad 不支持方向锁定 | `requestGeometryUpdate` 是 iOS 16+ API | 市场占有率 < 3%，长期可通过方案 B（JS 注入）覆盖 |
| `viewWillTransition` 中反向锁定可能有短暂视觉闪烁 | 系统已开始旋转动画时 `requestGeometryUpdate` 请求回到原方向 | `shouldAutorotate = false` 在 `UIRequiresFullScreen` 模式下可阻止大部分旋转 |

---

## 7. 测试计划

| 场景 | 预期 |
|------|------|
| iPad + H5 广告 + portrait 展示 + 旋转设备 | 广告保持 portrait |
| iPad + H5 广告 + landscape 展示 + 旋转设备 | 广告保持 landscape |
| iPad + 非 H5 广告 + 旋转设备 | 广告跟随旋转（不锁定） |
| iPhone + H5 广告 | 行为不变（锁定为展示方向） |
| iPad + H5 广告 + dismiss 后 | 宿主 App 方向恢复正常 |
| `UIRequiresFullScreen = NO` 的宿主 App (iPadOS 16-25) | 锁定无效（已知限制，需文档说明） |
| iPadOS 26 + H5 广告 + portrait 展示 + 旋转设备 | 广告保持 portrait（无需 UIRequiresFullScreen） |
| iPadOS 26 + H5 广告 + landscape 展示 + 旋转设备 | 广告保持 landscape（无需 UIRequiresFullScreen） |
| iPadOS 26 + H5 广告 + dismiss 后 | 宿主 App 方向恢复正常 |

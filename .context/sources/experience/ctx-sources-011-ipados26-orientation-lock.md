---
id: ctx-sources-011
title: "iPadOS 26 方向锁定失效 — UIRequiresFullScreen 废弃与 prefersInterfaceOrientationLocked 迁移"
domain: sources
layer: experience
tags: [orientation, ipad, ipados-26, uirequiresfullscreen, prefers-orientation-locked, request-geometry-update, should-autorotate, interstitial, fullscreen, wwdc-2025]
triggers:
  - "iPad orientation lock not working"
  - "iPadOS 26 orientation"
  - "UIRequiresFullScreen deprecated"
  - "prefersInterfaceOrientationLocked"
  - "requestGeometryUpdate not working iPad"
  - "shouldAutorotate deprecated"
  - "iPad H5 ad rotation"
  - "iPad 方向锁定"
  - "orientation lock iPad"
summary: "iPadOS 26 废弃 UIRequiresFullScreen，需用 prefersInterfaceOrientationLocked 替代，保留 iOS 15-25 fallback。"
version: "1.0"
status: active
created: "2026-03-24"
updated: "2026-03-24"
---

# iPadOS 26 方向锁定失效 — UIRequiresFullScreen 废弃与 prefersInterfaceOrientationLocked 迁移

## 问题描述

iPad H5 插屏广告的方向锁定在 iPadOS 26.3.1 上完全失效。广告展示后旋转设备，H5 内容随之旋转导致布局错乱。

## 根因分析

iPadOS 26 (WWDC 2025) 对方向控制 API 做了三项重大变更：

| 变更 | 影响 |
|------|------|
| `UIRequiresFullScreen` Info.plist key **已废弃** | 未来版本将完全忽略，依赖此 key 的 `requestGeometryUpdate` 方案失效 |
| `shouldAutorotate` **不再被系统查询** | iOS 16 deprecated，iPadOS 26 彻底移除查询。返回 `false` 无法阻止旋转 |
| iPad 新窗口系统 (Stage Manager / Windowed Apps) | `requestGeometryUpdate` 在非全屏窗口下不可靠 |

原有方案依赖 `shouldAutorotate` + `requestGeometryUpdate` + `UIRequiresFullScreen`，三个支柱在 iPadOS 26 上全部失效。

## 解决方案

### 新 API: `prefersInterfaceOrientationLocked` (iOS 26+)

Apple 在 WWDC 2025 Session 282 "Make your UIKit app more flexible" 中引入的 per-VC 方向锁定 API：

```swift
// 声明锁定偏好
@available(iOS 26.0, *)
override var prefersInterfaceOrientationLocked: Bool {
    return isOrientationLockActive
}

// 激活/解除时通知系统
setNeedsUpdateOfPrefersInterfaceOrientationLocked()
```

**优势**：
- 不需要 `UIRequiresFullScreen`
- 不需要宿主 App 做任何配置
- Per-VC 粒度，不影响其他界面

**观察锁定状态变化**（可选，在 SceneDelegate 中）：
```swift
func windowScene(_ windowScene: UIWindowScene,
    didUpdateEffectiveGeometry previousGeometry: UIWindowScene.Geometry) {
    let isLocked = windowScene.effectiveGeometry.isInterfaceOrientationLocked
}
```

### 版本分层策略

```
iOS 26+  → prefersInterfaceOrientationLocked（新 API，无外部依赖）
iOS 16-25 → requestGeometryUpdate + supportedInterfaceOrientations（需 UIRequiresFullScreen）
iOS 15   → shouldAutorotate + supportedInterfaceOrientations（系统原生尊重）
```

### 封装模式

版本分支集中在两个方法中，外部调用不感知版本差异：

```swift
private func activateOrientationLock() {
    guard /* iPad + H5 */ else { return }
    if #available(iOS 26.0, *) {
        isOrientationLockActive = true
        setNeedsUpdateOfPrefersInterfaceOrientationLocked()
    } else if #available(iOS 16.0, *) {
        // requestGeometryUpdate fallback
    }
    // iOS 15: shouldAutorotate handles it automatically
}

private func deactivateOrientationLock() {
    // 同样的版本分层，镜像结构
}
```

## 相关注意事项

1. `supportedInterfaceOrientations` 中避免访问 `self.view`，使用 `viewIfLoaded?.window` 防止 premature `loadView()`
2. `warnIfFullScreenNotRequired()` 仅在 iOS 16-25 legacy 路径调用，iOS 26 不需要
3. `shouldAutorotate` 保留是因为 iOS 15 仍需要它，不能删除

## 参考

- [WWDC 2025 Session 282: Make your UIKit app more flexible](https://developer.apple.com/videos/play/wwdc2025/282/)
- [TN3192: Migrating from UIRequiresFullScreen](https://developer.apple.com/documentation/technotes/tn3192-Migrating-your-app-from-the-deprecated-UIRequiresFullScreen-key)
- PR: https://github.com/ParticleMedia/msp-ios-sdk/pull/555
- 设计文档: `Docs/design/ipad-h5-orientation-lock.md`

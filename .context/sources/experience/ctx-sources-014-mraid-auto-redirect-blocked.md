---
id: ctx-sources-014
title: "MRAID 素材 setTimeout → mraid.open() 自动跳转 — JS 层 userActivation 防护"
domain: sources
layer: experience
tags: [mraid, auto-redirect, playable, html, webview, user-activation, click, gesture, security, ad-creative]
triggers:
  - "mraid.open() auto redirect"
  - "ad auto opens landing page"
  - "playable ad auto click"
  - "Blocked mraid.open()"
  - "no user activation"
  - "no recent user gesture"
  - "setTimeout mraid.open"
  - "auto-redirect blocked"
  - "userDidClick"
  - "navigator.userActivation"
summary: "MRAID auto-redirect via setTimeout blocked by JS userActivation check"
version: "1.0"
status: active
created: "2026-04-02"
updated: "2026-04-02"
---

## 问题

恶意广告素材在 playable/H5 广告中使用 `setTimeout → mraid.open(url)` 自动打开落地页，无需用户点击。

### 素材代码示例

```javascript
window.__autoRedirectTimer = setTimeout(function() {
  if (!window.__installClicked) window.clickInstall(); // calls mraid.open()
}, 2400);
```

### 根因

`mraidOpen()` 在 `NovaAdPlayableView` 和 `NovaAdHtmlView` 中没有用户手势验证，`mraid.open()` 通过 JS bridge 直接调到 native，绕过了 `decidePolicyFor` 中的 `userDidClick` 守卫。

## 已有的 userDidClick 机制及其问题

SDK 已有一个 `PassThroughTapView` + `userDidClick` 标记（0.3 秒 timer 重置）用于防自动跳转：

```
PassThroughTapView.hitTest → userDidClick = true → 0.3s 后重置
```

### 为什么不能用 userDidClick 保护 mraidOpen()

1. **timing 冲突**：`navigator.userActivation` 在 iOS 16+ 有 ~5s 的 transient activation 窗口，而 `userDidClick` 只有 0.3s。素材如果 click → 动画 → 0.5s 后 `mraid.open()`，JS 层放行但 native 层误杀。
2. **flag 竞争**：一次 tap 可能触发 `decidePolicyFor` + `mraidOpen()`，如果 `decidePolicyFor` 先消耗 flag（`userDidClick = false`），`mraidOpen()` 就拿不到了。
3. **hitTest 触发范围**：滑动手势也会触发 `hitTest`，误设 `userDidClick = true`。

## 修复方案

### 三条路径，各自独立防护

| 路径 | 防护层 | 机制 |
|------|--------|------|
| `mraid.open()` → JS bridge → `mraidOpen()` | **JS 层** | iOS 16+: `navigator.userActivation.isActive`; iOS 15: `click`/`touchend` listener |
| URL 导航 → `decidePolicyFor` | **Native `userDidClick`** | consume-on-use + 0.3s timer |
| `window.open()` → `createWebViewWith` | **Native `userDidClick`** | consume-on-use + 0.3s timer |

### JS 层实现（novaMraid.js）

```javascript
// iOS 15 fallback: track real click/touchend events
var _userGestureActive = false;
var _gestureTimer = null;
document.addEventListener('click', function() {
    _userGestureActive = true;
    clearTimeout(_gestureTimer);
    _gestureTimer = setTimeout(function() { _userGestureActive = false; }, 300);
}, true);
document.addEventListener('touchend', markUserGesture, true);

mraid.open = function(url) {
    if (navigator.userActivation) {
        // iOS 16+: browser-enforced, cannot be spoofed
        if (!navigator.userActivation.isActive) return;
    } else {
        // iOS 15: JS click/touchend listener
        if (!_userGestureActive) return;
    }
    postToNative('open', { url: url });
};
```

### 关键设计决策

- **`mraidOpen()` 不加 native `userDidClick` guard**：mraid.open() 是纯 JS API，JS 层一定先于 native 执行，JS 防护足够且不丢 click
- **`decidePolicyFor`/`createWebViewWith` 保留 consume-on-use**：这些路径不走 MRAID JS bridge，native 是唯一防线
- **`navigator.userActivation` 不可伪造**：由浏览器引擎控制，恶意 JS 无法绕过
- **`click`/`touchend` trusted event 不可伪造**：`document.createEvent` 创建的事件不是 trusted 的

## 涉及文件

- `Sources/Core/NovaCore/NovaCore/Resources/Scripts/novaMraid.js`
- `Sources/Core/NovaCore/NovaCore/NBResourceBundle.bundle/Scripts/novaMraid.js`
- `Sources/Core/NovaCore/NovaCore/Media/Playable/NovaAdPlayableView.swift`
- `Sources/Core/NovaCore/NovaCore/Media/Html/NovaAdHtmlView.swift`

## PR

- https://github.com/ParticleMedia/msp-ios-sdk/pull/610

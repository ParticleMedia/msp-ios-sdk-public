---
id: ctx-sources-009
title: "UIButton.Configuration 默认支持 Dynamic Type 导致广告 UI 文字溢出"
domain: sources
layer: experience
tags: [dynamic-type, accessibility, uibutton, uibutton-configuration, font-scaling, carousel, interstitial, overflow, cta, title-text-attributes-transformer]
triggers:
  - "button text overflow"
  - "font too large in ad view"
  - "Dynamic Type scaling"
  - "accessibility large text"
  - "UIButton.Configuration font"
  - "titleTextAttributesTransformer"
  - "CTA button text clipped"
  - "maximumContentSizeCategory"
  - "carousel shop now button"
  - "广告字体变大"
  - "辅助功能字体"
summary: "UIButton.Configuration 默认支持 Dynamic Type，用户开启辅助功能大字体后广告 UI 中的按钮文字会被放大导致溢出截断。需要设置 maximumContentSizeCategory 限制缩放。"
version: "1.0"
status: active
created: "2026-03-24"
updated: "2026-03-24"
---

# UIButton.Configuration 默认支持 Dynamic Type 导致广告 UI 文字溢出

## 问题描述

Carousel 广告卡片中的 "Shop Now" CTA 按钮在用户开启 iOS 辅助功能大字体后，文字被显著放大，超出按钮固定尺寸（96x26pt），导致文字被截断显示不全。

同样的问题也存在于 Interstitial 广告的 "SPONSORED" 标签。

## 根本原因

`UIButton.Configuration`（iOS 15+ API）**默认支持 Dynamic Type**。即使通过 `titleTextAttributesTransformer` 设置了固定字号（如 11pt），系统仍然会在用户开启辅助功能大字体时对文字进行缩放。

这与传统的 `button.titleLabel?.font = .systemFont(ofSize:)` 行为不同——后者使用固定 `UIFont` 不参与 Dynamic Type 缩放。

```swift
// 会被 Dynamic Type 缩放
var configuration = UIButton.Configuration.plain()
configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
    var outgoing = incoming
    outgoing.font = .systemFont(ofSize: 11)  // 仍会被放大！
    return outgoing
}

// 不会被缩放（传统方式）
let button = UIButton(type: .system)
button.titleLabel?.font = .systemFont(ofSize: 11)  // 固定大小
```

## 解决方案

在使用 `UIButton.Configuration` 的按钮上设置 `maximumContentSizeCategory`，限制 Dynamic Type 缩放上限：

```swift
let button = UIButton(configuration: configuration)
button.maximumContentSizeCategory = .large  // 限制为默认大小，不随辅助功能放大
```

## 受影响的文件

| 文件 | 组件 | 修复 |
|------|------|------|
| `NovaAdCarouselCell.swift` | CTA 按钮 ("Shop Now") | 已修复 (PR #xxx) |
| `NovaInterstitialAdVerticalSubviewHandler.swift` | SPONSORED 标签 | 已修复 (PR #xxx) |

## 开发提醒

**新建 UI 组件时必须考虑**：

1. 如果使用 `UIButton.Configuration`，**必须**设置 `maximumContentSizeCategory = .large`（除非明确需要支持 Dynamic Type）
2. 广告 SDK 的 UI 组件通常不应受辅助功能字体影响——广告素材的布局由服务端控制，字体放大会破坏布局
3. `UILabel` + 固定 `UIFont.systemFont(ofSize:)` 不受 Dynamic Type 影响，无需额外处理
4. 排查方法：iOS 设置 → 辅助功能 → 显示与文字大小 → 更大字体 → 拖到最大，检查所有广告 UI

## 排查清单

新增 UI 组件时，对照检查：

- [ ] 是否使用了 `UIButton.Configuration`？如是，是否设置了 `maximumContentSizeCategory`？
- [ ] 按钮/标签是否有固定尺寸约束？如是，确认字体缩放后不会溢出
- [ ] 在辅助功能大字体模式下测试过 UI 展示吗？

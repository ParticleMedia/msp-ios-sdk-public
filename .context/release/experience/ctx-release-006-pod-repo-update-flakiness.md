---
id: ctx-release-006
title: "pod repo update + pod search 不稳定导致发布验证误报"
domain: release
layer: experience
tags:
  - pod-repo-update
  - pod-search
  - cocoapods-cdn
  - availability-check
  - flakiness
  - cdn-direct-check
triggers:
  - "pod repo update flakiness in CI"
  - "pod search returns not found after trunk push"
  - "availability check false negative"
  - "CDN direct check replaces pod repo update"
  - "cocoapods cdn url check"
summary: "pod repo update + pod search 在 CI 中不稳定且耗时；改用直接查询 CocoaPods CDN HTTP API 解决"
version: "1.0"
status: active
created: "2026-04-16"
updated: "2026-04-16"
---

# ctx-release-006: pod repo update + pod search 不稳定

## 问题现象

CocoaPods `pod repo update` 命令在 CI 环境下平均耗时 3–5 分钟，且偶发失败：

- 本地 spec repo mirror 与 CDN 存在延迟，导致刚发布的版本查不到
- `pod search MSPCore X.Y.Z` 即使版本已在 CDN 上也可能返回 `[!] Unable to find a pod with name...`
- 导致发布脚本误判为"发布失败"，人工重试浪费大量时间

## 根本原因

`pod repo update` 更新的是**本地 spec repo 镜像**（`~/.cocoapods/repos/trunk`），
不等于 CocoaPods CDN 已经可用。两者同步有时差，且本地 mirror 同步本身就可能超时。

## 解决方案

改为直接查询 CocoaPods CDN HTTP API：

```
GET https://cdn.cocoapods.org/Specs/<h0>/<h1>/<h2>/<Pod>/<Ver>/<Pod>.podspec.json
```

其中 `h0/h1/h2` = `md5(pod_name)` 的前三个十六进制字符。
HTTP 200 = 已发布；HTTP 404 = 尚未传播；网络错误 = 可重试。

**关键参数**：3次重试（指数退避 1s→2s→4s），单次请求超时 10s。

## 实现位置

- `Scripts/lib/shared/cocoapods_cdn.sh` — CDN 检查模块
- `Scripts/lib/cocoapods.sh::check_pod_availability` — 委托给 CDN 模块
- `Scripts/release/utils/podspec.sh::smart_wait_for_pod_availability` — Stage1: 15s间隔, Stage2: 30s间隔

## 教训

> **不要用 `pod repo update` + `pod search` 做发布后可用性验证**。
> 本地 spec repo 镜像与 CDN 的同步延迟是不可控的，直接 HTTP 查询 CDN 才是 SSOT。

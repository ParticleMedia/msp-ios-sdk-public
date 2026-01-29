---
name: 发布系统
id: release
description: 与 SDK 发布流程相关的经验，包括 Pod 发布、版本管理、发布后集成问题
keywords: [release, pod, podspec, xcframework, 发布, 版本, publish, trunk]
---

# 发布系统

## 描述

本领域涵盖所有与 MSP SDK 发布流程相关的经验教训，包括但不限于：
- CocoaPods 发布 (pod trunk push)
- XCFramework 构建和打包
- 版本号管理
- 发布后使用方集成问题

## 适用范围

以下类型的问题属于此领域：
- Pod 发布失败
- 发布后使用方编译/链接错误
- 发布后使用方启动 crash
- 版本兼容性问题
- podspec 配置问题

## 触发关键词

以下关键词出现在用户问题中时，应自动检索此领域的上下文：
- release
- pod
- podspec
- publish
- trunk
- xcframework
- 发布
- 版本

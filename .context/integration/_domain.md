---
name: 集成兼容
id: integration
description: 与第三方 SDK 集成和兼容性相关的经验，包括编译链接问题、crash
keywords: [integration, 集成, crash, 编译, compile, linker, 链接, static, dynamic]
---

# 集成兼容

## 描述

本领域涵盖所有与第三方 SDK 集成和兼容性相关的经验教训，包括但不限于：
- 第三方 SDK 集成问题
- 静态库/动态库冲突
- 编译错误和链接错误
- 运行时 crash
- 符号冲突

## 适用范围

以下类型的问题属于此领域：
- 使用方集成时编译失败
- 链接器错误 (duplicate symbol, undefined symbol)
- 运行时 crash
- 第三方 SDK 版本冲突
- Framework 依赖问题

## 触发关键词

以下关键词出现在用户问题中时，应自动检索此领域的上下文：
- integration
- 集成
- crash
- 编译
- compile
- linker
- 链接
- static
- dynamic
- duplicate symbol

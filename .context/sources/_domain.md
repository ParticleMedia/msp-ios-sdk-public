---
name: Sources 业务逻辑
id: sources
description: Swift 源码业务逻辑实现相关的经验，包括 MVVM、Repository、网络层等
keywords: [sources, mvvm, viewmodel, repository, swift, ios, adapter, network, bidloader]
---

# Sources 业务逻辑

## 描述

本领域涵盖所有与 MSP SDK Swift 源码业务逻辑实现相关的经验教训，包括但不限于：
- MVVM 架构实现
- ViewModel 和 Repository 模式
- 网络层设计（BidLoader, AdAdapter）
- 业务状态管理
- 数据流和响应式编程

## 适用范围

以下类型的问题属于此领域：
- ViewModel 逻辑错误
- Repository 数据访问问题
- 广告加载和展示逻辑
- 状态管理和生命周期
- Swift 业务代码 bug

## 触发关键词

以下关键词出现在用户问题中时，应自动检索此领域的上下文：
- sources
- mvvm
- viewmodel
- repository
- swift
- ios
- adapter
- network
- bidloader
- 业务逻辑
- 广告加载

## 说明

**Phase 2 领域** - 当前为占位目录，后续会填充 Sources/ 业务逻辑相关的上下文。

可通过以下方式添加此领域的上下文：
1. 使用 `/context.add` 手动添加，选择 domain=sources
2. 使用 `./Scripts/context/init-context.sh` 从包含 `fix(sources):` 的 commit 提取

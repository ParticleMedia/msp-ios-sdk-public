---
name: 测试策略
id: testing
description: 单元测试、集成测试、测试策略相关的经验
keywords: [testing, 测试, quick, nimble, mock, stub, 单元测试, unit test, integration test]
---

# 测试策略

## 描述

本领域涵盖所有与测试相关的经验教训，包括但不限于：
- Quick/Nimble 单元测试
- Mock 和 Stub 策略
- 测试金字塔实践
- 集成测试设计
- 测试工具和框架使用
- 可测试性设计

## 适用范围

以下类型的问题属于此领域：
- 单元测试编写
- Mock 对象设计
- 测试覆盖率提升
- 测试失败调试
- 测试框架使用
- 可测试性重构

## 触发关键词

以下关键词出现在用户问题中时，应自动检索此领域的上下文：
- testing
- 测试
- quick
- nimble
- mock
- stub
- 单元测试
- unit test
- integration test
- spec
- test failure

## 说明

**Phase 2 领域** - 当前为占位目录，后续会填充测试策略相关的上下文。

可通过以下方式添加此领域的上下文：
1. 使用 `/context.add` 手动添加，选择 domain=testing
2. 使用 `./Scripts/context/init-context.sh` 从包含 `fix(test):` 的 commit 提取

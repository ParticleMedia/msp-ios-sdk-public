---
id: ctx-release-002
title: Pod trunk push 失败但脚本显示成功 - 退出码捕获错误
layer: experience
domain: release
tags: [pod, trunk-push, shell, exit-code, PIPESTATUS, tee]
created: 2026-01-29
source: commit:d332b5b2
status: active
confidence: high
---

# Pod trunk push 失败但脚本显示成功 - 退出码捕获错误

## 问题描述

在 CI/CD 中执行 pod trunk push 时，遇到奇怪的现象：

**症状**：
- `pod trunk push` 实际执行失败（validation 不通过）
- 但 release 脚本显示"发布成功"
- CI 构建标记为绿色（成功）
- CocoaPods 仓库中没有新版本

**触发条件**：
- 使用 shell 脚本自动化 `pod trunk push` 流程
- 使用 `tee` 命令同时捕获输出和显示到终端
- 检查 `$?` 来判断命令是否成功

## 根因分析

问题出在 **Shell pipeline 的退出码处理**：

### 错误的实现

```bash
# ❌ 错误：$? 是 tee 的退出码，不是 pod trunk push 的
pod trunk push MyPod.podspec 2>&1 | tee output.log
if [ $? -eq 0 ]; then
    echo "发布成功"  # 即使 pod 失败，tee 成功也会进这里
fi
```

### 为什么会这样？

在 Shell pipeline 中：
```bash
command1 | command2 | command3
```

- `$?` 返回的是**最后一个命令**的退出码（这里是 `command3`）
- `tee` 命令几乎总是成功（除非磁盘满）
- 即使 `pod trunk push` 返回非零退出码，`tee` 的成功会覆盖它

**实际发生的流程**：
```
pod trunk push  →  退出码 1（失败）
        ↓
      pipe
        ↓
     tee        →  退出码 0（成功，因为成功写入了日志）
        ↓
      $? = 0   →  脚本判断为成功 ❌
```

### Bash 的 PIPESTATUS 机制

Bash 提供了 `PIPESTATUS` 数组来获取 pipeline 中每个命令的退出码：

```bash
cmd1 | cmd2 | cmd3
# PIPESTATUS[0] = cmd1 的退出码
# PIPESTATUS[1] = cmd2 的退出码
# PIPESTATUS[2] = cmd3 的退出码
# $? = cmd3 的退出码（等同于 PIPESTATUS[2]）
```

## 解决方案

### 正确的实现

```bash
# ✅ 正确：使用 PIPESTATUS[0] 获取第一个命令的退出码
pod trunk push MyPod.podspec 2>&1 | tee output.log
POD_EXIT_CODE=${PIPESTATUS[0]}  # 必须紧跟 pipeline 后面

if [ $POD_EXIT_CODE -eq 0 ]; then
    echo "发布成功"
else
    echo "发布失败，退出码: $POD_EXIT_CODE"
    exit 1
fi
```

### 关键要点

1. **立即保存 PIPESTATUS**
   ```bash
   command | tee output.log
   EXIT_CODE=${PIPESTATUS[0]}  # ✅ 紧跟在 pipeline 后

   # ❌ 错误：中间执行了其他命令
   command | tee output.log
   echo "Some message"
   EXIT_CODE=${PIPESTATUS[0]}  # PIPESTATUS 已被覆盖！
   ```

2. **使用 trap 确保清理**
   ```bash
   TEMP_FILE=$(mktemp)
   trap "rm -f $TEMP_FILE" EXIT  # 无论如何退出都清理

   pod trunk push | tee $TEMP_FILE
   POD_EXIT_CODE=${PIPESTATUS[0]}
   ```

3. **保留失败日志用于调试**
   ```bash
   if [ $POD_EXIT_CODE -ne 0 ]; then
       echo "失败日志保存在: $TEMP_FILE"
       trap - EXIT  # 取消自动清理，保留日志
       exit 1
   fi
   ```

### 完整示例

```bash
#!/usr/bin/env bash
set -euo pipefail

TEMP_OUTPUT=$(mktemp)
trap "rm -f $TEMP_OUTPUT" EXIT

echo "开始发布 Pod..."

# 执行 pod trunk push 并捕获输出
pod trunk push MyPod.podspec --allow-warnings 2>&1 | tee "$TEMP_OUTPUT"

# 立即保存退出码
POD_EXIT_CODE=${PIPESTATUS[0]}

if [ $POD_EXIT_CODE -eq 0 ]; then
    echo "✅ Pod 发布成功"
    rm -f "$TEMP_OUTPUT"
    exit 0
else
    echo "❌ Pod 发布失败（退出码: $POD_EXIT_CODE）"
    echo "详细日志: $TEMP_OUTPUT"
    trap - EXIT  # 保留日志文件
    exit 1
fi
```

## 适用场景

这个问题和解决方案适用于：

1. **Pipeline 中的关键命令**
   - 任何通过 pipe 传递输出的命令
   - 需要正确判断第一个命令是否成功

2. **CI/CD 自动化**
   - 自动化发布脚本
   - 需要准确报告构建状态

3. **日志捕获场景**
   - 使用 `tee` 同时显示和保存输出
   - 使用 `grep`、`awk`、`sed` 处理输出

4. **常见的错误模式**
   ```bash
   # ❌ 都会遇到相同的问题
   important_command | tee log.txt
   critical_check | grep "SUCCESS"
   deploy_app | awk '{print $1}'
   ```

**关键词**：pod trunk push, exit code, PIPESTATUS, tee, shell pipeline, CI/CD

## 相关资源

- 相关 commit: d332b5b2
- 相关文件: `Scripts/release/utils/podspec.sh`
- Bash 手册: `man bash` 搜索 PIPESTATUS
- 相关概念: Shell pipeline, exit status, command substitution

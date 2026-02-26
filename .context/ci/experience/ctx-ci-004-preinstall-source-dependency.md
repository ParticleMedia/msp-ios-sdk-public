---
id: ctx-ci-004
title: "Podfile pre_install hook 中构建脚本依赖未就绪的源码目录"
domain: ci
layer: experience
tags:
  - cocoapods
  - pre-install-hook
  - xcodegen
  - chicken-egg
  - gitignore
  - prepare-command
triggers:
  - "XcodeGen missing source directory in CI"
  - "pre_install hook depends on prepare_command directory"
  - "pod install fails in CI but works locally"
  - "chicken-egg source directory dependency"
summary: "pre_install hook fails in CI because gitignored source dir is created by prepare_command after hook runs"
version: "1.0"
status: active
created: "2026-01-30"
updated: "2026-02-22"
---

# Podfile pre_install hook 中构建脚本依赖未就绪的源码目录

## 问题描述

`pod install` 在 CI 环境失败，XcodeGen 报错找不到源码目录。

**症状**:
- XcodeGen 报错：`Spec validation error: Target "XXX" has a missing source directory`
- 错误发生在 pre_install hook 执行的构建脚本中
- 本地环境正常，CI 环境失败

**错误示例**:
```
Spec validation error: Target "Kingfisher" has a missing source directory
"/Users/runner/work/msp-ios-sdk/msp-ios-sdk/ThirdParty/MSPKingfisher/Sources"
```

**触发条件**:
- Podfile 有 pre_install hook 调用构建脚本
- 构建脚本依赖某个源码目录
- 该源码目录被 gitignore
- 该源码目录由 pod 的 `prepare_command` 创建

## 根因分析

**Chicken-and-egg 问题**：构建脚本需要的源码在 pod install 完成前不存在。

**执行顺序**:
```
1. pod install 开始
2. pre_install hook 执行
   └── 调用 build-thirdparty.sh
       └── XcodeGen 生成项目
           └── 验证源码路径 → ❌ 失败（路径不存在）
3. pod install 下载 pods（未执行到）
4. prepare_command 创建源码目录（未执行到）
5. post_install hook 执行（未执行到）
```

**关键点**:
- `prepare_command` 在 pod **下载后**执行，不是在 pre_install 时
- gitignore 的目录不会被 git checkout，CI 环境没有这些目录
- 本地环境因为之前运行过 pod install，目录已存在

**本例中的情况**:

| 组件 | 说明 |
|-----|------|
| `ThirdParty/MSPKingfisher/Sources/` | 被 gitignore |
| `MSPKingfisher.podspec` 的 `prepare_command` | 从 GitHub 克隆源码到 Sources/ |
| `build-thirdparty.sh` | 在 pre_install 中被调用 |
| `project.yml.template` | 引用 `ThirdParty/MSPKingfisher/Sources` |

## 解决方案

### 方案 1: 从构建目标中移除（推荐）

如果该模块不是必须构建的，直接从构建列表中移除：

```bash
# build-thirdparty.sh
THIRDPARTY_TARGETS=(
    "SwiftProtobuf:SwiftProtobuf"
    "MSPSnapKit:MSPSnapKit"
    "Lottie:Lottie"
    # "Kingfisher:Kingfisher" - 移除：MSPKingfisher/Sources 在 pre_install 时不存在
)
```

同时从 XcodeGen 模板中移除对应的 target 和 scheme。

**适用条件**:
- 该模块有替代方案（如官方 pod、预构建 XCFramework）
- 不是 pre_install hook 必须检查的 XCFramework

### 方案 2: 将源码提交到 git

从 gitignore 中移除该目录，将源码直接提交：

```gitignore
# .gitignore
# ThirdParty/MSPKingfisher/Sources/  # 注释掉这行
```

**注意**:
- 需要维护源码与上游同步
- 仓库体积会增加
- 适合源码稳定、不常更新的情况

### 方案 3: 在构建脚本中手动执行 prepare_command

在 XcodeGen 之前，先执行源码准备：

```bash
# build-thirdparty.sh
prepare_mspkingfisher_sources() {
    local sources_dir="$ROOT_DIR/ThirdParty/MSPKingfisher/Sources"
    if [[ ! -d "$sources_dir" ]]; then
        log_info "Preparing MSPKingfisher sources..."
        git clone --depth 1 --branch 8.6.2 \
            https://github.com/onevcat/Kingfisher.git /tmp/kingfisher
        cp -R /tmp/kingfisher/Sources "$sources_dir"
        rm -rf /tmp/kingfisher
    fi
}

# 在 XcodeGen 之前调用
prepare_mspkingfisher_sources
```

**注意**:
- 增加了构建时间（需要 git clone）
- 需要网络访问
- 需要保持版本同步

### 方案 4: 条件性跳过缺失的目标

修改构建脚本，检测源码是否存在，不存在则跳过：

```bash
for target_spec in "${THIRDPARTY_TARGETS[@]}"; do
    IFS=':' read -r scheme_name output_name <<< "$target_spec"

    # 检查源码是否存在
    if ! check_sources_exist "$scheme_name"; then
        log_warn "Skipping $scheme_name: sources not available"
        continue
    fi

    build_single_xcframework "$scheme_name" "$output_name"
done
```

## 诊断方法

1. **确认错误位置**:
   ```bash
   # 查看完整错误
   pod install --verbose 2>&1 | grep -A5 "Spec validation error"
   ```

2. **检查目录是否被 gitignore**:
   ```bash
   git check-ignore -v ThirdParty/MSPKingfisher/Sources/
   # 如果输出 .gitignore:XX，说明被忽略
   ```

3. **检查 podspec 的 prepare_command**:
   ```bash
   grep -A10 "prepare_command" ThirdParty/MSPKingfisher/MSPKingfisher.podspec
   ```

4. **确认本地目录存在**:
   ```bash
   ls -la ThirdParty/MSPKingfisher/Sources/
   # 本地存在但 CI 不存在 → chicken-and-egg 问题
   ```

## 预防措施

1. **pre_install hook 中的构建脚本应该**:
   - 只依赖已提交到 git 的文件
   - 或者在依赖不存在时优雅跳过
   - 不要依赖 prepare_command 创建的目录

2. **gitignore 源码目录时**:
   - 确保没有 pre_install 脚本依赖这些目录
   - 或者在脚本中实现自动准备逻辑

3. **CI 与本地环境差异**:
   - 本地可能有历史遗留的目录
   - CI 是干净的 checkout，只有 git 跟踪的文件
   - 测试时可以用 `git clean -fdx` 模拟 CI 环境

## 适用场景

- CocoaPods + XcodeGen 组合
- pre_install hook 执行构建或验证脚本
- 源码目录被 gitignore 且由 prepare_command 创建
- CI 环境与本地环境行为不一致

**关键词**: `pre_install`, `prepare_command`, `gitignore`, `XcodeGen`, `missing source directory`, `chicken-egg`

## 相关资源

- 相关 commit: f40e4c7b (fix(ci): remove Kingfisher from build-thirdparty.sh)
- 相关文件:
  - `Scripts/xcframeworks/build-thirdparty.sh`
  - `Examples/ThirdPartyFrameworks/project.yml.template`
  - `ThirdParty/MSPKingfisher/MSPKingfisher.podspec`
  - `.gitignore`
- CocoaPods 文档: [prepare_command](https://guides.cocoapods.org/syntax/podspec.html#prepare_command)

## 关联 Playbooks

| Playbook | 关系 |
|----------|------|
| [ctx-sources-004](../../sources/tech/ctx-sources-004-script-best-practices.md) | 上游 — 脚本执行时序和依赖管理原则 |
| [ctx-release-002](../../release/experience/ctx-release-002.md) | 同类 — Shell 管道 exit code 问题（另一种 CI 脚本陷阱） |

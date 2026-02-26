# Context Index

> **Last Updated**: 2026-02-16
> **Total Entries**: 10

## By Layer

### Business (0)
业务知识：产品需求、业务规则、用户场景

### Experience (9)
经验教训：调试过程、踩坑记录、解决方案

### Tech (1)
技术知识：API 用法、架构设计、设计模式

## By Domain

### Release (3)
| ID | Title | Layer | Tags | Created | Status |
|----|-------|-------|------|---------|--------|
| ctx-release-001 | Pod 发布后使用方启动 crash - FB SDK 静态链接冲突 | experience | [facebook, static-linking, xcframework, crash, FBAdSettings, symbol-conflict] | 2026-01-29 | active |
| ctx-release-002 | Pod trunk push 失败但脚本显示成功 - 退出码捕获错误 | experience | [pod, trunk-push, shell, exit-code, PIPESTATUS, tee] | 2026-01-29 | active |
| ctx-release-003 | Pod 发布后使用方 crash - Kingfisher 静态链接重复 | experience | [kingfisher, static-linking, xcframework, crash, objc_retain, NovaCore, duplicate-symbol] | 2026-02-03 | active |

### CI (4)
| ID | Title | Layer | Tags | Created | Status |
|----|-------|-------|------|---------|--------|
| ctx-ci-001 | GitHub Actions Artifact 上传导致 XCFramework 结构丢失 | experience | [github-actions, artifact, xcframework, info-plist, v4] | 2026-01-29 | active |
| ctx-ci-002 | GitHub Actions Matrix 构建中 Artifact 名称冲突 | experience | [github-actions, matrix, artifact, overwrite, v4] | 2026-01-29 | active |
| ctx-ci-003 | 模块重复构建导致 Swift 编译器 ABI 冲突崩溃 | experience | [swift, abi-conflict, cocoapods, xcframework, compiler-crash, duplicate-build] | 2026-01-29 | active |
| ctx-ci-004 | Podfile pre_install hook 中构建脚本依赖未就绪的源码目录 | experience | [cocoapods, pre_install, xcodegen, prepare_command, chicken-egg, gitignore] | 2026-01-30 | active |

### Integration (2)
| ID | Title | Layer | Tags | Created | Status |
|----|-------|-------|------|---------|--------|
| ctx-integration-001 | NovaCore.xcframework 静态链接第三方库导致使用方 duplicate symbol crash | experience | [duplicate-symbol, xcframework, static-link, SnapKit, Kingfisher, Lottie, NovaCore, NovaAdapter] | 2026-02-15 | active |
| ctx-integration-002 | MSPFacebookAdapter mh_dylib + dynamic_lookup 导致 Release strip 后 flat namespace crash | experience | [facebook, FBAudienceNetwork, mh_dylib, dynamic_lookup, flat-namespace, staticlib, shim, linker, crash, strip] | 2026-02-16 | active |

### Compatibility (0)
| ID | Title | Layer | Tags | Created | Status |
|----|-------|-------|------|---------|--------|
| - | No entries yet | - | - | - | - |

### Testing (1)
| ID | Title | Layer | Tags | Created | Status |
|----|-------|-------|------|---------|--------|
| ctx-testing-001 | Test Doubles Strategy - Stub, Mock, Fake | tech | [test-double, mock, stub, fake, unit-test, quick, nimble, stub-factory, test-case, tdd] | 2026-02-02 | active |

### Sources (0)
| ID | Title | Layer | Tags | Created | Status |
|----|-------|-------|------|---------|--------|
| - | No entries yet | - | - | - | - |

### Architecture (0)
| ID | Title | Layer | Tags | Created | Status |
|----|-------|-------|------|---------|--------|
| - | No entries yet | - | - | - | - |

## Recent Updates

| ID | Title | Updated | Change |
|----|-------|---------|--------|
| - | Run with --rebuild to regenerate | - | - |

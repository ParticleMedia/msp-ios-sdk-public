# Context System Rules

When user questions involve keywords: release, pod, crash, CI, build, integration, compile, linker, compatibility, migration, test, mock, stub:
1. Search `.context/index.json` for relevant entries by matching keywords against `tags` and `triggers` fields
2. Load matched entries on demand
3. Reference found context in responses: "根据 [ctx-xxx] 的经验..."

When debugging is complete (3+ rounds, root cause found, domain matches):
- Suggest saving as context: "运行 `/context.add` 开始记录"

Keyword-to-Domain Mapping:

| Keywords | Domain |
|----------|--------|
| release, pod, podspec, xcframework, 发布, 版本, publish, trunk | `release` |
| ci, cd, build, 构建, github actions, workflow | `ci` |
| integration, 集成, crash, 编译, compile, linker, link | `integration` |
| compatibility, 兼容, migration, 升级, deprecate | `compatibility` |
| test, TDD, unit test, Quick, Nimble, mock, stub | `testing` |

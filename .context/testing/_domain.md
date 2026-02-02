---
name: Testing Strategy
id: testing
description: Unit testing, integration testing, and testing strategy experiences
keywords: [testing, 测试, quick, nimble, mock, stub, fake, stub-factory, test-case, tdd, 单元测试, unit test, 集成测试, integration test]
---

# Testing Strategy

## Description

This domain covers all testing-related experiences, including:
- Quick/Nimble unit testing
- Stub/Mock/Fake 3-layer strategy
- Test pyramid practices
- Integration test design
- Testing tools and frameworks
- Testability design

## Scope

The following types of issues belong to this domain:
- Writing unit tests
- Stub data management
- Mock/Fake class design
- Test coverage improvement
- Test failure debugging
- Testing framework usage
- Testability refactoring

## Trigger Keywords

Auto-search this domain when user questions contain:
- testing
- quick / nimble
- mock / stub / fake
- stub-factory
- unit test
- integration test
- spec
- test failure

## Context Entries

### Tech Layer

| ID | Title | Confidence |
|----|-------|------------|
| [ctx-testing-001](tech/ctx-testing-001-test-doubles.md) | Stub/Mock/Fake 3-Layer Strategy | high |

## Notes

Add context to this domain via:
1. Use `/context.add` manually, select domain=testing
2. Use `./Scripts/context/init-context.sh` to extract from commits containing `fix(test):`

# Sources Loading Guide

> **Version**: 2.0 | **Scope**: Sources/ directory
> **Applies To**: All AI Agents working in Sources/

When working in Sources/, load these playbooks from `.context/index.json`:

| Playbook ID | Topic | When |
|-------------|-------|------|
| ctx-sources-001 | Swift Best Practices | Always when writing Swift |
| ctx-sources-002 | UIKit Best Practices | When working with views/VCs |
| ctx-sources-003 | MVVM-Repo Pattern | When implementing features |
| ctx-sources-005 | Code Comment Best Practices | Always when writing Swift |
| ctx-testing-001 | Unit Test (Quick/Nimble) | When writing tests |
| ctx-testing-002 | BDD Best Practices | When writing test specs |

**Architecture**: MVVM-Repository (View → ViewModel → Repository → DataSource)
**State Constitution**: `Sources/constitution.md` (Articles IV-V)

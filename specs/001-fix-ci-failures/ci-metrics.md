# CI Refactor Metrics

Date: 2026-01-27
Source: git diff --numstat .github/workflows/ci-pull-request.yml

- Lines added: 138
- Lines removed: 436
- Net change: -298

Notes:
- Removal count reflects inline shell logic replaced by script calls and config-driven matrices.
- Counts are based on the current working diff against the branch baseline.

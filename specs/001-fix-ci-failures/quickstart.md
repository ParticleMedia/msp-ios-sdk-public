# Quickstart: Restore CI Stability

## Goal
Validate that CI passes for valid PRs and reports actionable failures when something is wrong.

## Prerequisites
- Access to the repository and CI system
- Ability to open a test PR

## Steps
1. Create a small, safe PR (e.g., doc-only change) and open it.
2. Confirm all required CI jobs run and complete successfully.
3. Create a temporary test failure (e.g., a failing test) and open a PR.
4. Confirm CI marks a single failing job with a clear failure reason.

## Expected Results
- Valid PRs complete all required CI checks without manual retries.
- Failures show a clear, actionable error message tied to the failing job.

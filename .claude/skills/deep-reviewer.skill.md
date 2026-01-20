---
name: deep-reviewer
description: Comprehensive code review with constitutional audit, architectural analysis, and design quality assessment
category: strategic
shared: false
applicable_agents: [claude-code]
required_model: opus
allowed-tools: [Read, Glob, Grep]
---

# Deep Reviewer Skill

> **Type**: Strategic Skill
> **Exclusive**: Claude Code (Opus) only
> **Purpose**: Multi-dimensional code review requiring deep reasoning

---

## Purpose

Perform comprehensive, multi-layered code reviews that assess:
1. **Constitutional Compliance**: Does code follow project constitution?
2. **Architectural Alignment**: Does code fit system design?
3. **Design Quality**: Is code well-designed and maintainable?
4. **Security & Performance**: Are there vulnerabilities or bottlenecks?
5. **Testing**: Is test coverage adequate?

**Task Tier**: Tier 3 (Strategic) - Requires deep analysis and judgment

---

## Scope

**Does**:
- Multi-dimensional code analysis
- Constitutional compliance verification
- Architectural impact assessment
- Design pattern evaluation
- Security and performance review
- Test coverage analysis
- Strategic recommendations

**Does NOT**:
- Simple style checks (use linter)
- Mechanical fixes (use quick-fix.skill.md)
- Trivial reviews (use constitutional-auditor.skill.md for simple audits)

---

## When to Use

Invoke this skill when:
- Reviewing complex pull requests (>500 lines or >5 files)
- Reviewing public API changes
- Assessing architectural changes
- Pre-merge review of critical features
- Security-sensitive changes
- Performance-critical changes
- Major refactorings

**Quick Decision**:
- Simple PR, style issues → Basic review or linter
- Tier 1-2 changes → constitutional-auditor.skill.md
- Tier 3 changes, architectural impact → deep-reviewer.skill.md

---

## Review Dimensions

### Dimension 1: Constitutional Compliance

**Federal Constitution** (`constitution.md`):
- Article I: Automation over manual processes
- Article II: Validation gates enforced
- Article III: Modularity and isolation

**Domain Constitutions**:
- `Sources/constitution.md`: Swift code quality
- `Scripts/constitution.md`: Shell script requirements
- `Tests/constitution.md`: Test quality standards

**Output**: Compliance report with violations and suggested fixes

---

### Dimension 2: Architectural Alignment

**Questions to Answer**:
- Does this fit the existing architecture?
- Are module boundaries respected?
- Are dependencies appropriate?
- Is abstraction level correct?
- Does this introduce coupling?

**Reference**: `ARCHITECTURE.md`

**Output**: Architectural assessment with alignment score

---

### Dimension 3: Design Quality

**Assess**:

**Code Structure**:
- [ ] Clear separation of concerns
- [ ] Appropriate abstraction levels
- [ ] No code duplication (DRY)
- [ ] Single Responsibility Principle
- [ ] Open/Closed Principle

**Naming**:
- [ ] Clear, descriptive names
- [ ] Consistent terminology
- [ ] No abbreviations (unless standard)
- [ ] Swift naming conventions followed

**Error Handling**:
- [ ] All errors handled appropriately
- [ ] No force unwraps without justification
- [ ] Proper use of Result/Optional types
- [ ] Error messages are actionable

**Maintainability**:
- [ ] Code is readable
- [ ] Logic is straightforward
- [ ] No premature optimization
- [ ] Comments explain "why", not "what"

**Output**: Design quality assessment with improvement suggestions

---

### Dimension 4: Security Analysis

**Check For**:

**Common Vulnerabilities**:
- [ ] No hardcoded credentials/secrets
- [ ] Input validation on boundaries
- [ ] No SQL/command injection risks
- [ ] Proper authentication/authorization
- [ ] Sensitive data encryption
- [ ] No insecure random number generation

**Data Handling**:
- [ ] User data properly anonymized
- [ ] No sensitive data in logs
- [ ] Secure data transmission
- [ ] Proper memory cleanup for sensitive data

**Third-Party Dependencies**:
- [ ] Dependencies are vetted
- [ ] Version pinning for security
- [ ] No known vulnerabilities

**Output**: Security assessment with risk level and mitigations

---

### Dimension 5: Performance Analysis

**Assess**:

**Algorithmic Complexity**:
- [ ] No O(n²) where O(n) possible
- [ ] Appropriate data structures used
- [ ] No unnecessary iterations

**Resource Usage**:
- [ ] Memory usage reasonable
- [ ] No memory leaks
- [ ] Proper resource cleanup
- [ ] No retain cycles

**Concurrency**:
- [ ] Thread-safe where needed
- [ ] No race conditions
- [ ] Appropriate use of async/await
- [ ] Main thread not blocked

**Network**:
- [ ] Efficient API calls
- [ ] Proper timeouts
- [ ] Retry logic where appropriate
- [ ] Caching strategy sound

**Output**: Performance assessment with optimization recommendations

---

### Dimension 6: Testing Analysis

**Assess**:

**Coverage**:
- [ ] Public methods tested
- [ ] Edge cases covered
- [ ] Error paths tested
- [ ] Integration points tested

**Quality**:
- [ ] Tests are deterministic
- [ ] Tests are isolated
- [ ] Test names are descriptive
- [ ] Mocks/stubs appropriate
- [ ] BDD structure followed (describe-context-it)

**Maintainability**:
- [ ] Tests are readable
- [ ] No test duplication
- [ ] Setup/teardown clear
- [ ] Test data meaningful

**Output**: Test assessment with coverage gaps and improvements

---

## Execution Steps

### Step 1: Context Gathering

**Read Change Diff**:
```bash
git diff main...feature-branch
```

**Read Modified Files**:
```bash
# For each changed file
cat Sources/path/to/ChangedFile.swift
```

**Read Related Files**:
```bash
# Find related files
grep -r "ChangedClass" Sources/
```

**Read Constitutions**:
```bash
cat constitution.md
cat Sources/constitution.md  # if Swift changes
cat Scripts/constitution.md  # if script changes
```

**Read Architecture**:
```bash
cat ARCHITECTURE.md
```

---

### Step 2: Constitutional Review

Use **constitutional-auditor.skill.md** internally to check compliance.

For each applicable article:
1. State the requirement
2. Check if code complies
3. Note violations with location and suggested fix

---

### Step 3: Architectural Analysis

**Map Changes to Architecture**:
- Which modules are affected?
- Are module boundaries crossed?
- Are new dependencies introduced?
- Is layering preserved?

**Assess Fit**:
- Does change align with architecture?
- Does it introduce technical debt?
- Are there better architectural approaches?

---

### Step 4: Design Analysis

**Evaluate Structure**:
- Is code well-organized?
- Are responsibilities clear?
- Is complexity managed?

**Evaluate Patterns**:
- Are appropriate patterns used?
- Are patterns applied correctly?
- Is there over-engineering?

**Evaluate Naming**:
- Are names clear and consistent?
- Do names reveal intent?

---

### Step 5: Security Analysis

**Threat Model**:
- What are potential attack vectors?
- What sensitive data is handled?
- Are boundaries validated?

**Vulnerability Scan**:
- Check against OWASP Top 10
- Review authentication/authorization
- Check data encryption

---

### Step 6: Performance Analysis

**Algorithmic Review**:
- Analyze time/space complexity
- Identify bottlenecks
- Check for inefficiencies

**Resource Review**:
- Check for memory leaks
- Review retain cycles
- Assess resource management

---

### Step 7: Testing Review

**Coverage Check**:
```bash
# Run tests with coverage
swift test --enable-code-coverage

# Check coverage report
xcrun llvm-cov report
```

**Quality Check**:
- Read test files
- Assess test quality
- Identify gaps

---

### Step 8: Synthesize Findings

Categorize findings:
- **[Blocker]**: Must fix before merge
- **[Critical]**: Should fix before merge
- **[Suggestion]**: Nice to have
- **[Nitpick]**: Minor improvement
- **[Praise]**: Highlight good practices

---

### Step 9: Generate Report

Use output format below.

---

## Output Format

```markdown
# Deep Code Review Report

---
review_date: [YYYY-MM-DD]
reviewer: claude-code (opus-4-5)
commit_range: [hash1]...[hash2]
files_reviewed: [N]
lines_changed: +[X] -[Y]
---

## Executive Summary

**Overall Assessment**: [Approve | Approve with Changes | Request Changes | Reject]

**Key Findings**:
- [Blocker findings count] blockers
- [Critical findings count] critical issues
- [Suggestion count] suggestions

**Recommendation**: [One sentence recommendation]

---

## Detailed Findings

### [Blocker] Findings

Must be fixed before merge.

#### [B1] Constitutional Violation: Force Unwrap in Critical Path

**Location**: `Sources/Core/MSPCore/BidLoader.swift:142`

**Issue**:
```swift
let bid = response.bid!  // Crashes if nil
```

**Violated Article**: Sources/Article IV.3 - Avoid force unwraps

**Impact**: Runtime crash when ad network returns no-fill response

**Fix**:
```swift
guard let bid = response.bid else {
    delegate?.didReceiveNoFill()
    return
}
```

**Priority**: Critical - Blocks merge

---

#### [B2] Public API Breaking Change Without Deprecation

**Location**: `Sources/SDK/MSPiOSSDK/AdManager.swift:45`

**Issue**: Method signature changed without deprecating old signature

**Violated Article**: Federal/Article III - Maintain backwards compatibility

**Impact**: Breaks existing integrations

**Fix**:
```swift
// Keep old method, mark deprecated
@available(*, deprecated, message: "Use loadAd(with:completion:) instead")
public func loadAd(_ request: AdRequest) {
    loadAd(with: request, completion: nil)
}

// Add new method
public func loadAd(with request: AdRequest, completion: ((Result<Ad, Error>) -> Void)?) {
    // new implementation
}
```

**Priority**: Critical - Blocks merge

---

### [Critical] Findings

Should be fixed before merge, but not blocking.

#### [C1] Missing Error Handling

**Location**: `Sources/Core/MSPCore/NetworkClient.swift:67`

**Issue**: Network errors not propagated to caller

**Impact**: Silent failures, difficult debugging

**Fix**: Add proper error handling and logging

---

### [Suggestion] Findings

Improvements to consider.

#### [S1] Extract Duplicate Logic

**Location**: Multiple files

**Issue**: Bid validation logic duplicated in 3 places

**Improvement**: Extract to `BidValidator` utility class

**Benefit**: DRY, easier to maintain

---

### [Nitpick] Findings

Minor style/readability improvements.

#### [N1] Variable Naming

**Location**: `Sources/Core/MSPCore/BidLoader.swift:89`

**Current**: `let resp = ...`
**Suggested**: `let response = ...`

**Reason**: Avoid abbreviations for clarity

---

### [Praise] Good Practices

#### [P1] Excellent Test Coverage

**Location**: `Tests/MSPCoreTests/BidLoaderSpec.swift`

**Observation**: Comprehensive edge case testing, clear BDD structure

**Impact**: High confidence in code correctness

---

## Dimension-Specific Assessments

### Constitutional Compliance: ⚠️ 2 Violations

| Article | Status | Notes |
|---------|--------|-------|
| Federal I.1 | ✅ Pass | Automated via script |
| Federal III.1 | ✅ Pass | No third-party imports in Core |
| Sources IV.3 | ❌ Fail | Force unwrap on line 142 |

**Action Required**: Fix violations before merge

---

### Architectural Alignment: ✅ Good

**Assessment**: Changes align well with existing architecture

**Strengths**:
- Respects module boundaries
- Appropriate abstraction level
- No new coupling introduced

**Concerns**:
- None

---

### Design Quality: ⚠️ Moderate

**Score**: 7/10

**Strengths**:
- Clear naming
- Good separation of concerns
- Proper use of protocols

**Weaknesses**:
- Some code duplication
- One method too long (>50 lines)

**Recommendations**:
- Extract duplicate validation logic
- Break down `processResponse` method

---

### Security: ✅ Pass

**Risk Level**: Low

**Checks**:
- ✅ No hardcoded secrets
- ✅ Input validation present
- ✅ No SQL injection risks
- ✅ Proper data encryption

**Notes**: No security concerns identified

---

### Performance: ✅ Good

**Assessment**: No performance issues identified

**Algorithmic Complexity**: Appropriate
**Memory Usage**: Reasonable
**Concurrency**: Thread-safe

**Recommendations**: None

---

### Testing: ⚠️ Adequate

**Coverage**: 78% (target: 80%)

**Strengths**:
- Good happy path coverage
- Edge cases tested

**Gaps**:
- Error path for network timeout not tested
- Concurrent access scenario not tested

**Recommendation**: Add tests for:
1. Network timeout handling
2. Concurrent bid request scenario

---

## Summary Metrics

| Dimension | Score | Status |
|-----------|-------|--------|
| Constitutional | 6/8 | ⚠️ Violations present |
| Architectural | 9/10 | ✅ Good |
| Design | 7/10 | ⚠️ Moderate |
| Security | 10/10 | ✅ Pass |
| Performance | 9/10 | ✅ Good |
| Testing | 7/10 | ⚠️ Adequate |

**Overall**: 48/60 (80%)

---

## Recommendations

### Must Fix (Blockers)
1. Fix force unwrap (B1)
2. Add deprecation for API change (B2)

### Should Fix (Critical)
1. Add error handling (C1)

### Consider (Suggestions)
1. Extract duplicate validation logic (S1)
2. Improve test coverage to 80%+ (T1)

---

## Next Steps

1. **Author**: Address blocker findings
2. **Author**: Consider critical and suggestion findings
3. **Reviewer**: Re-review after fixes
4. **Team**: Approve and merge once blockers resolved

---

## Reviewer Notes

[Any additional context, concerns, or observations]

---

**Review Complete**
```

---

## Example Usage

### Review Complex Pull Request

```bash
$ claude
> Review PR #123 - Add caching layer to BidLoader

[Deep-reviewer skill activated]
[Performs 6-dimensional analysis]
[Produces comprehensive review report]
```

### Review Before Release

```bash
$ claude
> Perform deep review of all changes since last release

[Deep-reviewer skill activated]
[Analyzes all commits in range]
[Produces release readiness assessment]
```

---

## Review Principles

### Be Constructive

- **Do**: "Consider extracting this to improve testability"
- **Don't**: "This code is terrible"

### Be Specific

- **Do**: "Line 142: Force unwrap can crash if bid is nil"
- **Don't**: "Code has issues"

### Be Balanced

- Highlight good practices (Praise section)
- Don't only focus on negatives

### Be Actionable

- Provide concrete fix suggestions
- Link to relevant documentation
- Show code examples

---

## Tips for Effective Reviews

1. **Review in Layers**: Constitutional → Architectural → Design → Details
2. **Start High-Level**: Assess big picture before nitpicks
3. **Consider Context**: Understand the "why" behind changes
4. **Question Assumptions**: Don't assume intent
5. **Verify Claims**: Test locally if needed
6. **Time-Box**: Don't get stuck on minor issues

---

## Anti-Patterns to Avoid

### ❌ Nitpicking Without Context

```
Bad: "Use trailing closure syntax"
Good: "Consider trailing closure for consistency with codebase patterns"
```

### ❌ Blocking on Preferences

```
Bad: [Blocker] "Use my preferred pattern"
Good: [Suggestion] "Alternative pattern to consider: ..."
```

### ❌ Reviewing Without Understanding

```
Bad: Review without reading related code
Good: Understand context before forming judgment
```

---

## Constitutional Compliance

This skill enforces all constitutional articles systematically.

---

## Related Skills

- `constitutional-auditor.skill.md`: For focused compliance checks (used internally)
- `architect.skill.md`: For architectural decisions
- `sources-bug-analyst.skill.md`: For analyzing bugs found in review
- `quick-fix.skill.md`: For addressing trivial review findings

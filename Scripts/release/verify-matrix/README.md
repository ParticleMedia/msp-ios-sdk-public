# MSP Release Verification Matrix

This directory implements an automated test matrix for validating the MSP iOS
SDK release system.

## 🧪 What This Tests

Each test case evaluates:

- `DRY_RUN` mode
- `VERIFY_SPM_STRICT` behavior
- presence/absence of `SPM_REMOTE_URL`
- Pods-only / SPM-only configurations

## 📁 Directory Structure

```
verify-matrix/
├── generate_cases.sh     # auto-generates test cases
├── matrix.sh             # runs all test cases
├── cases/                # generated test-case scripts
└── logs/                 # per-case logs (auto-created)
```

## ▶️ How to Use

### Generate all cases

```
./generate_cases.sh
```

### Run full matrix

```
./matrix.sh
```

### Output

- `logs/*.log` — logs per case
- `summary.json` — machine-readable summary

## ⚙️ Adding New Dimensions

Use generate_cases.sh as the source of truth. Add your case definitions there.


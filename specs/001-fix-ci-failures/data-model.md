# Data Model: Restore CI Stability

## Entities

### CI Job
- **Purpose**: Represents a required pipeline task with a clear success/failure state.
- **Fields**:
  - **Name**: Human-readable job identifier.
  - **Status**: Success | Failure | Skipped.
  - **Failure Reason**: Short, actionable message when status is Failure.
  - **Run Duration**: Time from start to completion.
- **Validation Rules**:
  - Name must be non-empty and unique within a run.
  - Failure Reason must be present when Status = Failure.

### Repository Layout
- **Purpose**: The current file and directory structure CI relies on.
- **Fields**:
  - **Path**: Relative path to a file or directory used by CI.
  - **Type**: File | Directory | Script.
  - **Required**: Yes | No.
- **Validation Rules**:
  - Required paths must exist in the repository.

## Relationships

- **CI Job** references one or more **Repository Layout** paths required for execution.

## State Transitions

- **CI Job**: Pending → Running → Success | Failure | Skipped.

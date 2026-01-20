# Data Model: Fix Unit Test Builds

## Entities

### Test Target
- **Description**: A named unit test suite tied to a module or component.
- **Key Attributes**: name, associated module, build settings, enabled/disabled status.
- **Relationships**: depends on one or more Test Dependencies; uses a Build Configuration.

### Test Dependency
- **Description**: External libraries required to compile and run unit tests.
- **Key Attributes**: name, version, supported platform range, compatibility notes.
- **Relationships**: referenced by one or more Test Targets.

### Build Configuration
- **Description**: The build settings used to compile the demo app and test targets.
- **Key Attributes**: platform version, Swift language level, build flags, dependency integration settings.
- **Relationships**: shared by Test Targets and Demo App Build.

### Demo App Build
- **Description**: The build output produced when compiling the demo application target.
- **Key Attributes**: app target name, build scheme, build status.
- **Relationships**: uses a Build Configuration but must remain independent of Test Dependencies.

## Validation Rules
- Test Targets and Demo App Build must reference a compatible Build Configuration.
- Test Dependencies must declare platform compatibility that does not conflict with the Build Configuration.

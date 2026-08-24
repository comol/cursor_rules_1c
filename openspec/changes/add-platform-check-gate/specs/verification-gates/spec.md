# Delta for verification-gates

## ADDED Requirements

### Requirement: Platform batch-check gate

The verification chain MUST include a conditional gate that validates a changed configuration
with the platform itself, in addition to the static gates. The gate SHALL run when all of the
following hold: the change loaded BSL or metadata into a development infobase, `INFOBASE_PATH`
and `PLATFORM_PATH` resolve to a reachable infobase and platform, and the target is a
development or test infobase. A failure of the gate is blocking for the artifact. The gate
MUST NOT be presented as a replacement for the static gates.

#### Scenario: Extension change validated against a dev infobase

- GIVEN an extension was modified and loaded into the dev infobase
- WHEN the platform batch-check gate runs
- THEN module checks execute for that extension
- AND the extension applicability check executes for that extension
- AND a reported error blocks the artifact until it is fixed and a clean run is obtained

#### Scenario: Main configuration change validated against a dev infobase

- GIVEN the main configuration was modified and loaded into the dev infobase
- WHEN the platform batch-check gate runs
- THEN module checks execute for the main configuration
- AND the applicability check is not executed, because it applies only to extensions

#### Scenario: No infobase available

- GIVEN the gate trigger fired but `INFOBASE_PATH` or `PLATFORM_PATH` is empty or unreachable
- WHEN the change is delivered
- THEN the gate is not run and delivery is not blocked
- AND the delivery summary records one fixed line under Risks naming the gate and the reason
- AND the absence of the infobase MUST NOT be turned into a question outside an infobase-bound task

#### Scenario: Production infobase

- GIVEN the resolved infobase is not established as a development or test base
- WHEN the gate would run
- THEN the gate is skipped and the skip is recorded under Risks
- AND the agent MUST NOT run batch Designer operations against that infobase to satisfy the gate

### Requirement: Extension applicability verification

Any change that modifies a configuration extension MUST verify that the extension can still be
applied to the infobase, using the platform's applicability check, before the change is declared
complete. Static validation of extension XML and BSL does not satisfy this requirement.

#### Scenario: Interceptor targets a method that no longer exists

- GIVEN an extension method annotated for a base-configuration method that was renamed by the vendor
- WHEN the applicability check runs
- THEN the check reports the failure
- AND the gate fails even though the XML structure and the BSL syntax are valid

#### Scenario: Several extensions in the infobase

- GIVEN the infobase contains other extensions besides the changed one
- WHEN the applicability check runs without naming a single extension
- THEN every extension is checked in load order
- AND a failure caused by the interaction between extensions is reported rather than hidden

### Requirement: Three-signal verdict for batch Designer operations

A batch Designer operation SHALL be treated as successful only when all three signals agree: the
process exit code is zero, the value written by `/DumpResult` is zero, and the `/Out` log contains
no error diagnostics. Every batch invocation MUST request both `/Out` and `/DumpResult`. A zero
exit code alone MUST NOT be reported as success.

#### Scenario: Failure hidden behind a zero exit code

- GIVEN a batch operation exits with code 0
- AND its log contains a line reporting a missing method
- WHEN the verdict is computed
- THEN the operation is reported as failed
- AND the log path and the result path are preserved and reported

#### Scenario: Clean log containing the word "ошибок"

- GIVEN a log whose only relevant line reads that no errors were found
- WHEN the verdict is computed
- THEN the line is recognised as a success phrase before error patterns are applied
- AND the operation is reported as successful

#### Scenario: Operation times out

- GIVEN a batch operation does not finish within its timeout
- WHEN the verdict is computed
- THEN the operation is reported as failed rather than unknown
- AND the log path is preserved for diagnosis

### Requirement: Gate placement in infobase-bound commands

The infobase-bound commands that load a configuration MUST run the platform batch-check gate
between loading the configuration and updating the database structure. A failing gate SHALL abort
the sequence before the database structure update.

#### Scenario: Broken configuration never reaches restructuring

- GIVEN a configuration was loaded into the dev infobase
- AND the module check reports an error
- WHEN the deployment sequence continues
- THEN the database structure update is not started
- AND the failure is reported with the log fragment that caused it

#### Scenario: Retry discipline is unchanged

- GIVEN the gate failed and the cause was fixed
- WHEN the sequence is retried
- THEN it restarts from the configuration load step
- AND the existing retry limits and session-termination discipline apply unchanged

### Requirement: Check profiles, depth modulation, and warning policy

The gate SHALL expose a quick profile (module checks), an applicability profile (extensions only),
and a full profile (centralized configuration test). Which profiles run is governed by
`VERIFICATION_DEPTH`: `lite` runs the gate only on promotion-trigger changes, `standard` runs the
quick profile plus the applicability profile whenever an extension is touched, and `full`
additionally runs the full profile. Errors and applicability failures are blocking; warnings MUST
be reported without blocking. The retry budget is the one defined for the other verification gates:
one clean pass on the latest artifact state, with one confirmation run after a blocking fix at
`standard` and at most two at `full`.

#### Scenario: Default depth on an extension change

- GIVEN `VERIFICATION_DEPTH` is `standard`
- AND an extension was modified
- WHEN the gate runs
- THEN the quick profile and the applicability profile execute
- AND the full profile does not execute

#### Scenario: Warnings on a typical configuration

- GIVEN the full profile reports warnings and no errors
- WHEN the verdict is computed
- THEN the gate passes
- AND the warnings are summarised in the delivery report

#### Scenario: Repeated run without changes

- GIVEN the gate already produced a clean pass on the current artifact state
- WHEN no source was changed since that run
- THEN the gate MUST NOT be executed again

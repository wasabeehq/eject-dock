# Project working rules

EjectDock is a native macOS menu bar utility written in Swift and AppKit.
Read `docs/ROADMAP.md` and `docs/VALIDATION.md` before changing behavior.

## Safety and architecture

- Keep system discovery and operations outside menu construction.
- Keep pure decisions and injectable operation coordination in EjectDockCore.
- Fail closed for internal, system, unknown, or ambiguously identified media.
- Never persist a BSD name, display name, or mount path as a physical disk identity.
- Revalidate each target before requesting an operation.
- Physical targets are unmounted only. Do not call DADiskEject or require the
  hardware to disappear. Confirm no associated volumes or snapshots remain mounted.
- Never force an unmount, kill a blocking process, or stop a backup.
- A timeout is pending, never success. Confirm completion with the system.
- Do not test ejection on the user's backup drive without explicit permission.
- Use disposable disk images for automated native integration tests.

## Implementation

- Target macOS 13 or later and avoid dependencies without a concrete need.
- Keep the main thread responsive during discovery and system operations.
- Keep English and French resource keys synchronized.
- Persist preferences without dropping disconnected selections.
- Add meaningful tests for identity, eligibility, and operation state changes.
- Coordinate file ownership during parallel work and preserve others' edits.

## Validation and delivery

- Run `./scripts/test.sh` and `./scripts/archive.sh` after integration.
- Record performed checks separately from manual and unavailable checks.
- Never mark a roadmap item complete based only on implementation if it requires
  a runtime, hardware, distribution, or visual check.
- Keep source, comments, documentation, and repository messages in English.
- Never use the em dash character or automated attribution trailers/notices.
- Do not publish fabricated release URLs or checksums.
- Do not change Gatekeeper settings or expose signing credentials.

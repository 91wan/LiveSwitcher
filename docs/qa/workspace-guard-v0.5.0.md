# LiveSwitcher v0.5.0 Workspace Guard

The v0.5.0 release starts from a clean `main` checkout with `HEAD` equal to `origin/main`.

Before tagging:

- `git status --short` must be empty.
- `git rev-parse HEAD` must equal `git rev-parse origin/main`.
- `VERSION` must equal the tag name without the leading `v`.
- The tag must point at the same commit as `origin/main`.
- Existing release tags must not be moved.

The public artifact must come from the GitHub Release workflow, not a local zip uploaded by hand. The workflow packages `dist/LiveSwitcher.app`, verifies the extracted app bundle, and uploads both `LiveSwitcher-macOS-v0.5.0.zip` and `LiveSwitcher-macOS-v0.5.0.zip.sha256`.

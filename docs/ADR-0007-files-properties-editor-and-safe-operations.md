# ADR-0007: Files, Properties, Native Editor, and Safe Operations

- Status: Accepted
- Date: 2026-09-14
- Supersedes: ADR-0019, ADR-0020
- Related: ADR-0005, ADR-0008

## Context

Users need native file editing without unsafe live mutations.

## Decision

- File view supports tree, metadata, internal search, open, create, edit, save, and reload.
- Use STTextView, UTF-8, and atomic saves.
- External conflict offers Reload, Overwrite, or Cancel; silent overwrite is forbidden.
- Preserve unknown properties, comments, and order where possible.
- Managed-root-wide search and diff are initially out of scope.
- Reads may remain live. Delete, move, rename, import, compress, extract, and restore require stopped state, immediate revalidation, and no auto-restart.
- Failed mutation leaves the original file and cleans temporary files.
- Normal errors show reason and recovery; detailed paths and diagnostics require explicit redacted detail/copy.

## Consequences

The editor behaves like a native document editor while honoring server lifecycle safety.

## Verification

Atomic-save, conflict, encoding, permission, path, running-guard, and rollback tests pass.

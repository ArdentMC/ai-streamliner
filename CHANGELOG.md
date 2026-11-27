# Changelog
## [1.0.6] - 2026-11-27

### Changed
- Pinned kubectl, kustomize, helm and yq to explicit versions and verified the
  published checksums where upstream publishes them. Builds of the same source
  now produce the same image, which a marketplace scan can be attested against.
- Downloads select the build platform rather than naming amd64, so the arm64
  image in the multi-arch index no longer carries amd64 binaries.
- Installed helm from its release tarball instead of the apt repository at
  baltocdn.com, which presents a Let's Encrypt chain rooted in ISRG Root YR and
  cannot be verified by the ca-certificates in Ubuntu 22.04 or 24.04.
- Took the Central Dashboard source from kubeflow/dashboard. The components
  directory no longer exists in kubeflow/kubeflow.
- Copied only components/centraldashboard into the shipped image rather than
  the whole Kubeflow monorepo.

### Removed
- kind. It was present for local testing, is only ever invoked behind a
  command -v guard, and the Makefile targets that create a cluster run on a
  developer's machine.

### Security
- CVE-2023-44487, HTTP/2 rapid reset. Carried by the pinned kind v0.20.0 binary,
  which was built with the Go 1.20.4 standard library; the fix is in Go 1.20.10.
  Go tracks the flaw as CVE-2023-39325, which is the identifier a scan reports.
  Removing kind clears it, along with 31 further high and critical findings that
  the same binary carried.

## [1.0.0] - 2025-06-17

### Added
- Initial release

### Changed
- N/A

### Deprecated
- N/A

### Removed
- N/A

### Fixed
- N/A

### Security
- N/A
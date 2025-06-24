# Contributing to This Project

Thank you for your interest in contributing!

## How to Contribute

1. Fork the repository and create your branch from `main`.
2. Make your changes with clear, descriptive commit messages.
3. Ensure your code passes all existing tests and follows our style guide.
4. Open a pull request with a clear description of your changes.

## Bug Reports & Feature Requests

- Use [GitHub Issues](https://github.com/ArdentMC/ai-streamliner/issues) to report bugs or request features.
- Please include as much detail as possible and steps to reproduce (for bugs).

## Coding Style

- Follow the conventions used in the existing codebase.
- Add tests for new features or bug fixes.
- Document public methods and significant changes.

## Versioning and Release Workflow

This project uses Git tags and a `CHANGELOG.md` to track changes.

### How to Release a New Version

**Contributors:**  
- Please do **not** push directly to the `main` branch.
- Open pull requests against the `main` branch.
- If your change warrants a changelog entry (user-facing fix, feature, etc.), add it under an `[Unreleased]` section at the top of `CHANGELOG.md` in your PR.
- Maintainers will curate and finalize the changelog, bump the version, and tag releases on `main`.
    > **Note**  
    > Contributors: Please follow this workflow to ensure our versioning and changelog stay consistent and useful!

**Maintainers:**  
- When ready to release:
    1. **Update the Version**
        - Change the version number in the `VERSION` file (e.g., to `1.1.0`).
    2. **Update the Changelog**
        - Add a new section at the top of `CHANGELOG.md` for the new version.
        - Move `[Unreleased]` changes in `CHANGELOG.md` under a new version heading and add today's date.
        - Summarize the notable changes under appropriate headings (e.g., Added, Changed, Fixed).
    
    3. **Commit the Changes**
        ```sh
        git add VERSION CHANGELOG.md
        git commit -m "chore: release vX.Y.Z"
        git push origin main
        ```
    4. Tag the new version:  
        ```
        git tag vX.Y.Z
        git push origin vX.Y.Z
        ```

---

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md).  
By participating, you are expected to uphold this code.

---

Contributions to this project are licensed under the Apache License 2.0.


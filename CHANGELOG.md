# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and
the project intends to follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Initial package structure and ERT test runner.
- Detection of relevant ordinary active timestamps, including ranges and
  repeaters, while excluding inactive and planning timestamps.
- A `vulpea-auto-tag-rules`-compatible rule for adding or removing the
  configurable timestamp tag on save.
- A global mode that filters stale timestamp-only files from the paths supplied
  by `vulpea-agenda`, while preserving ordinary agenda files and files selected
  through other configured tags.  Filtering follows the requested agenda date
  interval and caches database queries and file inspections for one agenda run.

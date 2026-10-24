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
- Idempotent reindex and stale-tag cleanup commands with unsaved-buffer
  protection, normal save-hook/database updates, per-file error isolation, and
  completion counts.

### Removed

- Agenda-time filtering, advice, caching, and profiling.  Agenda construction
  now relies entirely on indexed tags and never parses candidate files.

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
- Idempotent reindex and stale-tag cleanup commands with unsaved-buffer
  protection, normal save-hook/database updates, per-file error isolation, and
  completion counts.
- Opt-in per-agenda profiling for database queries, filtering, unique file
  parsing, total runtime, cache behavior, and path elimination counts, with a
  report that guides before/after stale-cleanup measurements.
- Rolling relevance based on today and all future timestamps instead of the
  displayed agenda interval, plus caching of the complete filtered path result.
- A shared cache boundary around whole agenda commands and custom block series,
  preventing the preparation pass and individual blocks from reparsing the
  same timestamp candidate files.

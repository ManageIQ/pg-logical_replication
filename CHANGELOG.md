# Changelog

All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.2.0] - 2021-07-07
### Added
- Default the sub slot name to the sub name if create_slot false and no name given [[#10](https://github.com/ManageIQ/pg-logical_replication/pull/10)]
- Add support for symbol keyed options to create_subscription [[#10](https://github.com/ManageIQ/pg-logical_replication/pull/10)]
- Support removal of subscriptions created without a slot [[#10](https://github.com/ManageIQ/pg-logical_replication/pull/10)]

## [1.1.0] - 2021-06-29
### Added
- Support providing the db name to the subscriber? method [[#7](https://github.com/ManageIQ/pg-logical_replication/pull/7)]
- Add create replication slot [[#8](https://github.com/ManageIQ/pg-logical_replication/pull/8)]

### Changed
- Cache type maps for queries/results [[#6](https://github.com/ManageIQ/pg-logical_replication/pull/6)]

## [1.0.0] - 2019-05-08

[Unreleased]: https://github.com/ManageIQ/pg-logical_replication/compare/v1.2.0...master
[1.2.0]: https://github.com/ManageIQ/pg-logical_replication/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/ManageIQ/pg-logical_replication/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/ManageIQ/pg-logical_replication/tree/v1.0.0

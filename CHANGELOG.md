# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/).

## [1.3.0] - Unreleased

BREAKING: Given the amount breaking changes introduces between Astarte 1.2.x and Astarte 1.3.x (and related Operator versions), the Astarte Cluster GitHub Action v1.3+ is only compatible with Astarte 1.3.x and Astarte Operator 26.5.x. It is advised to use Astarte Cluster GitHub Action v1.2 to use previous versions of Astarte.

### Added
- Support for Astarte 1.3.x and Astarte Kubernetes Operator 26.5.x.
- Installation of required prerequisites, including cert-manager, HAProxy Ingress Controller, RabbitMQ Cluster Operator, and Scylla Operator.
- Added a changelog.

### Changed
- BREAKING: Updated default versions for Astarte, Astarte Operator, astartectl.
- Version bump for cert-manager, KinD, GH Actions and related dependencies.
- Major refactor of the repository layout, moving manifests, scripts, and certificates into dedicated directories.
- Switched from NGINX Ingress Controller to HAProxy.
- Replaced fixed sleeps with `kubectl wait`-based readiness checks.
- Updated cluster setup to use HTTPS endpoints and the new Astarte 1.3 manifests.

### Removed
- BREAKING: NGINX Ingress Controller deployment as prerequisite.

### Fixed
- General deployment stability and reliability issues.
- Optional realm creation skipping when `astarte_realm` is set to an empty string.
- Improved setup logging and readiness checks during cluster creation.

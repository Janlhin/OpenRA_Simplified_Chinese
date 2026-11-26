# 变更记录

本文件登记**尚未发布**的改动（`## [Unreleased]`）。按版本固化的发布史在
[`docs/CHANGELOG.md`](docs/CHANGELOG.md)——其顶层条目格式由 `scripts/check-versions.ps1`
锁定（`## X.Y.Z — YYYY-MM-DD`，须与各线 `bin/manifest.json` 一致），不在本文件维护。

## [Unreleased]

### Added

- 2026-11-26：补齐发布治理骨架——[`docs/release-and-rollback.md`](docs/release-and-rollback.md)
  （安装 / 卸载 / 回滚 / 版本兼容 / 校验和）与 [`docs/release-checklist.md`](docs/release-checklist.md)
  （发布前检查清单）。

### Changed

- 2026-11-26：将 `NOTICE.md` 登记进顶层结构白名单与 README 结构表，修复 `validate`
  工作流 `check-layout` 步骤的红态（其余校验步骤此前均通过）。

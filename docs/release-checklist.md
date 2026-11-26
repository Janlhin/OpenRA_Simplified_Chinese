# 发布检查清单（OpenRA 汉化仓）

发版前逐项勾选；任一项不通过，不打 tag、不上传 Release 附件。安装/卸载/回滚/兼容与
校验和口径见 [`release-and-rollback.md`](release-and-rollback.md)，发版步骤见
[`MAINTAINING.md`](MAINTAINING.md)「发新版本」。

## 产物齐全

- [ ] 两条产品线（或本次发布的那条线）的 `files/` 载荷与 `fonts/` 就位。
- [ ] `bin/manifest.json` 的 `version` / `releaseDate` 与计划发布版本一致；两条线统一版号。
- [ ] 包内入口（`setup.ps1` / CMD 模板）、安装说明、LICENSE、字体随包清单齐全。

## 校验通过

- [ ] `python tools/verify_manifest.py`：载荷、字体与清单逐字节一致，字体未误入 `files/`。
- [ ] `pwsh -NoLogo -NoProfile -File scripts/verify.ps1` 退出码 0（版本一致、文档结构、
      布局白名单、脚本基线、Fluent 规范、地图结构、链接、生成物、字形覆盖、打包自校验）。
- [ ] `pwsh -NoLogo -NoProfile -File scripts/pre-release.ps1 -Rebuild` 七项自检结论归档到
      `dist/pre-release-<版本>.json`；签名与病毒扫描按 D-016 记「已登记豁免」，不在发布说明
      里声称已签名或「已通过病毒检测」。

## 文档与版本对齐

- [ ] 改动载荷后已重算 `manifest.json` 的 size/sha256，并重生成 README 附录与 `安装说明.txt`。
- [ ] [`../CHANGELOG.md`](../CHANGELOG.md) 的 Unreleased 条目已整理进
      [`CHANGELOG.md`](CHANGELOG.md) 对应版本一节并补上日期。
- [ ] 未核对的引擎版本 / 平台兼容性不写「兼容」结论。

## 回滚路径可用

- [ ] 卸载脚本按备份逐字节还原；旧版 zip 可从对应 Release 取回重装。
- [ ] 备份与日志不进入发布包白名单。

## 门禁

- [ ] 既有 `validate.yml` 在本分支推送后跑绿；本地未跑通的步骤不写入 CI。

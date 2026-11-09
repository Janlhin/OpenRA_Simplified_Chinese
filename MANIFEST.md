# 第三方来源登记（MANIFEST）

> 凡进入仓库或发布包的第三方**二进制、源码、逆向产物**，必须在此登记：来源 URL、版本、SHA256、用途、**许可结论**。
> 许可结论为空 = 该条目不完整，`scripts/check-docs.ps1` 会判失败。
> 仅构建期使用、不随包分发的依赖，「是否随包」填 `否`，SHA256 可填 `—`（由包管理器锁定）。

| 名称 | 来源 | 版本 | SHA256 | 用途 | 许可结论 | 是否随包 |
|---|---|---|---|---|---|---|
| Noto Sans SC Regular | https://github.com/google/fonts/blob/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf | google/fonts main，`wght=400` 固化 | `3ee4c70117ea2a94369dec831e43445d4f73cd0bb419fc7c558ff933e4c2a5b1` | 正文中文字体，安装到 `mods/common/` | SIL OFL 1.1，允许随包分发（见 `LICENSE-OFL.txt`） | 是 |
| Noto Sans SC Bold | https://github.com/google/fonts/blob/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf | google/fonts main，`wght=700` 固化 | `f9ec901913a6b47200a63096a1044fd38298ee89d6930af1acb2851601120e32` | 标题/粗体中文字体，同上 | SIL OFL 1.1，允许随包分发 | 是 |
| OpenRA 上游 Mod 文案 | https://github.com/OpenRA/OpenRA/tree/playtest-20261026/mods | `playtest-20261026` | —（按 tag 检出，不随包） | 译文基线、键集合与占位符校验 | GPL-3.0；译文为其衍生，本项目同许可 | 否 |
| RASC / TDSC 术语参考 | https://gitee.com/CastleJing/OpenRA_rasc · https://gitee.com/CastleJing/OpenRA_tdsc | 2026-10 快照 | —（仅人工比对，未复制文件） | 单位/建筑译名对齐 | GPL-3.0；仅参考用词，未复制代码或文案文件 | 否 |
| fonttools | https://pypi.org/project/fonttools/ | 由 pip 解析 | —（不随包） | 可变字体固化、字形覆盖检查 | MIT | 否 |
| GitHub Actions（actions/checkout、setup-python） | https://github.com/actions | v4 / v5 | —（CI 运行时拉取） | CI 校验环境 | MIT | 否 |

## 复核方式

- 随包字体的哈希必须与 `src/manifest.json` 的 `font.bundled[].sha256` 一致：

```bash
pwsh -NoLogo -NoProfile -File scripts/verify.ps1
```

- 新增第三方资产时，先登记再提交；`git log -- MANIFEST.md` 应能看到与资产同批的条目。

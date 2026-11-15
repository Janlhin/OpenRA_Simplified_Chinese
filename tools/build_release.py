# -*- coding: utf-8 -*-
"""构建发布包：`<仓库名>-<版本><后缀>.zip`。

两条产品线共用这一套打包与安装器，靠 `--profile` 选线：

- `playtest`（默认）：仓库根 `files/` + `fonts/`，版本 1.6.1，目标 `playtest-20261026`，带 `hotfix/`
- `release-20250330`：`release-20250330/files/` 作载荷 + 仓库根 `fonts/`，版本 2.0.0，
  目标官方 `release-20250330`，不带热修

两条线产出的包**布局完全一致**（`setup.ps1` / `setup.bat` / `setup.cmd` / `bin/install.ps1`
/ `bin/manifest.json` / `bin/files.sha256` / `files/` / `fonts/`），安装、还原、校验逻辑
只有一份代码（`src/install.ps1`），差异全部由清单的 `engineVersion` 与 `files[]` 驱动。

默认**只打玩家需要的文件**（白名单），研发资产（tools/、docs/、.github/、
CONTRIBUTING 等）留在仓库里，不进包。玩家解压后看到的布局：

    LICENSE / LICENSE-OFL.txt               ← 原样落到包根
    setup.ps1                               ← 来自 src/
    setup.bat / setup.cmd                   ← 打包时生成的纯 CMD 入口（不依赖 PS）
    bin/install.ps1 / bin/manifest.json     ← 来自 src/（收进 bin/）
    bin/files.sha256                        ← 打包时生成的部署清单，供纯 CMD 入口逐文件校验
    README.md / 安装说明.txt / 安装说明.md    ← 来自 src/（README 由 PACKAGE-README 改名）
    hotfix/**                               ← 可选引擎热修（纯 CMD 与 PS1 两套入口，仅 playtest 线）
    files/**                                 ← 文本载荷（208 或 197 个）
    fonts/**                                 ← Noto Sans SC 两个字重

`--dev` 打全量快照（除 .git/、dist/、*.zip），给内部复现问题用。

仓库里**零 `.bat` / `.cmd`**：发布包里的六个批处理入口由 `tools/cmd-templates/*.tpl`
现场生成（每个模板产出内容相同的 `.bat` 与 `.cmd` 两份）。模板保持纯 ASCII，写出时
统一转 CRLF；脚本内部只用 `certutil` / `copy` / `robocopy`，不调用任何 PowerShell 宿主。

包是**确定性**的：zip 内时间戳取自 manifest.json 的 releaseDate，
同一份仓库内容每次产出字节一致的 zip。

`--verify` 把包解压到临时目录后**在包内自带校验**（不依赖 tools/，因为发布包
不含 tools/）：入口文件是否齐全、bin/manifest.json 是否与仓库一致、208 个载荷的
size/sha256 是否对得上、files/ 里有没有多余文件。

用法:
    python tools/build_release.py [--out <zip路径>] [--verify] [--dev]
"""
import argparse
import hashlib
import json
import os
import re
import shutil
import sys
import tempfile
import zipfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 发布包白名单：改这里等于改「玩家拿到什么」
BASE_FILES = ('LICENSE', 'LICENSE-OFL.txt')

# 打包时现场生成的纯 CMD 入口。
#
# 仓库本身保持零 .bat / .cmd：模板以 .tpl 入库，生成物只写进 zip。
# 每个模板产出内容完全相同的 .bat 与 .cmd 两份——有的机器上 .bat 被改了关联或被
# 安全软件拦掉，换个扩展名就能双击。两者都是**自包含**的纯批处理，不转发 .ps1，
# 所以 PowerShell 被禁用 / 被精简掉 / 执行策略锁死的机器也能装。
CMD_TEMPLATES = {
    'setup.cmd.tpl': ('setup.bat', 'setup.cmd'),
    'apply-hotfix.cmd.tpl': ('hotfix/apply-hotfix.bat', 'hotfix/apply-hotfix.cmd'),
    'rollback-hotfix.cmd.tpl': ('hotfix/rollback-hotfix.bat', 'hotfix/rollback-hotfix.cmd'),
}

# 两条产品线共用同一套安装器（setup.ps1 只转发、bin/install.ps1 有业务逻辑、
# 打包时再生成纯 CMD 双入口），差别只在「装什么」：载荷目录、包内文档、版本与目标引擎。
# 新增一条线时只加一个 profile，安装器代码不需要分叉。
PROFILES = {
    # playtest 线：playtest-20261026/ 目录自成一包，带可选引擎热修
    'playtest-20261026': {
        'title': 'playtest 线（2.0.0）',
        'manifest': 'playtest-20261026/bin/manifest.json',
        'payload': (('playtest-20261026/files', 'files'), ('fonts', 'fonts')),
        'layout': {
            'src/setup.ps1': 'setup.ps1',
            'src/install.ps1': 'bin/install.ps1',
            'playtest-20261026/bin/manifest.json': 'bin/manifest.json',
            # 线目录里的 README.md 是**包内**那份 README 的源文件：链接只指向 zip 里确实
            # 存在的文件，与仓库首页（根 README.md，面向读源码的人）分开维护。
            'playtest-20261026/README.md': 'README.md',
            'playtest-20261026/安装说明.txt': '安装说明.txt',
            'playtest-20261026/安装说明.md': '安装说明.md',
            'playtest-20261026/hotfix/README.md': 'hotfix/README.md',
            'playtest-20261026/hotfix/apply-hotfix.ps1': 'hotfix/apply-hotfix.ps1',
            'playtest-20261026/hotfix/rollback-hotfix.ps1': 'hotfix/rollback-hotfix.ps1',
            'playtest-20261026/hotfix/OpenRA.Game.dll': 'hotfix/OpenRA.Game.dll',
            'playtest-20261026/hotfix/OpenRA.Mods.Common.dll': 'hotfix/OpenRA.Mods.Common.dll',
        },
        'templates': ('setup.cmd.tpl', 'apply-hotfix.cmd.tpl', 'rollback-hotfix.cmd.tpl'),
        'hotfix_ps1': 'playtest-20261026/hotfix/apply-hotfix.ps1',
        'suffix': '-playtest20261026',
    },
    # 稳定版线：release-20250330/ 目录自成一包，字体取仓库根 fonts/，不带热修
    'release-20250330': {
        'title': '稳定版线（2.0.0）',
        'manifest': 'release-20250330/bin/manifest.json',
        'payload': (('release-20250330/files', 'files'), ('fonts', 'fonts')),
        'layout': {
            'src/setup.ps1': 'setup.ps1',
            'src/install.ps1': 'bin/install.ps1',
            'release-20250330/bin/manifest.json': 'bin/manifest.json',
            'release-20250330/README.md': 'README.md',
            'release-20250330/安装说明.md': '安装说明.md',
            'release-20250330/适配说明.md': '适配说明.md',
            'release-20250330/未译条目清单.csv': '未译条目清单.csv',
        },
        'templates': ('setup.cmd.tpl',),
        'hotfix_ps1': None,
        'suffix': '-release20250330',
    },
}

DEFAULT_PROFILE = 'playtest-20261026'

# 纯 CMD 安装器的部署清单：三列 = SHA256 / 包内源路径 / 游戏目录相对路径。
# 清单由 manifest.json 生成（不在仓库里手写），安装、还原、卸载校验都读它。
CHECKSUM_LIST = 'bin/files.sha256'


def checksum_list(manifest):
    """字体排在前面——文档强调「先放字体、后覆盖文本」，顺序反了引擎会启动报错。"""
    lines = []
    for font in (manifest.get('font') or {}).get('bundled', []):
        lines.append('%s  %s  %s' % (font['sha256'], font['path'], font['deployTo']))
    for entry in manifest['files']:
        rel = entry['path']
        lines.append('%s  files/%s  %s' % (entry['sha256'], rel, rel))
    return '\r\n'.join(lines) + '\r\n'


def generated_files(root, manifest, profile):
    """返回 {包内相对路径: bytes}；同时守住模板与 PS1 的哈希一致性。"""
    out = {}
    ps1 = None
    if profile['hotfix_ps1']:
        ps1 = open(os.path.join(root, profile['hotfix_ps1'].replace('/', os.sep)),
                   encoding='utf-8-sig').read()

    for tpl_name in profile['templates']:
        tpl_rel = 'tools/cmd-templates/' + tpl_name
        tpl_path = os.path.join(root, tpl_rel.replace('/', os.sep))
        if not os.path.exists(tpl_path):
            raise SystemExit('缺少 CMD 模板：' + tpl_rel)
        text = open(tpl_path, encoding='utf-8').read()
        if not text.isascii():
            raise SystemExit('CMD 模板必须是纯 ASCII（cmd.exe 会拆坏中文行）：' + tpl_rel)

        # 模板里的 @@ENGINE@@ / @@TEXTCOUNT@@ 由本次打包的清单填入：
        # 同一份模板才能同时供 playtest 线与稳定版线使用
        text = text.replace('@@ENGINE@@', manifest['engineVersion'])
        text = text.replace('@@TEXTCOUNT@@', str(len(manifest['files'])))

        # 模板里的四个 DLL 哈希必须与 PS1 / README 同源，任何一处漂移都直接打包失败
        # （只有带热修的 profile 才有这层耦合；稳定版没有 hotfix/）
        if ps1 is not None:
            for h in re.findall(r'\b[0-9a-f]{64}\b', text):
                if h not in ps1:
                    raise SystemExit('CMD 模板里的哈希与 apply-hotfix.ps1 不一致：%s / %s' % (tpl_rel, h))

        crlf = text.replace('\r\n', '\n').replace('\n', '\r\n')
        data = crlf.encode('utf-8')          # 无 BOM；脚本首行靠 chcp 65001 显示中文
        for target in CMD_TEMPLATES[tpl_name]:
            out[target] = data

    out[CHECKSUM_LIST] = checksum_list(manifest).encode('ascii')  # 无 BOM，for /f 才读得对
    return out


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def walk_dir(root, sub):
    out = []
    base = os.path.join(root, sub)
    for dp, dn, fn in os.walk(base):
        dn.sort()
        for f in sorted(fn):
            out.append(os.path.relpath(os.path.join(dp, f), root).replace(os.sep, '/'))
    return out


def collect(root, profile, dev=False):
    if dev:
        out = []
        for dp, dn, fn in os.walk(root):
            parts = os.path.relpath(dp, root).split(os.sep)
            if parts and parts[0] in ('.git', 'dist'):
                dn[:] = []
                continue
            dn.sort()
            for f in sorted(fn):
                if f.lower().endswith('.zip'):
                    continue
                out.append(os.path.relpath(os.path.join(dp, f), root).replace(os.sep, '/'))
        return sorted(out)

    layout = profile['layout']
    missing = [f for f in list(BASE_FILES) + list(layout) if not os.path.exists(os.path.join(root, f.replace('/', os.sep)))]
    if missing:
        raise SystemExit('白名单里的文件在仓库中不存在：%s' % ', '.join(missing))
    out = list(BASE_FILES) + list(layout)
    for src_dir, _arc in profile['payload']:
        if not os.path.isdir(os.path.join(root, src_dir.replace('/', os.sep))):
            raise SystemExit('载荷目录不存在：%s' % src_dir)
        out += walk_dir(root, src_dir)
    return sorted(set(out))


def package_path(rel, profile):
    """仓库路径 -> 包内路径。载荷目录按 profile['payload'] 重挂到统一布局下。"""
    layout = profile['layout']
    if rel in layout:
        return layout[rel]
    for src_dir, arc_dir in profile['payload']:
        if rel == src_dir:
            return arc_dir
        if rel.startswith(src_dir + '/'):
            return arc_dir + rel[len(src_dir):]
    return rel


LINK = re.compile(r'\[[^\]]*\]\(([^)\s]+)\)')


def check_package_links(vroot):
    """包内 Markdown 的相对链接必须指向包里真实存在的文件。

    仓库里 check_links.py 只保证"在仓库里能解析"——README 一旦被放进 zip，
    指向 CONTRIBUTING.md / docs/ 的链接就全成了死链，而仓库侧完全看不出来。
    """
    problems = []
    for name in sorted(os.listdir(vroot)):
        if not name.lower().endswith(('.md', '.txt')):
            continue
        path = os.path.join(vroot, name)
        if not os.path.isfile(path):
            continue
        text = open(path, encoding='utf-8', errors='ignore').read()
        for target in set(LINK.findall(text)):
            if target.startswith(('http://', 'https://', 'mailto:', '#')):
                continue
            rel = target.split('#')[0]
            if not os.path.exists(os.path.join(vroot, rel.replace('/', os.sep))):
                problems.append('包内死链：%s 里的 %s' % (name, target))
    return problems


def verify_package(vroot, root, profile, manifest, generated):
    """在解压出的包上做自校验，返回问题列表（空 = 通过）。"""
    problems = []

    required = [package_path(f, profile) for f in list(BASE_FILES) + list(profile['layout'])] + list(generated)
    for name in required:
        if not os.path.exists(os.path.join(vroot, name.replace('/', os.sep))):
            problems.append('缺少入口文件：%s' % name)

    # 现场生成物必须与模板逐字节一致（防止打包后有人手改 zip）
    for name, data in generated.items():
        path = os.path.join(vroot, name.replace('/', os.sep))
        if os.path.exists(path) and open(path, 'rb').read() != data:
            problems.append('生成物与模板不一致：%s' % name)

    # 部署清单：行数 = 载荷 + 字体，且每行必须是「64 位哈希 + 两个路径」
    list_path = os.path.join(vroot, CHECKSUM_LIST.replace('/', os.sep))
    if os.path.exists(list_path):
        rows = [l for l in open(list_path, encoding='ascii').read().splitlines() if l.strip()]
        expect = len(manifest['files']) + len((manifest.get('font') or {}).get('bundled', []))
        if len(rows) != expect:
            problems.append('部署清单行数不符：%d 行，应为 %d 行' % (len(rows), expect))
        for row in rows:
            if not re.match(r'^[0-9a-f]{64}  \S+  \S+$', row):
                problems.append('部署清单格式错误：%s' % row[:80])
                break

    pkg_manifest = os.path.join(vroot, package_path(profile['manifest'], profile).replace('/', os.sep))
    if os.path.exists(pkg_manifest):
        if sha256(pkg_manifest) != sha256(os.path.join(root, profile['manifest'].replace('/', os.sep))):
            problems.append('包内 manifest.json 与仓库不一致（请重新构建）')

    listed = set()
    for entry in manifest['files']:
        rel = entry['path']                      # 相对 files/（例如 mods/ra/fluent/ra.ftl）
        listed.add('files/' + rel)
        path = os.path.join(vroot, 'files', rel.replace('/', os.sep))
        if not os.path.exists(path):
            problems.append('载荷缺失：%s' % rel)
            continue
        size = os.path.getsize(path)
        if size != entry['size']:
            problems.append('大小不符：%s（实际 %d，清单 %d）' % (rel, size, entry['size']))
        if sha256(path) != entry['sha256']:
            problems.append('哈希不符：%s' % rel)

    problems.extend(check_package_links(vroot))

    if os.path.isdir(os.path.join(vroot, 'files')):
        for rel in walk_dir(vroot, 'files'):     # 相对包根，形如 files/mods/...
            if rel not in listed:
                problems.append('多余载荷：%s' % rel)

    # 随包字体：路径、大小、哈希都要与 manifest 的 font.bundled 对得上
    for font in (manifest.get('font') or {}).get('bundled', []):
        rel = font['path']
        path = os.path.join(vroot, rel.replace('/', os.sep))
        if not os.path.exists(path):
            problems.append('字体缺失：%s' % rel)
            continue
        if os.path.getsize(path) != font['size']:
            problems.append('字体大小不符：%s' % rel)
        if sha256(path) != font['sha256']:
            problems.append('字体哈希不符：%s' % rel)

    return problems


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--repo', default=REPO, help='仓库根（默认本脚本所在仓库）')
    ap.add_argument('--profile', default=DEFAULT_PROFILE, choices=sorted(PROFILES),
                    help='打哪个产品线的包（默认 %s）' % DEFAULT_PROFILE)
    ap.add_argument('--out', help='输出 zip 路径（默认 dist/<仓库名>-<版本><后缀>.zip）')
    ap.add_argument('--verify', action='store_true', help='解压并做包内自校验')
    ap.add_argument('--dev', action='store_true', help='打全量快照（含 tools/docs 等研发资产）')
    args = ap.parse_args()

    root = os.path.abspath(args.repo)
    profile = PROFILES[args.profile]
    manifest_file = os.path.join(root, profile['manifest'].replace('/', os.sep))
    with open(manifest_file, encoding='utf-8') as fh:
        manifest = json.load(fh)
    generated = generated_files(root, manifest, profile)
    version = manifest['version']
    top = manifest['name']
    y, m, d = (int(x) for x in manifest['releaseDate'].split('-'))
    dt = (y, m, d, 0, 0, 0)

    name = '%s-%s%s%s.zip' % (top, version, profile['suffix'], '-dev' if args.dev else '')
    out = args.out or os.path.join(root, 'dist', name)
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)

    files = collect(root, profile, dev=args.dev)
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
        for rel in files:
            arc = top + '/' + (rel if args.dev else package_path(rel, profile))
            zi = zipfile.ZipInfo(arc, date_time=dt)
            zi.compress_type = zipfile.ZIP_DEFLATED
            zi.external_attr = 0o644 << 16
            with open(os.path.join(root, rel.replace('/', os.sep)), 'rb') as fh:
                z.writestr(zi, fh.read())

        # 纯 CMD 入口与部署清单（仓库里没有 .bat/.cmd，这里现场生成写进 zip）
        for rel, data in sorted(generated.items()):
            arc = top + '/' + rel
            zi = zipfile.ZipInfo(arc, date_time=dt)
            zi.compress_type = zipfile.ZIP_DEFLATED
            zi.external_attr = 0o644 << 16
            z.writestr(zi, data)

    size = os.path.getsize(out)
    print('发布包:', out)
    print('  产品线  :', profile['title'], '/', args.profile)
    print('  模式    :', '全量快照(--dev)' if args.dev else '玩家包(白名单)')
    print('  版本    :', version, '/ 引擎', manifest['engineVersion'])
    print('  条目    : %d 个文件（含 %d 个现场生成的纯 CMD 入口/清单）' % (len(files) + len(generated), len(generated)))
    print('  大小    : %d 字节 (%.1f KB)' % (size, size / 1024))
    print('  sha256  :', sha256(out))

    if not args.verify:
        print('(未加 --verify，跳过解压自校验)')
        return 0

    tmp = tempfile.mkdtemp(prefix='relverify-')
    try:
        with zipfile.ZipFile(out) as z:
            z.extractall(tmp)
        vroot = os.path.join(tmp, top)
        print('解压自校验:', vroot)
        problems = verify_package(vroot, root, profile, manifest, generated)
        if problems:
            for p in problems[:20]:
                print('  [失败] ' + p)
            if len(problems) > 20:
                print('  ...共 %d 个问题' % len(problems))
            return 1
        print('  [通过] 入口文件齐全（含 %d 个纯 CMD 入口），bin/manifest.json 与仓库一致'
              % (len(generated) - 1))
        print('  [通过] 生成物与模板逐字节一致，部署清单 %d 行格式正确' %
              (len(manifest['files']) + len((manifest.get('font') or {}).get('bundled', []))))
        print('  [通过] 随包字体 %d 个，size+sha256 与 manifest 一致' % len((manifest.get('font') or {}).get('bundled', [])))
        print('  [通过] %d 个载荷 size+sha256 全部一致，无多余文件' % len(manifest['files']))
        print('  [通过] 包内 Markdown/TXT 的相对链接都落在包里')
        return 0
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == '__main__':
    sys.exit(main())

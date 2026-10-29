# 视频下载助手 · Video Downloader

Apple Silicon Mac 上的原生视频下载工具。粘贴网页链接，每行一个，加入队列后按顺序下载。界面由 Swift/AppKit 构建，下载使用 yt-dlp，音视频合并使用 FFmpeg。

支持批量队列、重复等待任务去重、下载中追加链接、暂停与继续、更改并记住保存目录，以及下载日志。默认保存到系统下载目录；退出会清空任务队列，已下载文件保留。

## 构建与启动

需要 Apple Silicon、macOS 13+、Xcode Command Line Tools，以及 Homebrew Python 3 和 FFmpeg：

```bash
xcode-select --install
brew install python ffmpeg
./test.sh
./build.sh
open build/视频下载助手.app
```

应用会使用 `/opt/homebrew/bin/python3`、`ffmpeg` 与 `ffprobe`，当前不是跨平台独立安装包。构建脚本将 Python 依赖装入 app 内的 runtime/，这些第三方包不提交到仓库。签名为本地 ad hoc 签名，尚未做开发者签名或公证。

requirements.txt 保留原应用使用的 yt-dlp 开发版与 curl-cffi 版本。新建环境安装需要网络及对应发行包可用。已有兼容运行时可用 `RUNTIME_SOURCE=/path/to/runtime ./build.sh` 复用；本次导入使用此方式验证构建，未重新从网络安装全部依赖。

## 使用

1. 粘贴视频网页完整链接，每行一个。
2. 点击「加入队列并下载」。
3. 下载完成后点击「打开下载文件夹」。

暂停会中断当前任务并保留等待队列；继续时重新交给 yt-dlp 处理。不自动下载整个播放列表。任务失败后会继续下一条，可再次粘贴失败链接重试。

不会读取浏览器 Cookie 或登录信息。依赖登录、会员权限、DRM 或特殊验证的网站可能无法下载；网站改动也可能需要更新 yt-dlp。仅下载你有权保存的内容。

## 目录与验证

- Source/：AppKit 界面、链接编辑器与队列。
- Resources/：下载入口和应用图标。
- tests/：队列验证，覆盖链接校验、去重、顺序执行、失败继续与暂停恢复。
- build.sh / test.sh：构建与检查入口。

本次导入检查队列行为、Python 语法和应用编译，未重新执行真实网络视频下载。下载文件、依赖运行时、应用构建产物和个人设置不入库。

仓库暂为私有，尚未选择项目开源许可证；第三方依赖遵守各自许可。

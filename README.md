# ZiYouAutoLink

> 作者 / Author: **TOTO & rumip**
>
> 🤖 **本项目由 AI 生成** —— 代码与文档由 AI 助手 **TOTO** 与 **rumip** 协作产出：
> AI 负责实现与写作，人负责提需求、定方案取舍，并在真机上验证。

让「字由」跟着 Photoshop / Illustrator 自动启停 —— 打开 Adobe 软件时字由在后台自己起来，全退出后自己收工。

## 它做什么

- **打开 Photoshop 或 Illustrator** → 字由自动在后台起来（最小化到任务栏，不会弹到你面前，也不会抢走你当前的输入焦点）。
- **两个软件都退出后，10 分钟内没有再打开其中任何一个** → 字由被自动关闭。
- **空闲时不留任何常驻进程** —— 它只在 Adobe 软件启动 / 退出的那一刻短暂运行。

## 安装

1. 到本仓库的 **Releases** 页下载 `ZiYouAutoLink-v1.0.zip`，解压到任意位置。
2. 双击 `install.bat`。
3. 弹出 UAC 时点「是」（需要管理员权限：要往 Illustrator 安装目录写一个启动脚本）。
4. 看输出的「安装结果」，两边都打勾就完成了。

安装时的两个注意点：

- 如果 Photoshop 没开着，程序会以最小化方式启动它一次，注册完自动关闭；
- 如果 Illustrator 正开着，**需要重启一次 Illustrator**，启动脚本才会生效。

## 卸载

双击 `uninstall.bat`（同样需要管理员权限）。卸载后会以最小化方式启动一次 PS 来清理注册项，不留残留。

## 日志 / 排查

```
%LOCALAPPDATA%\ZiYouAutoLink\logs\ziyou-link.log
```

想确认它到底有没有工作，打开这个文件看时间戳和动作即可。

## 常见问题

**Q: 提示「没有找到字由客户端」**
字由没装在常见位置。按提示把 `字由.exe` 的完整路径粘贴进去就行。

**Q: 提示「没找到 Photoshop / Illustrator」**
装在非标准位置（例如绿色版）。这不会破坏任何东西，只是对应的联动不生效。

**Q: 想改「退出多久后关闭字由」**
打开 `%LOCALAPPDATA%\ZiYouAutoLink\config.json`，把 `graceSeconds` 改成你要的秒数（例如 180 就是 3 分钟）。

**Q: 想临时关掉联动、但保留安装**
打开 Photoshop → 文件 > 脚本 > 脚本事件管理器，把 `Start Application` 和 `Quit Application` 两条删掉。
（重新运行 `install.bat` 可以再装回来。）

## 它是怎么做的

- **Photoshop 侧**：通过 Photoshop 的 COM 自动化接口注册两个脚本事件（`Start Application` / `Quit Application`）。
  这就是 Photoshop 自带的「脚本事件管理器」机制，安装程序只是替你自动配好了，**没有装任何常驻程序**。
- **Illustrator 侧**：在它的安装目录里创建 `Startup Scripts\` 并放入一个 `.jsx` —— 这是 Adobe 官方文档支持的启动脚本机制。
  Illustrator 的脚本接口**没有退出事件**（官方对象参考里没有 `notifiers`），所以它运行期间会有一个极轻量的等待进程，等它退出后再做倒计时收尾。
- **字由是 Electron 程序**，启动瞬间会自己弹窗并抢焦点几秒。本程序会在这几秒里持续把它压回最小化，并把焦点还给你原来在用的窗口。

## 目录结构

```
install.bat          安装入口（自提权 → core\install.ps1）
uninstall.bat        卸载入口（自提权 → core\uninstall.ps1）
core\
  install.ps1        查找字由 / PS / AI，注册 PS 脚本事件，部署 AI 启动脚本，复制运行时文件
  uninstall.ps1      清理上述一切
  ziyou-launch.ps1   拉起字由，并压制它启动时抢焦点
  ziyou-grace.ps1    宽限期倒计时，到点关闭字由
  ziyou-*.vbs        WSH 启动壳（避开 PowerShell 窗口闪烁）
  hook-ps-start.jsx  Photoshop「Start Application」事件钩子
  hook-ps-quit.jsx   Photoshop「Quit Application」事件钩子
  hook-ai-start.jsx  Illustrator 启动脚本钩子
```

## 环境要求

- Windows 10 / 11（64 位）
- 字由客户端（HelloFont）
- Photoshop 和 / 或 Illustrator

## 许可

本项目以 **GNU General Public License v3.0** 发布 —— 完整条款见 [`LICENSE`](LICENSE)。
Copyright (C) 2026 TOTO & rumip.

你可以自由使用、修改、再分发；但把二进制或脚本分发给别人时（不论改没改过），必须让对方也能拿到对应的完整源码。

## 免责

本工具是个人出于兴趣编写的**非官方**工具，与 Adobe、字由（HelloFont）官方及其关联公司没有任何关系，也未获得其授权或认可。
使用本工具的一切后果由使用者自行承担。

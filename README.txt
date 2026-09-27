ZiYouAutoLink — 让字由跟着 Photoshop / Illustrator 自动启停
==========================================================
作者 / Author: TOTO & rumip（本项目由 AI 生成）

【它做什么】
  · 打开 Photoshop 或 Illustrator 时，字由会自动在后台起来（最小化到任务栏，
    不会弹到你面前，也不会抢走你当前的输入焦点）。
  · 两个软件都退出后，如果 10 分钟内没有再打开其中任何一个，字由会被自动关闭。
  · 机器上不会留下任何常驻进程 —— 它只在 Adobe 软件启动 / 退出的那一刻短暂运行。

【安装】
  1. 双击 install.bat
  2. 弹出 UAC 时点“是”（需要管理员权限：要往 Illustrator 安装目录写一个启动脚本）
  3. 看输出的“安装结果”，两边都打勾就完成了

  注意：
   · 安装时如果 Photoshop 没开着，程序会以最小化方式启动它一次，注册完自动关闭
   · 安装时如果 Illustrator 正开着，需要重启一次 Illustrator，启动脚本才会生效

【卸载】
  双击 uninstall.bat（同样需要管理员权限）

【日志 / 排查】
  %LOCALAPPDATA%\ZiYouAutoLink\logs\ziyou-link.log
  想确认它到底有没有工作，打开这个文件看时间戳和动作即可。

【常见问题】
  Q: 提示“没有找到字由客户端”
  A: 字由没装在常见位置。按提示把 字由.exe 的完整路径粘贴进去就行。

  Q: 提示“没找到 Photoshop / Illustrator”
  A: 装在非标准位置（例如绿色版）。这不会破坏任何东西，只是对应的联动不生效。

  Q: 想改“退出多久后关闭字由”
  A: 打开 %LOCALAPPDATA%\ZiYouAutoLink\config.json，
     把 graceSeconds 改成你要的秒数（例如 180 就是 3 分钟）。

  Q: 想临时关掉联动、但保留安装
  A: 打开 Photoshop -> 文件 > 脚本 > 脚本事件管理器，
     把 "Start Application" 和 "Quit Application" 两条删掉即可。
     （重新运行 install.bat 可以再装回来。）

  Q: 卸载时 Photoshop 没开怎么办
  A: 卸载程序会自动以最小化方式启动它、清理注册、再关掉，不会留残留。

【技术说明（给好奇的人）】
  · Photoshop 侧：通过 Photoshop 的 COM 自动化接口注册两个脚本事件
    （Start Application / Quit Application）。这就是 Photoshop 自带的
    “脚本事件管理器”机制，安装程序只是替你自动配好了，没有装任何常驻程序。
  · Illustrator 侧：在它的安装目录里创建 Startup Scripts\ 并放入一个 .jsx，
    这是 Adobe 官方文档支持的启动脚本机制。
  · Illustrator 的脚本接口没有退出事件（官方对象参考里没有 notifiers），
    所以它运行期间会有一个极轻量的等待进程，等它退出后再做倒计时收尾。
    Photoshop 侧完全没有这个问题，纯零进程。
  · 字由是 Electron 程序，启动瞬间会自己弹窗并抢焦点几秒。本程序会在这几秒里
    持续把它压回最小化，并把焦点还给你原来在用的窗口。

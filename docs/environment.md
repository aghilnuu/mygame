# 开发环境

- 平台：Windows x64。
- 引擎：Godot 4.7.2 stable 标准版，GDScript。
- 渲染：Compatibility，适用于当前 2D 原型。
- 本机安装位置：`%LOCALAPPDATA%\Programs\Godot\4.7.2`。
- 版本管理：本机已安装 Git，远端为 `https://github.com/aghilnuu/mygame.git`，分支为 `main`。

## 安装来源

官方入口：https://godotengine.org/download/windows/

官方发布文件：https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_win64.exe.zip

通过同一官方发布的 `SHA512-SUMS.txt` 校验下载包，解压至上述安装位置。标准版不需要额外安装 .NET SDK。

重新配置电脑时，下载该版本并解压，再导入 `project.godot`。桌面快捷方式属于本机配置，不上传仓库。

## 验证方式

1. 引擎输出版本号。
2. 使用 `--headless --editor --path <项目目录> --quit` 导入工程并检查解析错误。
3. 使用 `--headless --path <项目目录> --quit-after 5` 验证启动场景。
4. 打开实际游戏窗口检查中文、布局和退出按钮。

导出模板留到制作独立可执行版本时安装；当前可直接从 Godot 运行项目。

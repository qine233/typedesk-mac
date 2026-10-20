# NLtypedesk

macOS 上的 Typecho 写作 / 笔记 / 站点数据客户端，界面风格取自 noline 主题的设计令牌。

## 功能

- **写作**：仿 Bear 三栏布局，Markdown 编辑器（写作 / 分屏 / 预览），词数与阅读时长统计，图片上传后自动插入 Markdown。
- **站点管理**：文章、分类、标签、独立页面、评论审核（通过 / 垃圾 / 撤回 / 删除），全部走 Typecho XML-RPC。
- **本地笔记**：Markdown 文件存在本机，自动保存，并自动同步为 Typecho 草稿（记住 cid，之后一律编辑；已正式发布的笔记不会被降级回草稿）。
- **云端内容转 Markdown**：拉取的文章 / 页面 HTML 正文自动转换为 Markdown，已是 Markdown 的内容原样保留。
- **站点数据（NolineApi 插件）**：
  - 健康记录：当前体重 / BMI 分档 / 目标进度 / 7-30-90 天涨跌，按真实日期绘制的趋势曲线，录入按「整天整体覆盖」语义回传完整字段。
  - 买菜记账：本周 / 本月 / 累计看板（涨跌客户端计算并带「第 N/7 天」等语境）、近 7 个月柱状（含零月份）、本月分类占比、流水按日分组；POST 永不重复提交（超时先查那天的记录认领）。

## 安全约定

- Typecho 账号密码与站点接口密钥只存系统钥匙串（Keychain）。
- 站点密钥通过 `X-Noline-Key` 请求头发送，不进日志、不进 URL query。
- 三种 URL 形态（伪静态 / `index.php` / `?noline_api=`）自动探测并缓存。
- 403 二义性（密钥错 vs 站点只读）用 `GET /api/health` 判别后给出准确提示；401/403/404/405/500 不自动重试。

## 构建

不需要 Xcode 工程，SwiftPM 直接构建：

```sh
DEVELOPER_DIR=/Library/Developer/CommandLineTools ./Scripts/make_app.sh --open
```

产物在 `build/NLtypedesk.app`（ad-hoc 签名）。

> 如果本机装了完整 Xcode 但未同意许可，所有 `swift` / `git` 命令都要带
> `DEVELOPER_DIR=/Library/Developer/CommandLineTools` 前缀，或执行
> `sudo xcodebuild -license accept` 一劳永逸。

## 对接文档

- Typecho XML-RPC 方法签名以主题/插件源码为准（`var/Widget/XmlRpc.php`）。
- 站点数据接口见 NolineApi 插件的 App 对接文档（APP-API-SPEC）。

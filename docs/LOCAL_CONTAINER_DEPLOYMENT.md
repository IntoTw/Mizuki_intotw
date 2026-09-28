# 发布计划与决策

## 已确认

- 内容源：本地 notes/blog/content/posts，Markdown 原文件保持不变。
- 使用 Astro 静态构建，最终镜像仅 Nginx + dist，无 Node 运行服务。
- VPS 为 linux/amd64；本地 Mac 为 ARM。构建阶段使用本机平台，输出静态资源后打入 amd64 Nginx 镜像。
- 宿主机 Nginx 保留 HTTPS、证书续期与 WordPress 配置。未来仅切换网站处理规则。
- R2 图片 URL 继续沿用。当前不改变 DNS、CDN 和证书。
- 本轮用户要求仅本地构建与测试，不连接 VPS。
- 第一版 Compose 更新会重建单容器，不能承诺零中断。未来蓝绿发布另行实现。
- 暂不使用镜像仓库，远端预留 docker save/load 的 SSH 发布流程。
- 容器端口仅绑定 127.0.0.1；默认 8080。

## 实施顺序

1. 建立 Docker 多阶段构建、Nginx 配置、Compose 和本地发布脚本。
2. 先验证仓库现有内容能构建并运行，包括文章深层路由、404、静态资源和搜索索引。
3. 可选转换原笔记 frontmatter：date→published、lastmod→updated、featuredImage→image、categories 首项→category。原字段保留；不自动改正文和 URL。
4. 原笔记的短代码、链接和旧 WordPress URL 后续单独验收，不能把字段转换视为完整迁移。
5. 用户授权远端操作后，检查 Docker/Compose、端口及现有 Nginx/证书配置，再部署独立容器。
6. 另行切换主站入口，保留 WordPress 回退；接入 CDN 后再增加缓存刷新。

## 本地使用

```bash
# Docker Desktop 需启动
./scripts/deploy.sh build
./scripts/deploy.sh local
# http://localhost:8080
./scripts/deploy.sh stop
```

默认构建当前仓库文章，先验证主题。要使用原笔记：

```bash
cp deploy/local.env.example .deploy.env
# 从原笔记构建：将 CONTENT_SOURCE 设置为 /Users/chenxiang/Work/notes/blog/content/posts
# 后续从独立文章仓库构建：先克隆 blog_posts 到本项目同级目录，再设置 CONTENT_SOURCE=../blog_posts/posts
./scripts/deploy.sh build
./scripts/deploy.sh local
```

CONTENT_SOURCE 转换需要本地已安装项目依赖（pnpm install --frozen-lockfile）。整个构建使用临时目录，不覆盖仓库中的演示文章或原笔记。第一次下载 Node/Nginx 基础镜像和依赖可能较慢。

样式开发使用 `ENABLE_CONTENT_SYNC=false pnpm dev`（localhost:3000），支持实时更新；容器预览是正式构建快照，修改后必须重新 build 和 local。

## 预留远程命令（本轮不执行）

在 .deploy.env 配置 SSH_TARGET、REMOTE_DIR、BLOG_PORT。SSH 用户须有 Docker 权限，服务器需要 Compose v2（支持 --wait）、curl、flock。

```bash
./scripts/deploy.sh publish
./scripts/deploy.sh rollback
```

publish 先上传版本镜像，再更新独立 Compose 项目并检查健康；失败尝试恢复前一镜像。rollback 使用服务器记录的 previous。不会修改宿主机 Nginx、WordPress、DNS 或刷新 CDN。镜像、历史版本保留，不自动 prune。

部署脚本不会自动修改 siteURL、个人资料和演示页面。正式上线前必须核对这些设置。

## 缓存与限制

本阶段所有文件使用 Cache-Control: no-cache，优先保证预览一致性。未来全站 CDN 需单独制定 HTML、哈希资源和 Pagefind 缓存策略，并保留旧资源以兼容旧 HTML。单镜像替换尚未实现旧资源跨版本保留。

## 本轮验证记录

- amd64 与 arm64 镜像均完成生产构建，含 Pagefind 与字体检查。
- Apple Silicon 本地可执行 `PLATFORM=linux/arm64 ./scripts/deploy.sh build`，然后 `./scripts/deploy.sh local`。local 自动读取镜像架构。VPS 发布前执行默认 build 重新生成 amd64 镜像。
- 原笔记存在 TOML（+++）头部，转换使用 Python 3.11+ 的 tomllib。
- 原笔记 `ostep-15-Mechanism-Address-Translation.md` 使用 `ddtitle` 而非 `title`；临时转换器已兼容，原文件未改动。

本地启动后运行 `node scripts/check-local-blog.mjs`，检查首页、健康端点、文章、构建资源、Pagefind 和真实 404。

已验证：用户手动启动 Docker Desktop 后，ARM 镜像容器正常运行。仓库演示内容及 100 篇原笔记分别构建通过；真实内容镜像的首页、文章、字体、Pagefind、健康端点和 404 均通过 HTTP 检查。容器仅监听本机 127.0.0.1:8080。

### Docker 启动排查补充

先前由自动命令唤起的 Docker Desktop 无法启动任何容器；用户手动启动 Desktop 后恢复。`deploy.sh local` 最多等待 120 秒并返回明确错误，避免终端无限卡住。临时 4321 预览进程已按用户要求关闭。

### 真实内容迁移待处理

- 转换器只在临时目录中把 `ddtitle` 兼容为 `title`，并将 TOML 日期写成 Astro 可识别的 YAML 日期。原笔记未改动。
- `ostep-additional-mysql-page.md` 的 `date` 为无效的 `2024-05-124`；临时构建使用有效的 `lastmod` 并输出警告，正式发布前应修正原文。
- 三篇文章含 Hugo 的 `bilibili`/`admonition` 短代码，需转换并目视检查。
- 文章中仍有 `www.intotw.cn/年/月/日/slug/` 等旧链接；现有生成路径为 `/posts/slug/`。正式切换前要建立旧路径映射或重定向。
- 站点标题、正式域名、中文语言和作者已按旧站配置写入 `siteConfig.ts` 与 `profileConfig.ts`，RSS、分享链接和页面作者已在本地镜像中验证。
- `leetcode-1395.md` 的 `golang` 代码块降级成纯文本高亮，KaTeX 对少量中文数学文本发出警告，需检查对应文章。

### 2026-09-28 封面处理

- 原始笔记中 17 个 Markdown 文件的 34 处 `https://images.intotw.cn/` 已直接改为 `https://images.intotw.tech/`。
- 文章封面按显式封面、正文首图、默认图选取。旧 WordPress 的默认占位图会让位给正文首图；默认图 URL 在 `src/config/postCoverConfig.ts`。
- 使用 100 篇真实文章重新构建 ARM 本地镜像并运行；抽查正文首图、显式封面、无图默认封面的 `og:image`，均为预期 URL。`pnpm check` 为 0 错误、0 警告。

### 2026-09-28 站点身份与分享

- 原主题的 `siteURL` 为 `https://mizuki.mysqil.com/`，使静态分享组件复制演示域名；作者来自原主题的日文 `profileConfig.name`。
- 已设置正式站点 URL `https://www.intotw.cn/`、站点标题 `Intotw的博客`、语言 `zh_CN` 和作者 `intotw`；根据旧站 Hugo 配置移除主题作者的社交链接，仅保留当前 GitHub 账号。
- “其他博文精选”直接读取构建时的文章集合，链接为站内 `/posts/.../`，不依赖额外服务。本地镜像已验证其站内链接、分享组件 URL、作者 meta 和 RSS 域名。现有 WordPress 尚未切换，分享出的正式域名文章路径需等上线后才会指向新站。

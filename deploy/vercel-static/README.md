# Vercel 静态展示页

纯静态，无构建步骤、无依赖。目录结构：

```
deploy/vercel-static/
├── index.html      单页展示（改造说明 + 界面实录 + Vercel 可行性结论）
├── vercel.json     cleanUrls + 资源长缓存
└── assets/         4 张界面截图（1280 宽，JPEG）
```

## 为什么这里只有展示页

平台本体是 PHP 7.3 + Phalcon 3.4（C 扩展）应用，另需 MySQL 5.7、Redis 5、可写的
`storage/` 目录，以及常驻的 GatewayWorker 与定时调度器。Vercel 的运行时提供不了其中任何一项，
部署会在运行时直接失败（不是权限或账号问题）。完整论证见
`docs/源码核查与Vercel部署可行性.md` 第 5 节。

## 发布方式（二选一）

方式一，交互登录后发布：

```bash
npm i -g vercel
cd deploy/vercel-static
vercel login
vercel --prod
```

方式二，用 token 免交互发布：

```bash
cd deploy/vercel-static
vercel --prod --yes --token $VERCEL_TOKEN
```

首次发布会询问项目名与 scope，接受默认即可；产物是纯静态资源，不消耗函数额度。

## 本地预览

```bash
cd deploy/vercel-static
python -m http.server 8090
# 打开 http://127.0.0.1:8090
```

# MachKit website SEO playbook

Technical SEO (sitemap, canonical, hreflang, prerendered tool pages) is already in place. Use this checklist for discovery and growth.

## 1. Google Search Console (you must do this)

1. Open [Google Search Console](https://search.google.com/search-console) and add the property `https://machkit.app`.
2. Verify ownership (DNS TXT or HTML file upload via your host).
3. Submit sitemap: `https://machkit.app/sitemap.xml`.
4. After deploy, use **URL Inspection** on:
   - `https://machkit.app/`
   - `https://machkit.app/utilities/`
   - `https://machkit.app/tools/codec/`
   - `https://machkit.app/tools/cipher/`
   - `https://machkit.app/guides/local-vs-online-converters/`
   - matching `/zh-CN/...` URLs
5. Weekly: check **Pages** for “Crawled – currently not indexed” and fix only real blockers.

## 2. Demand-phrase pages (code)

High-intent titles/descriptions are customized for Codec, Cipher, and JSON Formatter. Prefer linking those deep URLs in posts:

- English: `/tools/codec/`, `/tools/cipher/`, `/tools/json-formatter/`
- Chinese: `/zh-CN/tools/codec/`, `/zh-CN/tools/cipher/`, `/zh-CN/tools/json-formatter/`
- Guide: `/guides/local-vs-online-converters/` and `/zh-CN/guides/local-vs-online-converters/`

## 3. Content follow-ups (optional next)

- One comparison post: open-source Mac cleaner vs paid cleaners (link `/features/storage-cleanup/`).
- One screenshot workflow post (link `/features/screenshot/`).
- Keep Chinese pages aligned with the same intents (`Mac 本地 Base64`, `开源 Mac 清理`).

## 4. Off-site signals (you must do this)

Post short, honest blurbs that link a **tool URL**, not only the homepage.

Suggested destinations:

- Product Hunt / AlternativeTo / Softpedia-style directories
- Reddit, Hacker News, Chinese developer communities
- GitHub Topics and awesome-mac style lists
- Release notes that mention Codec / Cipher with deep links

Example English blurb:

> MachKit is a free open-source Mac app with local tools (no upload). If you need Base64 / Data URI offline: https://machkit.app/tools/codec/ — AES/RSA local crypto: https://machkit.app/tools/cipher/

Example Chinese blurb:

> MachKit 是免费开源的 Mac 本地工具。本机 Base64 / Data URI：https://machkit.app/zh-CN/tools/codec/ — 本机 AES/RSA/国密：https://machkit.app/zh-CN/tools/cipher/

## Measurement

In Search Console, watch:

- High impressions + low CTR → rewrite title/description
- Queries with impressions → strengthen that tool/guide page lead
- No impressions → prioritize indexing + off-site links first

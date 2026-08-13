# 部落格多語文章整理方案

## 目標

在不拆成兩個 Jekyll 網站、不更換 Chirpy 主題、也不改寫既有文章網址的前提下，將中文與英文視為「同一篇文章的不同語言版本」。

完成後應有以下行為：

- 首頁、Archives、Category 與 Tag 等彙整頁面中，同一份內容只出現一次。
- 如果同一篇文章有英文版，彙整頁面優先顯示英文版，因為目前網站的預設語言是 `en`。
- 如果文章只有中文版或只有英文版，它仍會正常顯示，不會因為缺少翻譯而被隱藏。
- 文章頁頂部會列出實際存在的語言版本；只有一種語言時不產生無效連結。
- 加入翻譯時不必手動維護 URL 對照表，只要兩個版本使用相同的 `translation_key`。
- 搜尋引擎可以辨識各語言版本的關係，但每個版本仍保有自己的 canonical URL。

## 最小改動原則

本次不採用以下做法：

- 不建立 `/en/` 與 `/zh-TW/` 兩套完整網站。
- 不改變現有 permalink，避免既有連結失效。
- 不把語言放進 `categories` 或 `tags`；語言不是文章主題。
- 不使用前端 JavaScript 隱藏文章或自動重新導向，避免分頁、SEO 及無 JavaScript 環境出現不一致。
- 不複製或覆寫完整的 Chirpy `home` 與 `post` layout。
- 不要求每篇文章都必須有翻譯。

## 文章資料格式

每篇文章的 front matter 新增兩個欄位：

```yaml
content_lang: en
translation_key: hawkeye-keylogger
```

中文版使用：

```yaml
content_lang: zh-TW
translation_key: hawkeye-keylogger
```

規則：

- `content_lang` 目前只允許 `en` 或 `zh-TW`，不再使用非標準的 `ch`。
- 文章不要設定 `lang`；Chirpy 會將它解讀成整個頁面的介面語言。網站介面固定沿用全站 `lang: en`，只有正文依 `content_lang` 標記語言。
- `translation_key` 是文章內容的穩定 ID，不包含日期、語言或副檔名。
- 同一篇文章的不同語言版本必須使用相同的 `translation_key`。
- 即使文章目前只有一種語言，也應填寫 `translation_key`；日後新增翻譯時只要沿用它。
- 同一個 `translation_key` 下，每種語言最多只能有一篇文章。
- 後續檔名建議使用 `YYYY-MM-DD-slug-en.md` 與 `YYYY-MM-DD-slug-zh-tw.md`。現有檔名不重新命名，以免改變由檔名產生的 URL。
- 從 `tags` 移除現有的 `en`、`ch`；tags 只保留技術或主題資訊。
- 作者不需要自行設定 `hidden`，也不需要手動填寫另一語言的 URL。

目前文章的配對如下：

| `translation_key` | 英文 | 繁體中文 | 彙整頁代表版本 |
|---|---|---|---|
| `hawkeye-keylogger` | `2026-06-02-hawkeye-en.md` | `2026-06-02-hawkeye.md` | 英文 |
| `imminentrat-part-1` | `2026-07-22-ImminentRAT-1-en.md` | `2026-07-22-ImminentRAT-1-ch.md` | 英文 |
| `imminentrat-part-2` | 無 | `2026-07-27-ImminentRAT-2-ch.md` | 繁體中文 |

`imminentrat-part-2` 是單語文章的驗收案例：沒有英文版時，中文版必須出現在首頁及其他彙整頁面。

## 網站設定

在 `_config.yml` 加入集中式設定：

```yaml
multilingual:
  default_lang: en
  languages:
    - code: en
      label: English
      short_label: EN
    - code: zh-TW
      label: 繁體中文
      short_label: 中文
```

同時完成以下小幅調整：

- 保留全站 `lang: en` 作為所有頁面的介面語言；文章只用 `content_lang` 描述正文，不切換 Chirpy 介面。
- 將 `url` 設為正式站點 `https://kmes9940502.github.io`，讓 canonical 與 `hreflang` 產生絕對網址。
- 將 Gemfile 的 Chirpy 約束從 `~> 7.5` 收窄為 `~> 7.5.0`。本方案會對少數彙整 layout 做極小覆寫，限制 minor version 可避免 CI 在未審查時自動換成不相容的 layout。日後升級 Chirpy 時再人工比對這些覆寫。
- 保留 posts 的預設 `post` layout。Chirpy 會依 `page.layout == 'post'` 決定是否載入文章專用 CSS/JS，因此不使用會改變該值的 nested layout；改由 Jekyll render hook 暫時在正文前加入切換器，render 後立即還原原始 content。

## 自動配對與彙整頁去重

新增 `_plugins/multilingual-posts.rb`，在 Jekyll 讀取文章後執行。它只整理文章 metadata，不修改 Markdown 原始檔。

處理流程：

1. 驗證每篇文章都有合法的 `content_lang` 與 `translation_key`。
2. 依 `translation_key` 分組。
3. 拒絕同一組內重複的語言，因為這會造成語言切換連結不明確。
4. 將同組文章依 `_config.yml` 的語言順序排列，寫入各文章的 `translations` metadata，供 Liquid template 使用。
5. 選出彙整頁的代表版本：優先使用 `multilingual.default_lang`；若沒有預設語言版本，使用設定中第一個實際存在的語言版本。
6. 只有一種語言的組合，該文章就是代表版本。
7. 對非代表版本在建置期間設定 `hidden: true`；代表版本保留可見。這會讓 Chirpy 首頁沿用原生 hidden 機制去重，但每個語言版本的文章頁仍會正常輸出。
8. `pin` 視為整篇內容的狀態：同組任一版本設定 `pin: true` 時，只讓代表版本在首頁保持 pinned，避免兩個語言版本同時出現。
9. 作者原本明確設定的 `hidden: true` 應保留；外掛不可把作者刻意隱藏的文章重新公開。

錯誤策略：

- 文章設定了 page-level `lang`、缺少 `content_lang`、缺少 `translation_key`、未知語言，或同一組有重複語言時，直接讓 build 失敗並顯示包含檔名的清楚訊息。
- 某個翻譯不存在不是錯誤，也不應產生 warning。

## 彙整頁面的行為

Chirpy 7.5 的首頁已支援 `hidden: true`，因此不覆寫 `_layouts/home.html`。

Archives、單一 Category 與單一 Tag 頁面若沒有套用 `hidden` 過濾，則只覆寫以下三個必要 layout：

- `_layouts/archives.html`
- `_layouts/category.html`
- `_layouts/tag.html`

實作時先從實際安裝的 Chirpy `7.5.x` 複製對應檔案，再只對文章集合加入 `post.hidden != true` 條件，不重新設計 HTML。若該版本原本已過濾 hidden，就不要新增無作用的覆寫。

保留以下刻意行為：

- sitemap 應包含所有語言版本，讓搜尋引擎可以索引每個翻譯。
- 語言文章頁應各自保有 categories 與 tags。
- 語言專頁與文章切換器必須能讀到 hidden 的翻譯版本；不能只從首頁可見文章中查找。
- 網站搜尋可保留所有語言版本，讓使用者能用中文或英文內容搜尋。若 Chirpy 的原生搜尋自動排除 hidden，初版不為此覆寫整套搜尋功能。

## 文章頁語言切換器

新增 `_includes/language-switcher.html`。`_plugins/multilingual-posts.rb` 會在單篇文章的 `pre_render` 階段暫時把 include 放到正文之前，並依 `content_lang` 產生帶有正確 `lang` attribute 的正文容器，再於 `post_render` 還原原始 content。這樣不必覆寫 Chirpy 的完整 post layout、不會讓語言切換器文字進入首頁摘要，也不會改變網站介面語言。

切換器規格：

- 放在文章正文最上方、標題資訊之後。
- 顯示設定中所有「實際存在」的語言版本。
- 目前語言顯示為不可點擊的 active 標籤，其他語言是直接連到對應文章的連結。
- 使用 Chirpy 已載入的 Bootstrap utility/button class，不為這個元件建立一整份自訂 CSS。
- 加入適當的 `aria-current="page"`，並提供可理解的輔助文字。
- 只有一種語言時顯示 `Available in: English` 或 `提供語言：繁體中文`，不顯示不存在語言的 disabled link，也不連回首頁。
- 如果日後增加第三種語言，只需更新 `_config.yml` 並新增相同 `translation_key` 的文章，template 不應寫死兩種語言。

## 語言瀏覽頁

新增一個側欄 tab，讓讀者能主動依語言瀏覽：

- `_tabs/languages.md`
- `_layouts/languages.html`

頁面需求：

- 標題為 `Languages`，沿用 Chirpy 的 page layout。
- 依 `_config.yml` 的語言順序分為 `English` 與 `繁體中文` 兩區。
- 每區列出該語言的所有文章，包含在首頁被 hidden 的翻譯版本。
- 顯示文章標題與日期；可沿用 Chirpy 既有 class，不新增 JavaScript。
- 單語文章只出現在它實際具有的語言區。
- 不建立空語言區；某語言沒有文章時略過。

此頁負責「按語言分類」；原本的 Category 和 Tag 繼續只負責「按主題分類」。

## 多語 SEO

透過 Chirpy 7.5 官方預留的 `_includes/metadata-hook.html`，在文章 `<head>` 加入：

```html
<link rel="alternate" hreflang="en" href="...">
<link rel="alternate" hreflang="zh-TW" href="...">
<link rel="alternate" hreflang="x-default" href="...">
```

規則：

- 只為實際存在的語言輸出 alternate link。
- `x-default` 指向該組的彙整頁代表版本。
- 單語文章只輸出自身語言與指向自身的 `x-default`。
- URL 必須是絕對網址，且尊重 `site.baseurl`。
- 不把中文版 canonical 到英文版，也不把英文版 canonical 到中文版；每個版本保留 Chirpy/Jekyll SEO Tag 產生的 self-canonical。
- 頁面層級的 `<html lang>` 固定沿用全站 `en`，使 Chirpy 導覽及其他介面保持英文；文章正文另以 `<div lang="...">` 標記實際內容語言。
- metadata hook 是唯一的 `hreflang` 輸出位置，避免重複輸出。

## 新增文章的日常流程

在 README 新增一段簡短的「Multilingual posts」說明，作者只需遵循以下流程。

只有一種語言的新文章：

```yaml
---
title: "文章標題"
date: 2026-08-13
content_lang: zh-TW
translation_key: stable-topic-name
categories: [Reverse Engineering]
tags: [Malware]
---
```

日後補翻譯：

1. 複製文章成另一個語言檔案。
2. 修改 `title`、`content_lang` 與正文。
3. 保留相同的 `translation_key`。
4. 不設定 `hidden`，不填另一篇的 URL，也不修改任何 data file。

外掛會在下一次 build 自動完成配對、首頁代表版本選擇、語言切換與 `hreflang`。

## 預計變更檔案

必要變更：

- 修改 `_config.yml`
- 修改 `Gemfile`
- 修改現有五篇 `_posts/*.md` 的 `content_lang` 與其他 front matter
- 新增 `_plugins/multilingual-posts.rb`
- 新增 `_includes/language-switcher.html`
- 新增 `_includes/metadata-hook.html`
- 新增 `_tabs/languages.md`
- 新增 `_layouts/languages.html`
- 更新 `README.md` 的發文說明

條件式變更（只有 Chirpy 原版未過濾 hidden 時才新增）：

- `_layouts/archives.html`
- `_layouts/category.html`
- `_layouts/tag.html`

不變更：

- 文章正文
- 既有圖片與圖片路徑
- 現有 permalink 規則
- 既有文章檔名
- GitHub Actions 部署流程
- Chirpy 的首頁與完整 post layout

## 實作順序

1. 確認 Chirpy 7.5 實際 layout 與 `hidden` 行為，並將 Gemfile 限制在相容版本。
2. 加入 `_config.yml` 的多語設定及正式 `url`。
3. 更新五篇文章的 `content_lang`、`translation_key` 與語言 tags。
4. 實作並測試 multilingual plugin 的驗證、配對與代表版本，並透過 metadata hook 加入 SEO alternate links。
5. 透過 render hook 加入語言切換器，並保留原生 post layout。
6. 加入 Languages tab。
7. 只在必要處為 Archives、Category、Tag 加上 hidden 過濾。
8. 更新 README 作者流程。
9. 執行完整 build、HTML 驗證與輸出內容檢查。

## 驗收與測試

至少完成以下檢查：

1. `bundle exec jekyll build` 成功。
2. `bundle exec htmlproofer _site --disable-external` 成功；參數應與 CI 保持一致。
3. 首頁只出現一次 HawkEye、一次 ImminentRAT Part 1，以及中文版 ImminentRAT Part 2。
4. Archives、Reverse Engineering category 及相關 tag 不重複列出同內容的兩個語言版本。
5. Languages 頁英文區列出兩篇現有英文文章，繁中區列出三篇現有中文文章。
6. HawkEye 與 ImminentRAT Part 1 的中英文文章可互相切換。
7. ImminentRAT Part 2 顯示只有繁中可用，且沒有死連結或虛構的英文網址。
8. 所有頁面的網站介面與 `<html lang>` 保持英文；中文文章正文容器輸出 `lang="zh-TW"`，英文正文輸出 `lang="en"`。
9. 雙語文章輸出兩個語言的 `hreflang` 及正確的 `x-default`；單語文章只輸出實際存在的語言。
10. 每個語言版本的 canonical 指向自己。
11. 現有文章 URL 全部維持可訪問，不因本次修改產生 redirect requirement。
12. 暫時把一篇測試文章設為只有英文或只有中文時，build 仍成功且彙整頁仍會顯示它。
13. 測試誤用 page-level `lang`、缺少 `content_lang`、缺少 `translation_key` 與重複 `(translation_key, content_lang)` 時，build 會給出含檔名的明確錯誤。

如果本機仍沒有 Ruby/Bundler，應完成可進行的靜態檢查，並以 GitHub Actions 的 build 與 htmlproofer 作為最終驗證；不可宣稱未實際執行的測試已通過。

## 完成定義

只有在下列條件全部成立時才算完成：

- 雙語內容在一般彙整頁只顯示一次。
- 單語文章不會消失。
- 每篇文章能正確顯示目前可用的語言。
- 新增翻譯只需要設定 `content_lang` 與共用 `translation_key`，網站介面語言不受影響。
- 不破壞舊網址。
- 沒有用大規模 fork Chirpy layout 的方式完成。

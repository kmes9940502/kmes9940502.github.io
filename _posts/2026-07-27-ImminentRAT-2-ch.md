---
title: "ImminentRAT 樣本分析(下篇)"
date: 2026-07-27
categories: [Reverse Engineering]
tags: [Borland Delphi, C#, Galaxy Logger, ImminentRAT, ch]
---


# 概要:
銜接上篇，接下來分析其中的三個載荷
(三個載荷各自還有 Packer/Loader 但主要都是從 resource 解密 Payload 的流程。因篇幅關係不過多贅述)

# 深度分析

## Galaxy Logger V3
第一個 payload 為 Galaxy Logger V3，從許多發送 message 到伺服器的行為便可知
![alt text](../assets/img/posts/2026-07-27-ImminentRAT-Part2/Snipaste_2026-07-27_02-04-03.png)

這裡顯示版本號為 V3.6
![alt text](../assets/img/posts/2026-07-27-ImminentRAT-Part2/v36.png)

這是2015年的老 KeyLogger 了，沒想到也出現在這個組合包中
![alt text](../assets/img/posts/2026-07-27-ImminentRAT-Part2/Family.png)

接下來就針對幾個主要功能說明

### RuneScape PIN

針對 [Old School RuneScape](https://en.wikipedia.org/wiki/Old_School_RuneScape) 這款遊戲竊取其中的 PIN 碼，因為作者沒玩過這款遊戲猜測應該是銀行系統之類的東西
![遊戲中類似銀行PIN碼的設計](../assets/img/posts/2026-07-27-ImminentRAT-Part2/settingpin5.png)

Galaxy Logger 會尋找 RuneScape 的視窗特徵、偵測 PIN pad 畫面、啟用MouseHook、在玩家點擊後截圖並上傳

尋找視窗特徵 : Logger 會搜尋 Window 上的字串，符合特徵回傳`True`
![alt text](../assets/img/posts/2026-07-27-ImminentRAT-Part2/Snipaste_2026-07-27_02-42-42.png)

若搜尋不到字串也會檢測 Java 的 `SunAwtCanvas`




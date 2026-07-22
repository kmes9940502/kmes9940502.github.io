---
title: "ImminentRAT 分析(上篇)"
date: 2026-07-22
categories: [Reverse Engineering]
tags: [Borland Delphi, yara, ImminentRAT, ch]
---


# 概要:
根據 VirusTotal 上的紀錄這支樣本最早在2017年被發現，MalwareBazaar 顯示樣本在2023-12-06被上傳到資料庫

這隻樣本套了好幾層 Loader，並且最終的 Payload 使用了自定義的 Confuser 混淆，篇幅有點長所以會分成兩篇來寫

# 深度分析
## Road Map
### MD5:
原始樣本: 939aa21bbb29c3a09dfd80c155a8a63e

## Delphi Loader
原始樣本為一隻 Borland Delphi 寫成的Loader 
![alt text](../assets/img/posts/2026-07-22-ImminentRAT/DIE_Init.png)
樣本偽裝成 MalwareBytes 的反病毒軟體誘騙使用者打開
![alt text](../assets/img/posts/2026-07-22-ImminentRAT/init_property.png)
Delphi 首先會呼叫 InitExe() 進行 unit initialization，遍歷一個 table 中的 function。惡意代碼很常被夾帶在這裡執行
![alt text](../assets/img/posts/2026-07-22-ImminentRAT/Snipaste_2026-07-22_16-53-02.png)
在 Table 末尾處的 function `sub_45B93C` 就是 loader 的主邏輯
![alt text](../assets/img/posts/2026-07-22-ImminentRAT/init_initTable.png)

主邏輯中呼叫了許多無意義操作，並且有大量空迴圈來拖延時間
![alt text](../assets/img/posts/2026-07-22-ImminentRAT/Snipaste_2026-07-22_17-05-18.png)

解密流程為 `0x45B894` -> `0x45B794`
`0x45B794` 負責解密並將下一段Payload載入記憶體。Payload長度為`0x65E4`
![alt text](../assets/img/posts/2026-07-22-ImminentRAT/Snipaste_2026-07-22_17-26-44.png)
`0x45B5AC` 是一個變種 RC4 算法。因為是 Loader 的部分，我們盡量只關注取得下一段 Payload 避免太過深究，算法細節就不多做贅述了。

在動態分析的時候直接改 EIP 跳過大迴圈，執行到載入記憶體(0x45B862)就可以拿到下一段Payload，Payload是一隻shellcode，進入點在0x4BE7
## Shellcode


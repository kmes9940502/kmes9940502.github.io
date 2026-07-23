---
title: "ImminentRAT 分析(上篇)"
date: 2026-07-22
categories: [Reverse Engineering]
tags: [Borland Delphi, yara, ImminentRAT, ch]
---


# 概要:
根據 VirusTotal 上的紀錄這支樣本最早在2017年被發現，MalwareBazaar 顯示樣本在2023-12-06被上傳到資料庫

這隻樣本套了好幾層 Loader，並且最終的 Payload 使用了自定義的 ConfuserEX 混淆，篇幅有點長所以會分成兩篇來寫

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

在動態分析的時候直接改 EIP 跳過大迴圈，執行到載入記憶體(0x45B862)就可以拿到下一段Payload，Payload是一隻shellcode，進入點在0x42B7
![VirtualAlloc base + 0x42B7](../assets/img/posts/2026-07-22-ImminentRAT/Snipaste_2026-07-22_18-06-11.png)
Loader將跳轉地址寫到 `VirtualAlloc base + 0x42B7`
![alt text](../assets/img/posts/2026-07-22-ImminentRAT/Snipaste_2026-07-22_18-06-45.png)
## Shellcode Loader
### 靜態分析
Shellcode 使用大量跳躍與 `0x78` 混淆，好在IDA Pro可以成功辨識大部分的function範圍
首先從入口點一路跳轉到 `0xD94` 後呼叫 `0x1B1C` 初始化 API
API 列表可以用動態分析解出來，寫成 struct 匯入 IDA 協助分析。還原效果大致長這樣
![alt text](../assets/img/posts/2026-07-22-ImminentRAT/Snipaste_2026-07-22_20-26-26.png)

進入主邏輯的流程如下:
```
42B7 → F59 → 4549 → 4F27 → D94
     → 460A → 9E0
     → 4262 → 4277
     → 4C2 → 371B → 3A78
     → CB5
     → 117 → 3CF0 → 5E7F → 5690
```
主流程末尾會對下一段 Payload 進行 RC4 解密，並 Process Hollowing 載入下一段載荷
![alt text](../assets/img/posts/2026-07-22-ImminentRAT/Snipaste_2026-07-22_22-32-42.png)
`0x21A9` 檢查完下一段 payload 開頭(為一個執行檔)後進行 Process Hollowing
![alt text](../assets/img/posts/2026-07-22-ImminentRAT/process_hollowing.png)

### 反沙箱/Debug功能:
`0x1ABA`: VM driver 檢查
![alt text](../assets/img/posts/2026-07-22-ImminentRAT/Snipaste_2026-07-22_21-30-58.png)
`0x61E4`: username 沙箱檢查
![alt text](../assets/img/posts/2026-07-22-ImminentRAT/Snipaste_2026-07-22_21-23-10.png)
`0x5D34`: PhysicalDrive0 虛擬機檢查
![alt text](../assets/img/posts/2026-07-22-ImminentRAT/Snipaste_2026-07-22_21-22-28.png)

### 動態分析
動態分析時，因為 Shellcode 會從初始樣本中提取 Resource，所以要從原樣本開始分析讓 shellcode 解密 resource
繞開反分析檢查:
```
base + 0x9E0: 修改 EAX 為 0 繞過第一個檢查
base + 0xCB9: 修改 [esi+2CCh] 為 0 規避 driver 檢測
base + 0x4874: 修改 [esi+310h] 為 0 規避主流程內的 VM 檢測
```
可以讓代碼執行到 `0x34D6` 或 `0x21A9` dump 出下一段 Payload
大小為 RC4 的argument `[eax+20]`
![alt text](../assets/img/posts/2026-07-22-ImminentRAT/Snipaste_2026-07-22_23-16-07.png)
可以看到下一段Payload已被載入到記憶體中
![alt text](../assets/img/posts/2026-07-22-ImminentRAT/Snipaste_2026-07-22_23-17-30.png)

dump出來就可以得到下一段執行檔

## Second Payload
原始 Payload 用一層 UPX 壓縮，依舊是一個 loader，裡面放了三個 payload
![alt text](../assets/img/posts/2026-07-22-ImminentRAT/Snipaste_2026-07-22_23-40-08.png)

這一層 Loader 相對簡單，取出 resource 中的三個載荷並執行

![alt text](../assets/img/posts/2026-07-22-ImminentRAT/Snipaste_2026-07-22_23-50-28.png)

三個 payload 都是 Borland Delphi 的殼，也就是開頭的 Loader，重複一次步驟再拿到下一段 Payload (依舊有套殼)

## 小結
這隻樣本一共有三隻 Malware，各種殼層層嵌套，還有自訂義的 ConfuserEX 混淆，分析起來實在有點麻煩。於是如何避免太過深入的分析不必要的部分，節省時間保存精力是個必須持續學習的課題




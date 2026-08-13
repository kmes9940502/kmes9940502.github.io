---
title: "ImminentRAT 樣本分析(Galaxy Logger V3)"
date: 2026-07-27
lang: zh-TW
translation_key: imminentrat-part-2
categories: [Reverse Engineering]
tags: [Borland Delphi, C#, Galaxy Logger, ImminentRAT]
---


# 概要:
銜接上篇，接下來分析三個載荷的其中一個
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
![alt text](../assets/img/posts/2026-07-27-ImminentRAT-Part2/Snipaste_2026-07-27_02-48-14.png)

接下來檢測是否在 PIN pad、檢測到畫面就啟用 MouseHook
![alt text](../assets/img/posts/2026-07-27-ImminentRAT-Part2/Snipaste_2026-07-27_02-50-59.png)

檢測 Pinpad 片段:
![alt text](../assets/img/posts/2026-07-27-ImminentRAT-Part2/Snipaste_2026-07-27_02-52-07.png)
Base64 編碼的image解出來長這樣(用來檢測按鈕邊界):
![alt text](../assets/img/posts/2026-07-27-ImminentRAT-Part2/Snipaste_2026-07-27_02-41-14.png)
啟用 MouseHook
![alt text](../assets/img/posts/2026-07-27-ImminentRAT-Part2/Snipaste_2026-07-27_02-56-26.png)
集滿四張圖片就上傳到C2
![alt text](../assets/img/posts/2026-07-27-ImminentRAT-Part2/Snipaste_2026-07-27_03-05-15.png)
這邊見到第一個 C2: `http://uploads[.]im/api?upload`
![alt text](../assets/img/posts/2026-07-27-ImminentRAT-Part2/Snipaste_2026-07-27_03-06-12.png)

### PWS.bin Loader

Logger 下載了一個名為`PWS.bin`的檔案，寫到`/stext \<tempfile>`中進行process hollowing啟動
這邊找到第二個 C2: `http://galaxysproducts[.]com/pws/PWS[.]bin`
![alt text](../assets/img/posts/2026-07-27-ImminentRAT-Part2/Snipaste_2026-07-27_03-17-06.png)
隨機選擇 `MSBuild`、`InstallUtil`、`RegAsm`做為目標
![alt text](../assets/img/posts/2026-07-27-ImminentRAT-Part2/Snipaste_2026-07-27_03-21-09.png)
Process Hollowing的證據
![alt text](../assets/img/posts/2026-07-27-ImminentRAT-Part2/Snipaste_2026-07-27_03-23-19.png)

啟動後解析許多欄位，推測是用來竊取瀏覽器密碼的功能
![alt text](../assets/img/posts/2026-07-27-ImminentRAT-Part2/Snipaste_2026-07-27_03-26-12.png)

### 解密

解密 Script 放在 [這裡](https://github.com/kmes9940502/malware-detection-rules/blob/main/malware/Galaxy_Logger_V3/scripts/decrypter.cs)，找個Online C# compiler 就可以跑。
各類金鑰、C2 indicator都放在 `Token: 0x04000003` 附近
![alt text](../assets/img/posts/2026-07-27-ImminentRAT-Part2/Snipaste_2026-07-27_04-15-34.png)

解密大量Config
![alt text](../assets/img/posts/2026-07-27-ImminentRAT-Part2/Snipaste_2026-07-27_04-19-15.png)

解出來的C2 有:
```
tony@rixcsgsm[.]com
smtp.rixcsgsm[.]com
ftp.host[.]com
http://galaxysproducts[.]com/testpanel
```

### 其他 C2
在 `Token: 0x0600000A` 呼叫另一個 C2 用以查詢受害者的 IPv4 地址
![alt text](../assets/img/posts/2026-07-27-ImminentRAT-Part2/Snipaste_2026-07-27_04-29-58.png)
![alt text](../assets/img/posts/2026-07-27-ImminentRAT-Part2/Snipaste_2026-07-27_04-31-01.png)

C2: `http://ip4.telize[.]com/`

## IOCs
### C2 Indicators
```
http://uploads[.]im/api?upload
http://galaxysproducts[.]com/pws/PWS.bin
tony@rixcsgsm[.]com
smtp[.]rixcsgsm.com
ftp"//ftp[.]host.com
http://galaxysproducts[.]com/testpanel
ip4[.]telize.com
```

**下篇分析另一個 Payload**

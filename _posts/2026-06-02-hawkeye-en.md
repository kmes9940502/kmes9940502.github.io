---
title: "In-Depth Analysis of the HawkEye Keylogger"
date: 2026-06-02
content_lang: en
translation_key: hawkeye-keylogger
categories: [Reverse Engineering]
tags: [C#, AutoIt, yara, HawkEye]
---

# Background

As part of extending my work into detection engineering, I worked through the **HawkEye Lab** on CyberDefenders. From the provided packet capture I extracted a malware sample. The scenario describes a victim who opened a phishing email, which caused the malware to be downloaded onto the host.

![wireshark_export_file](../assets/img/posts/2026-06-02-hawkeye/Q15_2.png)

This post documents the full analysis from the loader to the payload, and is the first entry in a detection research series that I plan to keep updating.

# Overview

HawkEye Keylogger is a long-running keylogger written in C#. Its earliest campaigns date back to 2016, and the sample analyzed here is already version 9. VirusTotal records renewed activity in 2023, spread through phishing emails. Its main capabilities include stealing device information, logging keystrokes, taking screenshots, and even recording the victim's webcam.

# Deep Analysis

## Loader

The executable obtained from Wireshark is a loader written in **AutoIt 3**.

![Detect It Easy result for the loader](../assets/img/posts/2026-06-02-hawkeye/DIE_tkraw.png)

We can recover the AutoIt script with [unAutoIt](https://github.com/digitalsleuth/UnAutoIt). The content is shown below:

![Recovered AutoIt script](../assets/img/posts/2026-06-02-hawkeye/Autoit.png)

Besides obfuscating variable and string names, the script uses two functions to obfuscate strings.

![String obfuscation functions](../assets/img/posts/2026-06-02-hawkeye/obf.png)

These two functions are used heavily throughout the script to obfuscate all strings and byte arrays. By following the logic of these two functions, we can write a script to decode them. The script is available in my repo.

The loader decrypts the resources **hvax641** and **pcalua2** into the malware payload.

![Decrypting the embedded resources](../assets/img/posts/2026-06-02-hawkeye/dec_resource.png)

The resource decryption function:

![Resource decryption function](../assets/img/posts/2026-06-02-hawkeye/decrypt_resource_function.png)

The shellcode then performs process hollowing on `RegAsm.exe` to inject and run the malware.

![Process hollowing routine](../assets/img/posts/2026-06-02-hawkeye/process_holowing.png)

After deobfuscation we obtain the shellcode:

![Recovered shellcode](../assets/img/posts/2026-06-02-hawkeye/shellcode_sig.png)

The hardcoded shellcode starts with:

```text
55 8B EC 8B 4D 08 ...
```

Here, `55 8B EC` is a typical 32-bit x86 function prologue:

```asm
push ebp
mov  ebp, esp
```

When injecting the shellcode, the `DllCallAddress` parameters show that the shellcode entry point is at `0xBE`.

![Shellcode injection parameters](../assets/img/posts/2026-06-02-hawkeye/shellcode_loading.png)

Three arguments are passed in. The actual values are:

```text
arg1 = 'C:\Windows\Microsoft.NET\Framework\v2.0.50727\RegAsm.exe'
arg2 = ''
arg3 = decrypted .NET PE bytes (hvax641 + pcalua2)
```

![The three loader arguments](../assets/img/posts/2026-06-02-hawkeye/loader_3args.png)

## Shellcode

In IDA, the reconstructed function at `0xBE` also takes three arguments, which confirms that this is the shellcode entry point.

![Shellcode entry point in IDA](../assets/img/posts/2026-06-02-hawkeye/IDA_shellcode_args.png)

It reads the `IMAGE_DOS_HEADER` information from the malware payload.

![Reading the DOS header](../assets/img/posts/2026-06-02-hawkeye/IDA_shellcode_load_dos_header.png)

It then performs process hollowing. Here it calls `CreateProcessW` to start `RegAsm.exe` with `dwCreationFlags` set to 4, which is `CREATE_SUSPENDED`.

![CreateProcessW call with CREATE_SUSPENDED](../assets/img/posts/2026-06-02-hawkeye/IDA_shellcode_createprocess_hollowing.png)

At this point the behavior is clear. Readers who want to go further can [download the sample](https://github.com/kmes9940502/malware-detection-rules/blob/main/malware/HawkEye_SMTP.zip) for a deeper analysis.

## Payload

Loading the payload into DIE shows that it is written in C# and obfuscated with ConfuserEx, which can be deobfuscated directly with de4dot.

![DIE result for the payload](../assets/img/posts/2026-06-02-hawkeye/DIE_decrypt_from_resource.png)

The deobfuscated code:

![Deobfuscated payload in dnSpy](../assets/img/posts/2026-06-02-hawkeye/dnspy_main.png)

The sample is now fully recovered, so we can run it through CAPA.

![CAPA output](../assets/img/posts/2026-06-02-hawkeye/capa_geo.png)

CAPA identifies many capabilities, and it is very useful for triaging an unpacked sample. It also produces false positives, so manual review is still needed. For example, the function above that CAPA labels as geolocation is in fact a POST request used to send collected data back. The sample provides four methods for exfiltrating data, grouped in class `0x02000033`.

![POST exfiltration code](../assets/img/posts/2026-06-02-hawkeye/capa_geo_code.png)

This sample uses SMTP to send data back, in function `0x06000177`. The code is shown below:

![SMTP exfiltration routine](../assets/img/posts/2026-06-02-hawkeye/dnspy_SMTP.png)

The behavior matches the log provided in the lab, where the payload IP was identified using an IP lookup service.

![IP lookup behavior](../assets/img/posts/2026-06-02-hawkeye/dnspy_iplookup.png)

The C2 configuration is decrypted from the `RCDATA` resource through `0x0600036C`.

Key: `0cd08c62-955c-4bdb-aa2b-a33280e3ddce`

![C2 decryption](../assets/img/posts/2026-06-02-hawkeye/dnspy_decrypt_c2.png)

The decryption function:

![Decryption function](../assets/img/posts/2026-06-02-hawkeye/dnspy_crypto_algo.png)

Algorithm settings (AES decryption):

```text
Key/password:
0cd08c62-955c-4bdb-aa2b-a33280e3ddce

Cipher:
RijndaelManaged
Key size: 256-bit
Block size: 128-bit
Mode: CBC
Padding: PKCS7
```

![Cipher configuration](../assets/img/posts/2026-06-02-hawkeye/dnspy_crypto_algo2.png)

The decrypted `RCDATA`:

![Decrypted RCDATA](../assets/img/posts/2026-06-02-hawkeye/RCDATA_dec.png)

After deserialization we can recover the C2 details:

```text
SMTP server: macwinlogistics[.]in
SMTP user:   sales.del@macwinlogistics.in
SMTP pass:   Sales@23
SMTP port:   587
SSL:         false
```

## Other Capabilities

* Webcam capture (`0x0600034B`):
![Webcam capture](../assets/img/posts/2026-06-02-hawkeye/dnspy_webcam.png)
* Screenshot (`0x060002A9`):
![Screenshot routine](../assets/img/posts/2026-06-02-hawkeye/dnspy_screenshot.png)
* System information collection (`0x0600024D`):
![System information collection](../assets/img/posts/2026-06-02-hawkeye/dnspy_info_gather.png)
* Keylogging through system event hooks (`0x060001E7`):
![Keylogger via Windows hooks](../assets/img/posts/2026-06-02-hawkeye/dnspy_windows_keylogger.png)

There are many more functions. For a deeper analysis, please [download the sample](https://github.com/kmes9940502/malware-detection-rules/blob/main/malware/HawkEye_SMTP.zip).

## Conclusion

This analysis followed the full chain, from the AutoIt loader to the injected shellcode and finally the C# payload. The key stages were resource decryption, process hollowing into `RegAsm.exe`, AES-based C2 decryption from `RCDATA`, and the main surveillance features such as keylogging, screenshots, webcam capture, and system information collection.

CAPA proved very useful for quickly mapping the capabilities and locations of components in an unpacked sample. At the same time, manual verification is still necessary, since the tool can misclassify functions, as seen with the supposed geolocation routine that was actually a data exfiltration POST request.

# Local Audio PiP Translator

โปรเจกต์นี้เพิ่มต้นแบบ **iOS local realtime audio translator** สำหรับกรณี “ฟังเสียงเพลง/เกมแล้วแปลขึ้นหน้าจอแบบ PiP/floating overlay” พร้อม workflow บน GitHub Actions macOS เพื่อ build ไฟล์ `.ipa` แบบ unsigned

> หมายเหตุสำคัญ: iOS ไม่อนุญาตให้แอปทั่วไปดักฟังเสียง system audio ของแอปอื่นแบบเงียบ ๆ โดยตรง การทำให้ถูกต้องต้องใช้ไมโครโฟน, audio session ที่ผู้ใช้อนุญาต, หรือ ReplayKit Broadcast Extension ที่ผู้ใช้เริ่มเอง ส่วน PiP จริงของ iOS ต้องอิง video layer; ในต้นแบบนี้จึงทำ floating overlay ในแอป, เพิ่ม voice translation ด้วย Text-to-Speech, และวางโครงต่อยอดไป Broadcast Extension/AVPictureInPictureController ภายหลัง

## มีอะไรใน repo นี้

- `ios/LocalAudioPiPTranslator.xcodeproj` — Xcode project สำหรับ iOS app
- `ios/LocalAudioPiPTranslator` — SwiftUI app ที่มี UI สำหรับเริ่ม/หยุดการฟังเสียง, แสดง transcript, แปล local dictionary, floating overlay, ReplayKit picker และ PiP subtitle controller
- `ios/LocalAudioBroadcastExtension` — Broadcast Upload Extension scaffold สำหรับรับ `audioApp`, `audioMic` และ `video` sample buffers จาก Screen Recording ที่ผู้ใช้กดเริ่มเอง
- `ios/Shared` — โครง shared App Group payload สำหรับส่งซับ/คำแปลล่าสุดจาก extension กลับเข้าแอปหลัก
- `ios/Scripts/build_unsigned_ipa.sh` — script สร้าง unsigned `.ipa` จาก command line บน macOS/Xcode
- `.github/workflows/ios-unsigned-ipa.yml` — GitHub Actions workflow ใช้ runner macOS build แล้วอัปโหลด unsigned IPA artifact
- เว็บเดโมเดิมยังอยู่ที่ `index.html`, `src/main.js`, `src/styles.css` และยังตรวจ syntax ได้ด้วย `npm run build`

## ความสามารถของ iOS app ต้นแบบ

- SwiftUI interface สำหรับ “Local Audio PiP Translator”
- ขอสิทธิ์ Microphone และ Speech Recognition ครบก่อนเริ่มฟัง
- ใช้ `SFSpeechRecognizer` พร้อม `requiresOnDeviceRecognition = true` เพื่อบังคับแนวทาง local-first เท่าที่อุปกรณ์รองรับ
- เลือกภาษาต้นทาง/ปลายทางได้ เช่น Auto, English, Japanese, Korean, Chinese, Thai
- แปลข้อความด้วย dictionary ในเครื่องก่อน และ fallback เป็นข้อความ `[Language] ...` เพื่อไม่ออก network
- แปลเสียงได้จริงในต้นแบบ: เมื่อมีประโยคใหม่ แอปใช้ `AVSpeechSynthesizer` อ่านคำแปลออกเสียงตามภาษาปลายทาง
- Floating subtitle แบบ PiP-style ภายในแอป พร้อมปรับขนาดตัวอักษร สีพื้นหลัง และเปิด/ปิดเสียงแปล
- Conversation history สำหรับดูประโยคต้นฉบับ/คำแปลย้อนหลัง
- ปุ่ม `Demo voice` สำหรับจำลองประโยคเกม/เพลงในเครื่อง
- โหมดเลือก `ReplayKit / Screen Recording` พร้อม `RPSystemBroadcastPickerView` เพื่อให้ผู้ใช้เริ่ม Broadcast ผ่าน UI ทางการของ iOS
- Broadcast Upload Extension target ที่รับ `audioApp`, `audioMic`, `video` sample buffers แล้วเขียน subtitle payload ผ่าน App Group
- PiP subtitle renderer scaffold ที่ render ข้อความแปลลงใน sample-buffer video stream สำหรับ `AVPictureInPictureController`


## แนวทางเทียบกับแอปแนว ViiTor

ต้นแบบนี้เน้น flow ที่ผู้ใช้คาดหวังจากแอป live subtitle/voice translator:

1. ฟังเสียงแบบ realtime จากไมค์หรือ pipeline ที่ผู้ใช้อนุญาต
2. ถอดเสียงเป็น live transcript
3. แปลในเครื่องแบบเร็วที่สุดเท่าที่ทำได้
4. ส่งผลลัพธ์จาก extension กลับแอปหลักผ่าน App Group
5. แสดงผลเป็น floating subtitle ภายในแอป และเตรียม render เป็น video stream สำหรับ PiP
6. อ่านคำแปลออกเสียงด้วย voice ของภาษาปลายทาง
7. เก็บ history สั้น ๆ เพื่อย้อนดูบทสนทนา

ส่วนการทำให้ซับลอยเหนือแอปอื่นหรือฟังเสียงเกม/เพลงโดยตรง ต้องทำผ่าน API ที่ Apple อนุญาต เช่น ReplayKit Broadcast Extension หรือ PiP video layer ไม่ใช่การ bypass sandbox


## สถาปัตยกรรม iOS แบบ ViiTor ที่เพิ่มในโค้ด

### 1) รับเสียง/หน้าจอข้ามแอปด้วย Broadcast Upload Extension

แอปหลักเพิ่ม `RPSystemBroadcastPickerView` เพื่อเปิด broadcast picker ของ iOS แทนการแอบดักเสียงเอง ผู้ใช้ต้องกดเริ่ม Screen Broadcast ด้วยตัวเอง จากนั้น `LocalAudioBroadcastExtension/SampleHandler.swift` จะได้รับ sample buffers ตามที่ระบบอนุญาต:

- `.audioApp` สำหรับเสียงจากแอป/หน้าจอที่ถูก broadcast
- `.audioMic` สำหรับไมโครโฟน
- `.video` สำหรับเฟรมหน้าจอ

ตอนนี้ extension scaffold เขียน payload จำลอง/สถานะล่าสุดลง App Group เพื่อให้แอปหลัก poll กลับมาแสดงผลได้ จุดต่อจริงถัดไปคือส่ง audio buffers เข้า ASR/translation engine ที่อยู่ใน extension หรือ service ที่ผู้ใช้ยินยอม

### 2) ทำซับลอยด้วย Picture-in-Picture

แอปหลักเพิ่ม `PiPSubtitleController` เพื่อ render ข้อความคำแปลเป็นภาพใน `AVSampleBufferDisplayLayer` แล้วเตรียม `AVPictureInPictureController.ContentSource` แบบ sample-buffer video layer วิธีนี้คือแนวทางที่ถูกต้องสำหรับ “หน้าต่างลอย” บน iOS เพราะระบบอนุญาตให้ PiP ลอยข้ามแอป ไม่ใช่การสร้าง overlay เหนือแอปอื่นแบบ Android

### 3) Privacy/App Store

โครงนี้ตั้งใจใช้เฉพาะ API ทางการ: Speech, Microphone, ReplayKit Broadcast, App Group และ PiP ผู้ใช้ต้องเห็นและอนุญาตการ broadcast เองเสมอ การเปิดใช้ App Group บนเครื่องจริงต้องตั้งค่า entitlement/group identifier ให้ตรงกับบัญชี Apple Developer ของคุณ

## Build unsigned IPA บน GitHub

1. Push repo ขึ้น GitHub
2. เข้าแท็บ **Actions**
3. เลือก workflow **Build unsigned iOS IPA**
4. กด **Run workflow** หรือ push ไฟล์ใน `ios/**`
5. ดาวน์โหลด artifact ชื่อ `LocalAudioPiPTranslator-unsigned-ipa`

ไฟล์ที่ได้คือ:

```text
ios/build/LocalAudioPiPTranslator-unsigned.ipa
```

## Build unsigned IPA บน Mac local

ต้องมี Xcode ติดตั้งไว้ก่อน แล้วรัน:

```bash
./ios/Scripts/build_unsigned_ipa.sh
```

script จะรัน `xcodebuild` ด้วย:

- `CODE_SIGNING_ALLOWED=NO`
- `CODE_SIGNING_REQUIRED=NO`
- `CODE_SIGN_IDENTITY=""`

จากนั้น package โฟลเดอร์ `Payload/LocalAudioPiPTranslator.app` เป็น `.ipa` โดย app bundle จะ embed `LocalAudioBroadcastExtension.appex` ถ้า build บน macOS/Xcode สำเร็จ

> หมายเหตุ: unsigned IPA เหมาะสำหรับ artifact/testing pipeline เท่านั้น การทดสอบ App Group/Broadcast Extension บนอุปกรณ์จริงต้อง sign ด้วย provisioning profile ที่เปิด App Groups และ Broadcast Upload Extension ให้ตรงกับ bundle id ของคุณ

## ข้อจำกัดและทางต่อยอดให้เป็นแอปเต็ม

### เสียงจากเพลง/เกมอื่น

- **ทำไม่ได้โดยตรงจาก sandbox ของ iOS app ปกติ**
- ทางที่ถูกต้องคือใช้ **ReplayKit Broadcast Upload Extension** แล้วให้ผู้ใช้เริ่ม screen broadcast เอง
- repo นี้เพิ่ม extension scaffold แล้ว: `SampleHandler` รับ `audioApp`, `audioMic`, `video` buffers และ sync ผลลัพธ์ผ่าน App Group/shared container

### PiP / overlay เหนือแอปอื่น

- iOS ไม่มี permission ให้แอปทั่วไปวาด overlay เหนือแอปอื่นเหมือน Android
- PiP จริงต้องผูกกับ video playback/call UI ที่เป็นไปตาม API ของ Apple
- repo นี้เพิ่ม `PiPSubtitleController` ที่ render caption เป็น sample-buffer video layer สำหรับ PiP แล้ว จุดถัดไปคือทดสอบบนอุปกรณ์จริงและปรับ lifecycle/ขนาดหน้าต่าง

### Local translation model

ต้นแบบนี้ใช้ dictionary ในเครื่องเพื่อความเบาและไม่มี network ถ้าจะทำจริงให้ต่อ:

- Apple Speech on-device สำหรับ ASR ภาษาที่รองรับ
- Core ML / MLX model สำหรับ translation บนอุปกรณ์
- quantized model ขนาดเล็กเพื่อ latency ต่ำและประหยัดแบต

## เว็บเดโมเดิม

รันเว็บ static demo:

```bash
npm start
```

ตรวจ syntax JavaScript:

```bash
npm run build
```

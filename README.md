# Screen Broadcast PiP Translator

โปรเจกต์นี้เพิ่มต้นแบบ **iOS local realtime screen-broadcast subtitle translator** สำหรับกรณี “เปิด Screen Recording/Broadcast แล้วแปลเสียง/ซับจากหน้าจอเป็น PiP subtitle” พร้อม workflow บน GitHub Actions macOS เพื่อ build ไฟล์ `.ipa` แบบ unsigned

> หมายเหตุสำคัญ: โหมดหลักของแอปนี้คือ Screen Recording/Broadcast ไม่ใช่การอัดเสียงล้วน ๆ เพราะ iOS ไม่อนุญาตให้แอปทั่วไปดัก system audio เองแบบเงียบ ๆ วิธีที่ถูกต้องคือให้ผู้ใช้เริ่ม ReplayKit Broadcast ผ่าน UI ของ iOS แล้วระบบส่งเฟรมหน้าจอและเสียงของแอปที่ broadcast ให้ extension ส่วน PiP จริงต้องอิง video/call content source; ต้นแบบนี้จึง render ซับเป็น UIView content ใน System PiP ที่ลากขยับได้

## มีอะไรใน repo นี้

- `ios/LocalAudioPiPTranslator.xcodeproj` — Xcode project สำหรับ iOS app
- `ios/LocalAudioPiPTranslator` — SwiftUI app ที่มี UI สำหรับเริ่ม Screen Broadcast/import ซับ, แสดง transcript, แปล local dictionary, floating subtitle, ReplayKit picker และ PiP subtitle controller
- `ios/LocalAudioBroadcastExtension` — Broadcast Upload Extension scaffold สำหรับรับ `audioApp`, `audioMic` และ `video` sample buffers จาก Screen Recording ที่ผู้ใช้กดเริ่มเอง
- `ios/Shared` — โครง shared App Group payload สำหรับส่งซับ/คำแปลล่าสุดจาก extension กลับเข้าแอปหลัก
- `ios/Scripts/build_unsigned_ipa.sh` — script สร้าง unsigned `.ipa` จาก command line บน macOS/Xcode
- `.github/workflows/ios-unsigned-ipa.yml` — GitHub Actions workflow ใช้ runner macOS build แล้วอัปโหลด unsigned IPA artifact
- เว็บเดโมเดิมยังอยู่ที่ `index.html`, `src/main.js`, `src/styles.css` และยังตรวจ syntax ได้ด้วย `npm run build`

## ความสามารถของ iOS app ต้นแบบ

- SwiftUI interface สำหรับ “Screen Broadcast PiP Translator”
- โหมดหลักเป็น Screen Recording/Broadcast ผ่าน ReplayKit; Microphone เป็น fallback เท่านั้น
- ใช้ `SFSpeechRecognizer` พร้อม `requiresOnDeviceRecognition = true` เพื่อบังคับแนวทาง local-first เท่าที่อุปกรณ์รองรับ
- เลือกภาษาต้นทาง/ปลายทางได้ เช่น Auto, English, Japanese, Korean, Chinese, Thai
- แปลข้อความด้วย dictionary ในเครื่องก่อน และ fallback เป็นข้อความ `[Language] ...` เพื่อไม่ออก network
- แปลเสียงได้จริงในต้นแบบ: เมื่อมีประโยคใหม่ แอปใช้ `AVSpeechSynthesizer` อ่านคำแปลออกเสียงตามภาษาปลายทาง
- Floating subtitle ภายในแอป และ System PiP จริงที่ iOS ให้ผู้ใช้ลาก/ขยับได้เหมือน YouTube PiP
- Conversation history สำหรับดูประโยคต้นฉบับ/คำแปลย้อนหลัง
- ปุ่ม `Demo subtitle` สำหรับจำลองซับเกม/วิดีโอในเครื่อง
- โหมดเริ่มต้นคือ `Screen Recording` พร้อม `RPSystemBroadcastPickerView` เพื่อให้ผู้ใช้เริ่ม Broadcast ผ่าน UI ทางการของ iOS
- Broadcast Upload Extension target ที่รับ `audioApp`, `audioMic`, `video` sample buffers แล้วเขียน subtitle payload ผ่าน App Group
- Safe movable subtitle overlay ที่ลากได้ทันทีโดยไม่เด้ง และมี Experimental System PiP แยกไว้สำหรับทดสอบบนเครื่องที่รองรับ
- PiP subtitle renderer ที่ใช้ `AVPictureInPictureVideoCallViewController`/System PiP host view เพื่อให้หน้าต่าง PiP มีคอนเทนต์จริง ไม่จอดำ และลาก/ย่อ/ขยายได้โดย iOS


## แนวทางเทียบกับแอปแนว ViiTor

ต้นแบบนี้เน้น flow ที่ผู้ใช้คาดหวังจากแอป live subtitle/voice translator:

1. ผู้ใช้กดเริ่ม Screen Recording/Broadcast ผ่าน ReplayKit picker
2. Broadcast Upload Extension รับเฟรมหน้าจอและ app audio ที่มากับ screen broadcast
3. แปลในเครื่องแบบเร็วที่สุดเท่าที่ทำได้
4. ส่งผลลัพธ์จาก extension กลับแอปหลักผ่าน App Group
5. แสดงผลเป็น floating subtitle ภายในแอป และ render เป็น video stream สำหรับ System PiP ที่ผู้ใช้ลากขยับได้
6. อ่านคำแปลออกเสียงด้วย voice ของภาษาปลายทาง
7. เก็บ history สั้น ๆ เพื่อย้อนดูบทสนทนา

ส่วนการทำให้ซับลอยเหนือแอปอื่นหรือฟังเสียงเกม/เพลงโดยตรง ต้องทำผ่าน API ที่ Apple อนุญาต เช่น ReplayKit Broadcast Extension หรือ PiP video layer ไม่ใช่การ bypass sandbox


## สถาปัตยกรรม iOS แบบ ViiTor ที่เพิ่มในโค้ด

### 1) รับเสียง/หน้าจอข้ามแอปด้วย Broadcast Upload Extension

แอปหลักเพิ่ม `RPSystemBroadcastPickerView` เพื่อเปิด Screen Recording/Broadcast picker ของ iOS แทนการอัดเสียงเอง ผู้ใช้ต้องกดเริ่ม Screen Broadcast ด้วยตัวเอง จากนั้น `LocalAudioBroadcastExtension/SampleHandler.swift` จะได้รับ sample buffers ตามที่ระบบอนุญาต:

- `.audioApp` สำหรับเสียงจากแอป/หน้าจอที่ถูก broadcast
- `.audioMic` สำหรับไมโครโฟนเสริมถ้าผู้ใช้เปิดเอง แต่ picker ในแอปตั้งค่าเริ่มต้นให้ปิดปุ่มไมค์เพื่อเน้น Screen Recording
- `.video` สำหรับเฟรมหน้าจอ

ตอนนี้ extension scaffold เขียน payload จำลอง/สถานะล่าสุดลง App Group เพื่อให้แอปหลัก poll กลับมาแสดงผลได้ จุดต่อจริงถัดไปคือส่ง app-audio buffers ที่มากับ screen broadcast เข้า ASR/translation engine ที่อยู่ใน extension หรือ service ที่ผู้ใช้ยินยอม

### 2) ทำซับลอยด้วย Picture-in-Picture

แอปหลักเพิ่ม `PiPSubtitleController` และ safe movable subtitle overlay: ปุ่มหลักจะเปิดกล่องซับที่ลากได้ทันทีในแอปโดยไม่ force-start System PiP จึงไม่ควรจอดำหรือเด้ง ส่วน `Experimental System PiP` ยังใช้ `AVPictureInPictureController.ContentSource(activeVideoCallSourceView:contentViewController:)` ผ่าน `AVPictureInPictureVideoCallViewController` สำหรับทดสอบบนเครื่อง/โปรไฟล์ที่รองรับ
แอปหลักเพิ่ม `PiPSubtitleController` ที่ attach preview view เข้ากับหน้าจอก่อน แล้วเปิด `AVPictureInPictureController.ContentSource(activeVideoCallSourceView:contentViewController:)` ผ่าน `AVPictureInPictureVideoCallViewController` วิธีนี้ทำให้ PiP มี UIView subtitle content จริง จึงลดปัญหาจอดำจาก sample-buffer layer เปล่า และเมื่อ PiP เริ่มแล้ว iOS เป็นเจ้าของหน้าต่าง ผู้ใช้จึงลาก/ขยับ/ย่อ/ขยายได้เหมือน YouTube PiP

### 3) Privacy/App Store

โครงนี้ตั้งใจใช้เฉพาะ API ทางการ: Speech, Microphone, ReplayKit Broadcast, App Group และ PiP ผู้ใช้ต้องเห็นและอนุญาตการ broadcast เองเสมอ การเปิดใช้ App Group บนเครื่องจริงต้องตั้งค่า entitlement/group identifier ให้ตรงกับบัญชี Apple Developer ของคุณ


### แก้กรณี PiP จอดำ/เด้ง

ถ้าเห็นหน้าจอ PiP สีดำหรือแอปเด้ง ให้ใช้ปุ่ม **Show safe movable subtitles** เป็นค่าเริ่มต้น ปุ่มนี้ไม่เรียก System PiP เลย แต่เปิดกล่องซับที่ลากได้ในแอปทันที ส่วน **Try System PiP** เป็นโหมดทดลองที่อาจขึ้นกับเครื่อง, iOS, provisioning และ background modes; ถ้าเริ่มไม่ได้แอปจะ fallback กลับมาแสดง safe movable subtitles แทน
ถ้าเห็นหน้าจอ PiP สีดำหรือแอปเด้ง มักเกิดจากการเริ่ม PiP ก่อนที่ source view จะถูก attach เข้าหน้าจอ หรือใช้ sample-buffer layer ที่ยังไม่มีเฟรมต่อเนื่อง เวอร์ชันนี้เปลี่ยน PiP เป็น video-call content source ที่มี UIView subtitle จริง, แสดง preview ในแอปก่อนเริ่ม PiP, และถ้า PiP ยังไม่พร้อมจะแสดงข้อความสถานะแทนการ force start

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
- repo นี้เพิ่ม `PiPSubtitleController` ที่ attach UIView preview เข้ากับหน้าจอก่อนเปิด System PiP จริง พร้อม guard/ข้อความ error ถ้า PiP ยังไม่พร้อม เมื่อรันบนอุปกรณ์ที่รองรับ ผู้ใช้จะลาก/ขยับหน้าต่างได้แบบ YouTube PiP

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

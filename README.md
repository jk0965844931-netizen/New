# Local Audio PiP Translator

โปรเจกต์นี้เพิ่มต้นแบบ **iOS local realtime audio translator** สำหรับกรณี “ฟังเสียงเพลง/เกมแล้วแปลขึ้นหน้าจอแบบ PiP/floating overlay” พร้อม workflow บน GitHub Actions macOS เพื่อ build ไฟล์ `.ipa` แบบ unsigned

> หมายเหตุสำคัญ: iOS ไม่อนุญาตให้แอปทั่วไปดักฟังเสียง system audio ของแอปอื่นแบบเงียบ ๆ โดยตรง การทำให้ถูกต้องต้องใช้ไมโครโฟน, audio session ที่ผู้ใช้อนุญาต, หรือ ReplayKit Broadcast Extension ที่ผู้ใช้เริ่มเอง ส่วน PiP จริงของ iOS ต้องอิง video layer; ในต้นแบบนี้จึงทำ floating overlay ในแอป, เพิ่ม voice translation ด้วย Text-to-Speech, และวางโครงต่อยอดไป Broadcast Extension/AVPictureInPictureController ภายหลัง

## มีอะไรใน repo นี้

- `ios/LocalAudioPiPTranslator.xcodeproj` — Xcode project สำหรับ iOS app
- `ios/LocalAudioPiPTranslator` — SwiftUI app ที่มี UI สำหรับเริ่ม/หยุดการฟังเสียง, แสดง transcript, แปล local dictionary, และ floating overlay
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
- โหมดเลือก `ReplayKit / Screen Recording` เพื่อสื่อสาร pipeline ที่ถูกต้องสำหรับการรับเสียงจากเกม/แอปอื่นในอนาคต


## แนวทางเทียบกับแอปแนว ViiTor

ต้นแบบนี้เน้น flow ที่ผู้ใช้คาดหวังจากแอป live subtitle/voice translator:

1. ฟังเสียงแบบ realtime จากไมค์หรือ pipeline ที่ผู้ใช้อนุญาต
2. ถอดเสียงเป็น live transcript
3. แปลในเครื่องแบบเร็วที่สุดเท่าที่ทำได้
4. แสดงผลเป็น floating subtitle
5. อ่านคำแปลออกเสียงด้วย voice ของภาษาปลายทาง
6. เก็บ history สั้น ๆ เพื่อย้อนดูบทสนทนา

ส่วนการทำให้ซับลอยเหนือแอปอื่นหรือฟังเสียงเกม/เพลงโดยตรง ต้องทำผ่าน API ที่ Apple อนุญาต เช่น ReplayKit Broadcast Extension หรือ PiP video layer ไม่ใช่การ bypass sandbox

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

จากนั้น package โฟลเดอร์ `Payload/LocalAudioPiPTranslator.app` เป็น `.ipa`

## ข้อจำกัดและทางต่อยอดให้เป็นแอปเต็ม

### เสียงจากเพลง/เกมอื่น

- **ทำไม่ได้โดยตรงจาก sandbox ของ iOS app ปกติ**
- ทางที่ถูกต้องคือเพิ่ม **ReplayKit Broadcast Upload Extension** แล้วให้ผู้ใช้เริ่ม screen broadcast เอง
- ใน extension ให้รับ audio sample buffer, ส่งเข้า on-device ASR/translator, แล้ว sync ผลลัพธ์กลับ app group/shared container

### PiP / overlay เหนือแอปอื่น

- iOS ไม่มี permission ให้แอปทั่วไปวาด overlay เหนือแอปอื่นเหมือน Android
- PiP จริงต้องผูกกับ video playback/call UI ที่เป็นไปตาม API ของ Apple
- สำหรับการใช้งานจริงควรทำเป็น PiP video layer ที่ render caption หรือใช้ Broadcast/SharePlay workflow ตามข้อจำกัดของระบบ

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

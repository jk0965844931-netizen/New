# Manga Overlay Translator

เว็บต้นแบบสำหรับอ่านมังงะพร้อมคำแปลแบบ overlay ที่ออกแบบให้เร็วและใช้งานบน iPhone ได้ โดยเน้นการทำงานใน browser ก่อน แล้วเปิดจุดต่อสำหรับ Ollama local และ Hugging Face cloud

## ฟีเจอร์

- Reader mode: วาง URL รูปภาพหลายบรรทัด แล้วแสดงเป็นหน้าอ่านมังงะ
- Web-in-web mode: ฝังเว็บจริงผ่าน iframe เมื่อเว็บต้นทางอนุญาต และถ้าเป็น MangaDex chapter จะดึงรูปผ่าน MangaDex API เข้า reader แทน iframe
- Overlay editor: เพิ่ม/แก้กรอบคำพูดและตำแหน่งแบบเปอร์เซ็นต์
- Translation providers:
  - `local`: dictionary/mock เร็วสุดและไม่ออกเน็ต
  - `ollama`: เรียก Ollama ที่เครื่องผู้ใช้ เช่น `gemma3:4b`
  - `huggingface`: เรียก Hugging Face Inference API โดย token เก็บเฉพาะ session storage
- Mobile-first CSS รองรับ safe-area และปุ่มขนาดเหมาะกับ touch

## ทำเป็นเว็บไซต์จริง

โปรเจกต์นี้เป็น static website จึง deploy ฟรีได้บน GitHub Pages, Netlify หรือ Vercel โดยใช้โฟลเดอร์ root เป็น publish directory ดูขั้นตอนละเอียดใน [`DEPLOY.md`](./DEPLOY.md)

## ข้อจำกัดสำคัญ

- เว็บมังงะหลายเว็บไม่ยอมให้ฝัง iframe ด้วย `X-Frame-Options` หรือ `Content-Security-Policy` เว็บนี้จะไม่พยายาม bypass ระบบนั้น
- MangaDex ไม่อนุญาต iframe ดังนั้นต้องใช้ลิงก์ chapter เต็มรูปแบบ เช่น `https://mangadex.org/chapter/<uuid>` เพื่อให้ระบบดึงรูปผ่าน API
- รูปภาพจากเว็บอื่นอาจโดน hotlink/CORS block ให้ใช้รูปที่คุณมีสิทธิ์ใช้งาน หรือทำ proxy ฝั่ง server ที่คุณควบคุมเอง
- OCR จริงยังไม่ได้รวมไว้ในต้นแบบนี้ เพื่อให้เปิดเร็วบนมือถือ โค้ดปัจจุบันใช้การเพิ่ม/แก้ข้อความใน bubble เองและ provider แปลข้อความ
- Hugging Face token ไม่ควรฝังไว้ใน frontend production ให้ทำ backend proxy สำหรับงานจริง

## เริ่มใช้งาน

```bash
npm install
npm run start
```

เปิด `http://localhost:5173` ใน Safari/Chrome หรือทดสอบบน iPhone ผ่าน IP เครื่องในเครือข่ายเดียวกัน

## ใช้ Ollama local

1. ติดตั้ง Ollama และ pull model ที่ต้องการ เช่น `ollama pull gemma3:4b`
2. เปิด Ollama ให้ browser เรียกได้ โดยตั้งค่า CORS ตามสภาพแวดล้อมของคุณ
3. ในเว็บเลือก provider เป็น `Ollama local`
4. ตั้ง endpoint เป็น `http://localhost:11434/api/generate` และ model เป็นชื่อ model ในเครื่อง

> หมายเหตุ: ชื่อรุ่น Gemma ที่ใช้งานได้จริงขึ้นกับ Ollama/Hugging Face ณ เวลานั้น ถ้าไม่มี `gemma 4` ให้ใช้รุ่น Gemma ที่ provider รองรับแทน

## แนวทางต่อยอด production

- เพิ่ม backend proxy สำหรับดึงภาพ/หน้าเว็บที่มีสิทธิ์เข้าถึงและ cache ภาพ
- เพิ่ม OCR/Web Worker เช่น Tesseract/WASM หรือ OCR server เพื่อแยกข้อความจากภาพโดยไม่บล็อก UI
- เพิ่ม speech-bubble detector ด้วย computer vision หรือ model เฉพาะทาง
- เพิ่ม PWA manifest + service worker สำหรับ offline cache

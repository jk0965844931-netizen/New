# Manga Overlay Translator

เว็บต้นแบบสำหรับอ่านมังงะพร้อมคำแปลแบบ overlay ที่ออกแบบให้เร็วและใช้งานบน iPhone ได้ โดยเน้น **local-first** ก่อน แล้วเปิดจุดต่อสำหรับ Ollama local, Ollama Cloud และ Hugging Face cloud

## ฟีเจอร์

- **Search mode**: ค้นหาเว็บมังงะหรือเว็บทั่วไปผ่าน DuckDuckGo/Google/Bing/Brave และรองรับ SearXNG JSON endpoint ถ้ามี instance ที่เปิด CORS
- **Reader mode**: วาง URL รูปภาพหลายบรรทัด แล้วแสดงเป็นหน้าอ่านมังงะ
- **HTML image extractor**: วาง HTML/source ที่คัดลอกจากเว็บ แล้วให้แอปแยก `<img>`, `srcset`, `data-src` และ URL รูปภาพออกมาให้
- **Web-in-web mode**: ฝังเว็บจริงผ่าน iframe เมื่อเว็บต้นทางอนุญาต
- **Overlay editor**: แตะพื้นที่ว่างบนภาพเพื่อวางกรอบคำพูด, แตะกรอบเพื่อแก้ข้อความและตำแหน่งแบบเปอร์เซ็นต์
- **Auto translate + cache**: แปลทันทีหลังแก้ข้อความในกรอบ และ cache ผลแปลระหว่าง session เพื่อลด latency
- **Translation providers**:
  - `local`: dictionary/cache เร็วสุด ไม่ออกเน็ต และเหมาะกับ iPhone มากที่สุด
  - `ollama`: เรียก Ollama ที่เครื่องผู้ใช้ เช่น `gemma3:4b` หรือ `gemma4:e4b` ถ้าติดตั้งไว้
  - `ollama-cloud`: เรียก Ollama Cloud ผ่าน `https://ollama.com/api/generate` พร้อม API key ที่เก็บเฉพาะ session
  - `huggingface`: เรียก Hugging Face Inference API โดย token เก็บเฉพาะ session storage
- **Mobile-first CSS** รองรับ safe-area, ปุ่มขนาดเหมาะกับ touch และ PWA service worker

## ใช้ Gemma 4 / Ollama Cloud ได้ไหม?

ได้ในเชิงสถาปัตยกรรม ถ้าบัญชี/เครื่องของคุณมี model นั้นให้เรียกใช้งาน:

1. ถ้าใช้ **Ollama local** ให้ติดตั้งหรือ pull model ในเครื่องที่รัน Ollama แล้วตั้ง endpoint เป็น `http://localhost:11434/api/generate` หรือ IP เครื่องในวง Wi‑Fi เช่น `http://192.168.1.20:11434/api/generate`
2. ถ้าใช้ **Ollama Cloud** ให้เลือก provider `Ollama Cloud`, ใส่ API key และใส่ชื่อ model cloud ที่บัญชีคุณรองรับ เช่นช่องนี้ตั้งค่าเริ่มต้นเป็น `gemma4:e4b`
3. บน iPhone โดยตรง การรัน LLM ใหญ่ใน browser ยังไม่เหมาะกับความเร็ว/แบตเตอรี่ จึงแนะนำให้ใช้ local dictionary/cache หรือเรียก cloud ผ่าน HTTPS

## วิธีใช้งานแบบเร็ว

### ค้นหาเว็บมังงะหรือเว็บทั่วไป

1. เปิดแท็บ **ค้นหาเว็บ**
2. พิมพ์ชื่อเรื่อง/คำค้น แล้วเลือกประเภท `มังงะ`, `เว็บทั่วไป` หรือ `ค้นหารูปภาพ`
3. กด **เปิดผลค้นหา** เพื่อเปิดผลใน search engine ที่เลือก
4. ถ้ามี SearXNG instance ที่เปิด CORS ให้ใส่ endpoint แล้วกด **ค้นหาในแอป** เพื่อดึงผลมาแสดงในเว็บนี้
5. เมื่อเจอเว็บที่ต้องการ ให้เปิดในแท็บใหม่, ส่ง URL ไปยังโหมด **เว็บซ้อนเว็บ**, หรือคัดลอก URL/HTML กลับมาใช้ใน **โหลดรูป**

### อ่านและแปล overlay

1. เปิดเว็บ แล้วอยู่ในแท็บ **โหลดรูป**
2. วาง URL รูปภาพหนึ่งรายการต่อหนึ่งบรรทัด หรือเปิดส่วน **ดึง URL รูปจาก HTML ที่คัดลอกมา** แล้ววาง HTML/source
3. กดโหลดรูปเข้า reader
4. แตะพื้นที่บนรูปเพื่อวางกรอบคำพูด
5. แตะกรอบเพื่อพิมพ์ข้อความต้นฉบับ และปล่อยช่องคำแปลว่างหากต้องการให้ระบบแปลให้
6. กด **แปล overlay ทั้งหมด** ถ้าต้องการแปลทุกกรอบพร้อมกัน

## ทำเป็นเว็บไซต์จริง

โปรเจกต์นี้เป็น static website จึง deploy ฟรีได้บน GitHub Pages, Netlify หรือ Vercel โดยใช้โฟลเดอร์ root เป็น publish directory ดูขั้นตอนละเอียดใน [`DEPLOY.md`](./DEPLOY.md) วิธีสั้นที่สุดคือ push repo ขึ้น GitHub แล้วเปิด GitHub Pages ที่ Settings → Pages หรือใช้ Netlify/Vercel โดยตั้ง Build command เป็น `npm run build` และ Publish/Output directory เป็น `.`

## ข้อจำกัดสำคัญ

- การค้นหาในตัวแอปแบบดึงผลกลับมาต้องใช้ SearXNG หรือ search backend ที่เปิด CORS เอง เพราะ search engine ส่วนใหญ่ไม่อนุญาตให้ static browser app scrape ผลโดยตรง
- เว็บมังงะหลายเว็บไม่ยอมให้ฝัง iframe ด้วย `X-Frame-Options` หรือ `Content-Security-Policy` เว็บนี้จะไม่พยายาม bypass ระบบนั้น
- รูปภาพจากเว็บอื่นอาจโดน hotlink/CORS block ให้ใช้รูปที่คุณมีสิทธิ์ใช้งาน หรือทำ proxy ฝั่ง server ที่คุณควบคุมเอง
- OCR เต็มรูปแบบยังไม่รวมใน static app นี้ เพราะ browser ล้วน ๆ จะใหญ่และช้าบนมือถือ หากต้องการ OCR จริงให้ต่อ backend OCR/vision model หรือใช้ model vision ผ่าน provider ที่รองรับ
- การใช้งานเว็บมังงะจริงควรเคารพลิขสิทธิ์, เงื่อนไขเว็บต้นทาง, robots policy, paywall และ rate limit
- Token cloud ที่กรอกใน browser เหมาะกับ prototype เท่านั้น ถ้าทำ production ควรทำ backend proxy เพื่อซ่อน secret

## คำสั่ง

```bash
npm run start
npm run build
```

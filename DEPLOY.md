# ทำเป็นเว็บไซต์จริงอย่างไร

โปรเจกต์นี้เป็น **static website**: มีแค่ HTML, CSS, JavaScript และไฟล์ PWA จึงเอาไปฝากบนบริการฟรีได้ทันทีโดยไม่ต้องมี server backend

## วิธีทดสอบบนเครื่อง

```bash
npm install
npm run start
```

จากนั้นเปิด `http://localhost:5173` ใน browser

ถ้าจะลองบน iPhone:

1. ให้คอมพิวเตอร์และ iPhone อยู่ Wi-Fi เดียวกัน
2. หา IP เครื่องคอมพิวเตอร์ เช่น `192.168.1.20`
3. เปิด `http://192.168.1.20:5173` ใน Safari บน iPhone
4. กด Share → Add to Home Screen เพื่อทดลองแบบ PWA

## Deploy ฟรีด้วย GitHub Pages

1. Push repo นี้ขึ้น GitHub
2. ไปที่ **Settings → Pages**
3. เลือก **Deploy from a branch**
4. เลือก branch ที่ต้องการ และ folder เป็น `/ (root)`
5. กด Save แล้วรอ URL ประมาณ `https://username.github.io/repository-name/`

โปรเจกต์ใช้ path แบบ relative แล้ว จึงทำงานได้ทั้ง root domain และ GitHub Pages แบบ subpath

## Deploy ฟรีด้วย Netlify

1. เข้า Netlify แล้วเลือก **Add new site → Import an existing project**
2. เลือก repo นี้
3. Build command: `npm run build`
4. Publish directory: `.`
5. Deploy

มีไฟล์ `netlify.toml` ตั้งค่าไว้แล้ว ถ้า Netlify อ่านไฟล์นี้ได้ ระบบจะใส่ค่า build/publish ให้อัตโนมัติ

## Deploy ฟรีด้วย Vercel

1. เข้า Vercel แล้วเลือก **Add New → Project**
2. เลือก repo นี้
3. Framework Preset: **Other**
4. Build Command: `npm run build`
5. Output Directory: `.`
6. Deploy

มีไฟล์ `vercel.json` ตั้งค่า static routing ไว้ให้แล้ว

## เรื่อง Ollama และ Hugging Face หลัง deploy

- `local` provider ใช้ได้ทันที เพราะไม่ต้องเรียก server ภายนอก
- `Hugging Face cloud` ใช้ได้ถ้าใส่ token ในหน้าเว็บ แต่ production จริงควรทำ backend proxy เพื่อไม่ให้ token อยู่ใน browser
- `Ollama local` บนเว็บ HTTPS ที่ deploy แล้วอาจเรียก `http://localhost:11434` ไม่ได้เพราะ browser มี mixed-content/CORS policy ให้ใช้ตอนทดสอบ local หรือทำ HTTPS proxy ที่คุณควบคุม

## ข้อจำกัดของเว็บซ้อนเว็บ

โหมด iframe จะใช้ได้เฉพาะเว็บมังงะที่อนุญาตให้ฝังเท่านั้น ถ้าเว็บปลายทางตั้งค่า `X-Frame-Options` หรือ `Content-Security-Policy` ห้ามฝัง หน้าเว็บจะไม่แสดง และแอปนี้จะไม่ bypass ระบบป้องกันของเว็บต้นทาง

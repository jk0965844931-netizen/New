# Danganronpa 1 Thai Mod Builder (Server Version)

เว็บแอปนี้เป็นเวอร์ชัน **เซิร์ฟเวอร์ใช้งานจริง**:
- อัปโหลดไฟล์ `.zip` ของ game dump
- สร้างงานประมวลผล (job)
- แปลไฟล์ข้อความ (`.txt`, `.json`) อัตโนมัติ
- QA report
- แพ็กกลับเป็นไฟล์ม็อด `.zip` ให้ดาวน์โหลด

## Run

```bash
python server.py
```

เปิดที่ `http://localhost:8000`

## API

- `POST /api/jobs` (multipart, field: `gameFile`)
- `GET /api/jobs/:jobId`
- `GET /api/jobs/:jobId/download`

## หมายเหตุด้านเทคนิค

- ปัจจุบัน parser แบบ built-in รองรับไฟล์ข้อความทั่วไปก่อน (`.txt`, `.json`).
- หากเกมใช้ไฟล์ไบนารีเฉพาะทาง (เช่น message bundle format เฉพาะของเกม) ต้องเพิ่ม parser เฉพาะฟอร์แมตนั้นใน pipeline.
- โค้ดนี้ทำงานเป็นฐาน production workflow ได้จริงฝั่ง server + queue แต่คุณภาพคำแปลและความเข้ากันได้ 100% ต้องปรับ dictionary/model ตามไฟล์จริงของเกม.

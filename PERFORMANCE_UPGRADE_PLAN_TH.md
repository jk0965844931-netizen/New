# แผนอัปเกรด iPSX2 แบบ “ก้าวกระโดด” (เน้น FPS เพิ่ม + บั๊กลด)

> หมายเหตุ: ในสภาพแวดล้อมนี้ไม่สามารถเข้าถึง GitHub repo ที่คุณส่งมาได้โดยตรง (ติดข้อจำกัดเครือข่าย 403) จึงจัดเป็นแผนลงมือทำที่นำไปใช้กับโค้ดจริงได้ทันที

## 1) เป้าหมายวัดผล (ต้องมี baseline ก่อน)
- FPS เฉลี่ยและ 1% low ในฉากเดิมซ้ำได้
- Frame time (ms) เฉลี่ย/สูงสุด
- อัตรา crash ต่อชั่วโมง
- จำนวน regression tests ที่ผ่าน

## 2) เพิ่ม FPS แบบเห็นผลเร็ว
1. เปิดใช้ **PGO + LTO + -O3** ใน release build
2. ทำ **hot path profiling** แล้ว optimize เฉพาะ 10 ฟังก์ชันบนสุด
3. ลด lock contention ใน core loop (CPU emulation, GPU command queue)
4. เพิ่ม **shader cache / pipeline cache**
5. ลด memory allocation ระหว่างเฟรม (ใช้ object pool / arena)

## 3) ลดบั๊กแบบเป็นระบบ
1. เปิด sanitizer ใน debug/staging:
   - AddressSanitizer
   - UndefinedBehaviorSanitizer
   - ThreadSanitizer (เฉพาะงาน threading)
2. เพิ่ม deterministic tests:
   - save state/load state consistency
   - replay input แล้ว hash output frame
3. เพิ่ม crash dump + symbolication pipeline
4. ทำ canary release ก่อนปล่อยเต็ม

## 4) ลำดับงาน 14 วัน (แนะนำ)
- Day 1-2: ใส่ benchmark scene + telemetry + baseline
- Day 3-5: PGO/LTO + optimize hot functions
- Day 6-8: shader/pipeline cache + ลด allocation
- Day 9-10: sanitizer sweep + fix UB/race
- Day 11-12: regression tests + replay tests
- Day 13-14: canary + compare metrics ก่อน/หลัง

## 5) KPI ที่ควรได้หลังรอบแรก
- FPS เฉลี่ยเพิ่ม 20-60% (ขึ้นกับ bottleneck เดิม)
- 1% low ดีขึ้นชัดเจน (stutter ลด)
- crash rate ลด 30-80%
- regressions หลัง release ลดลง

## 6) ถ้าต้องการให้ผมแก้โค้ดให้ตรงจุด
ส่งมาอย่างใดอย่างหนึ่ง:
- zip ของ repo
- หรือเปิด mirror ที่เข้าถึงได้จาก environment นี้

แล้วผมจะทำ patch ให้เป็นไฟล์จริงพร้อม commit ต่อให้ทันที (เช่น build flags, profiler hooks, cache layer, test harness)

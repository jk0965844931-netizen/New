#!/usr/bin/env python3
from __future__ import annotations

import cgi
import io
import json
import os
import re
import shutil
import threading
import time
import uuid
import zipfile
from dataclasses import dataclass, field
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Dict, List
from urllib import request

ROOT = Path(__file__).parent.resolve()
JOBS_DIR = ROOT / "jobs"
JOBS_DIR.mkdir(exist_ok=True)

THAI_GLOSSARY = {
    "hope": "ความหวัง",
    "despair": "ความสิ้นหวัง",
    "truth bullet": "กระสุนแห่งความจริง",
    "class trial": "ชั้นพิจารณาคดี",
    "ultimate": "สุดยอด",
    "monokuma": "โมโนคุมะ",
}


@dataclass
class Job:
    job_id: str
    filename: str
    status: str = "queued"
    progress: int = 0
    message: str = "รอคิว"
    logs: List[str] = field(default_factory=list)
    created_at: float = field(default_factory=time.time)
    output_zip: str | None = None
    warnings: List[str] = field(default_factory=list)


JOBS: Dict[str, Job] = {}
JOBS_LOCK = threading.Lock()


def set_job(job_id: str, **kwargs):
    with JOBS_LOCK:
        job = JOBS[job_id]
        for key, value in kwargs.items():
            setattr(job, key, value)


def log(job_id: str, message: str):
    with JOBS_LOCK:
        JOBS[job_id].logs.append(message)
        JOBS[job_id].message = message


def translate_text(text: str) -> str:
    result = text
    for en, th in THAI_GLOSSARY.items():
        result = re.sub(en, th, result, flags=re.IGNORECASE)
    if result == text:
        # fallback marker so team can QA unresolved strings quickly
        result = f"[TH_AUTO]{text}"
    return result


def process_text_file(path: Path) -> int:
    content = path.read_text(encoding="utf-8", errors="ignore")
    lines = content.splitlines()
    translated = [translate_text(line) for line in lines]
    path.write_text("\n".join(translated), encoding="utf-8")
    return len(lines)


def process_json_file(path: Path) -> int:
    content = json.loads(path.read_text(encoding="utf-8", errors="ignore"))

    def walk(node):
        count = 0
        if isinstance(node, dict):
            for k, v in node.items():
                c, new_v = walk(v)
                node[k] = new_v
                count += c
            return count, node
        if isinstance(node, list):
            out = []
            for item in node:
                c, new_item = walk(item)
                out.append(new_item)
                count += c
            return count, out
        if isinstance(node, str):
            return 1, translate_text(node)
        return 0, node

    count, output = walk(content)
    path.write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding="utf-8")
    return count


def zip_directory(source_dir: Path, output_zip: Path):
    with zipfile.ZipFile(output_zip, "w", zipfile.ZIP_DEFLATED) as zf:
        for item in source_dir.rglob("*"):
            if item.is_file():
                zf.write(item, item.relative_to(source_dir))


def run_pipeline(job_id: str, source_zip: Path, job_dir: Path):
    work_dir = job_dir / "work"
    work_dir.mkdir(parents=True, exist_ok=True)
    set_job(job_id, status="running", progress=5, message="กำลังแตกไฟล์")
    log(job_id, "แตกไฟล์เกม")

    with zipfile.ZipFile(source_zip, "r") as zf:
        zf.extractall(work_dir)

    targets = [p for p in work_dir.rglob("*") if p.suffix.lower() in {".txt", ".json"} and p.is_file()]
    if not targets:
        with JOBS_LOCK:
            JOBS[job_id].warnings.append("ไม่พบไฟล์ .txt/.json ที่รองรับในแพ็กเกจ")

    total = max(len(targets), 1)
    translated_lines = 0

    for idx, path in enumerate(targets, start=1):
        ext = path.suffix.lower()
        try:
            if ext == ".txt":
                translated_lines += process_text_file(path)
            elif ext == ".json":
                translated_lines += process_json_file(path)
        except Exception as exc:
            with JOBS_LOCK:
                JOBS[job_id].warnings.append(f"ข้ามไฟล์ {path.name}: {exc}")
        progress = 10 + int((idx / total) * 75)
        set_job(job_id, progress=progress)
        log(job_id, f"แปลไฟล์ {idx}/{total}: {path.name}")

    log(job_id, "กำลังทำ QA และแพ็กไฟล์ม็อด")
    set_job(job_id, progress=92)

    output_zip = job_dir / "thai-mod-pack.zip"
    zip_directory(work_dir, output_zip)

    report = {
        "job_id": job_id,
        "translated_units": translated_lines,
        "processed_files": len(targets),
        "warnings": JOBS[job_id].warnings,
        "note": "รองรับไฟล์ข้อความทั่วไป (.txt/.json) สำหรับไฟล์ไบนารีเฉพาะเกมต้องเพิ่ม parser เฉพาะทาง",
    }
    (job_dir / "qa-report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    set_job(
        job_id,
        status="done",
        progress=100,
        message="เสร็จสิ้น พร้อมดาวน์โหลด",
        output_zip=str(output_zip.relative_to(ROOT)),
    )
    log(job_id, "เสร็จสิ้น")


class Handler(SimpleHTTPRequestHandler):
    def _send_json(self, payload, code=200):
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self):
        if self.path != "/api/jobs":
            self._send_json({"error": "Not found"}, 404)
            return

        ctype, pdict = cgi.parse_header(self.headers.get("content-type", ""))
        if ctype != "multipart/form-data":
            self._send_json({"error": "ต้องส่งแบบ multipart/form-data"}, 400)
            return

        pdict["boundary"] = bytes(pdict["boundary"], "utf-8")
        pdict["CONTENT-LENGTH"] = int(self.headers.get("content-length", 0))
        form = cgi.FieldStorage(fp=self.rfile, headers=self.headers, environ={"REQUEST_METHOD": "POST"})

        if "gameFile" not in form:
            self._send_json({"error": "ไม่พบฟิลด์ gameFile"}, 400)
            return

        file_item = form["gameFile"]
        if not getattr(file_item, "filename", ""):
            self._send_json({"error": "ไม่ได้เลือกไฟล์"}, 400)
            return

        filename = Path(file_item.filename).name
        if not filename.lower().endswith(".zip"):
            self._send_json({"error": "รองรับเฉพาะไฟล์ .zip"}, 400)
            return

        job_id = uuid.uuid4().hex[:12]
        job_dir = JOBS_DIR / job_id
        job_dir.mkdir(parents=True, exist_ok=True)
        source_zip = job_dir / "source.zip"
        with source_zip.open("wb") as f:
            shutil.copyfileobj(file_item.file, f)

        with JOBS_LOCK:
            JOBS[job_id] = Job(job_id=job_id, filename=filename)

        thread = threading.Thread(target=run_pipeline, args=(job_id, source_zip, job_dir), daemon=True)
        thread.start()

        self._send_json({"jobId": job_id})

    def do_GET(self):
        if self.path.startswith("/api/jobs/"):
            rest = self.path.removeprefix("/api/jobs/")
            parts = rest.split("/")
            job_id = parts[0]
            with JOBS_LOCK:
                job = JOBS.get(job_id)
            if not job:
                self._send_json({"error": "ไม่พบงาน"}, 404)
                return

            if len(parts) > 1 and parts[1] == "download":
                if job.status != "done" or not job.output_zip:
                    self._send_json({"error": "งานยังไม่เสร็จ"}, 400)
                    return
                output = ROOT / job.output_zip
                if not output.exists():
                    self._send_json({"error": "ไม่พบไฟล์ผลลัพธ์"}, 404)
                    return
                self.send_response(200)
                self.send_header("Content-Type", "application/zip")
                self.send_header("Content-Disposition", f'attachment; filename="{job_id}-thai-mod-pack.zip"')
                self.send_header("Content-Length", str(output.stat().st_size))
                self.end_headers()
                with output.open("rb") as f:
                    shutil.copyfileobj(f, self.wfile)
                return

            self._send_json(
                {
                    "jobId": job.job_id,
                    "status": job.status,
                    "progress": job.progress,
                    "message": job.message,
                    "warnings": job.warnings,
                    "logs": job.logs[-10:],
                }
            )
            return

        return super().do_GET()


if __name__ == "__main__":
    os.chdir(ROOT)
    server = ThreadingHTTPServer(("0.0.0.0", 8000), Handler)
    print("Server running at http://0.0.0.0:8000")
    server.serve_forever()

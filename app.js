const dropZone = document.getElementById("dropZone");
const fileInput = document.getElementById("fileInput");
const fileList = document.getElementById("fileList");
const startBtn = document.getElementById("startBtn");
const downloadBtn = document.getElementById("downloadBtn");
const progressEl = document.getElementById("progress");
const statusText = document.getElementById("statusText");
const logList = document.getElementById("logList");
const resultText = document.getElementById("resultText");

let selectedFile = null;
let activeJobId = null;

const setFile = (file) => {
  selectedFile = file;
  fileList.innerHTML = "";

  if (!file) {
    startBtn.disabled = true;
    return;
  }

  const item = document.createElement("li");
  item.textContent = `${file.name} (${Math.round(file.size / 1024)} KB)`;
  fileList.appendChild(item);
  startBtn.disabled = false;
};

fileInput.addEventListener("change", (e) => {
  const file = e.target.files[0] || null;
  setFile(file);
});

["dragenter", "dragover"].forEach((eventName) => {
  dropZone.addEventListener(eventName, (e) => {
    e.preventDefault();
    dropZone.classList.add("dragging");
  });
});

["dragleave", "drop"].forEach((eventName) => {
  dropZone.addEventListener(eventName, (e) => {
    e.preventDefault();
    dropZone.classList.remove("dragging");
  });
});

dropZone.addEventListener("drop", (e) => {
  const file = e.dataTransfer?.files?.[0];
  if (!file) return;
  if (!file.name.toLowerCase().endsWith(".zip")) {
    alert("กรุณาเลือกไฟล์ .zip เท่านั้น");
    return;
  }

  const dt = new DataTransfer();
  dt.items.add(file);
  fileInput.files = dt.files;
  setFile(file);
});

const renderLogs = (logs) => {
  logList.innerHTML = "";
  logs.forEach((entry) => {
    const li = document.createElement("li");
    li.textContent = entry;
    logList.appendChild(li);
  });
};

const pollJob = async (jobId) => {
  const timer = setInterval(async () => {
    const res = await fetch(`/api/jobs/${jobId}`);
    const data = await res.json();

    progressEl.style.width = `${data.progress || 0}%`;
    statusText.textContent = data.message || data.status;
    renderLogs(data.logs || []);

    if ((data.warnings || []).length) {
      resultText.textContent = `คำเตือน: ${data.warnings.join(" | ")}`;
    }

    if (data.status === "done") {
      clearInterval(timer);
      downloadBtn.disabled = false;
      resultText.textContent = "งานเสร็จแล้ว สามารถดาวน์โหลดไฟล์ม็อดได้";
    }

    if (data.status === "error") {
      clearInterval(timer);
      resultText.textContent = "เกิดข้อผิดพลาดระหว่างประมวลผล";
    }
  }, 1200);
};

startBtn.addEventListener("click", async () => {
  if (!selectedFile) return;

  const formData = new FormData();
  formData.append("gameFile", selectedFile);

  startBtn.disabled = true;
  downloadBtn.disabled = true;
  statusText.textContent = "กำลังอัปโหลดไฟล์...";
  resultText.textContent = "";

  const res = await fetch("/api/jobs", {
    method: "POST",
    body: formData,
  });

  const data = await res.json();
  if (!res.ok) {
    statusText.textContent = data.error || "อัปโหลดล้มเหลว";
    startBtn.disabled = false;
    return;
  }

  activeJobId = data.jobId;
  statusText.textContent = `เริ่มงาน ${activeJobId}`;
  pollJob(activeJobId);
});

downloadBtn.addEventListener("click", () => {
  if (!activeJobId) return;
  window.location.href = `/api/jobs/${activeJobId}/download`;
});

const DEMO_PAGES = [
  {
    src: '',
    alt: 'Demo manga panel generated with CSS',
    bubbles: [
      { id: createId(), x: 8, y: 8, w: 39, h: 13, text: 'I will protect this town!', translated: '' },
      { id: createId(), x: 52, y: 30, w: 39, h: 13, text: 'The dragon is coming.', translated: '' },
      { id: createId(), x: 14, y: 72, w: 72, h: 13, text: 'Run to the old bridge now!', translated: '' }
    ]
  }
];

const LOCAL_DICTIONARY = new Map([
  ['i will protect this town!', 'ฉันจะปกป้องเมืองนี้เอง!'],
  ['the dragon is coming.', 'มังกรกำลังมาแล้ว'],
  ['run to the old bridge now!', 'รีบวิ่งไปที่สะพานเก่าเดี๋ยวนี้!'],
  ['hello', 'สวัสดี'],
  ['thank you', 'ขอบคุณ'],
  ['sorry', 'ขอโทษ'],
  ['what happened?', 'เกิดอะไรขึ้น?'],
  ['let us go', 'ไปกันเถอะ'],
  ['wait for me', 'รอฉันด้วย'],
  ['no way!', 'เป็นไปไม่ได้!']
]);

const state = {
  mode: 'reader',
  sourceUrl: '',
  imageList: '',
  pages: cloneDemoPages(),
  provider: 'local',
  targetLanguage: 'Thai',
  ollamaUrl: 'http://localhost:11434/api/generate',
  ollamaModel: 'gemma3:4b',
  hfModel: 'google/gemma-2-2b-it',
  hfToken: sessionStorage.getItem('hfToken') || '',
  selectedBubbleId: null,
  isTranslating: false,
  status: 'พร้อมใช้งาน: โหมดเดโมทำงานบนเครื่องทันที'
};

const $app = document.querySelector('#app');

function render() {
  $app.innerHTML = `
    <header class="hero">
      <div>
        <p class="eyebrow">Manga Overlay Translator</p>
        <h1>อ่านมังงะพร้อมคำแปลซ้อนทับแบบเร็วบนมือถือ</h1>
        <p class="lede">วางเว็บ/รูปตอนมังงะ แล้วแปลข้อความในกรอบคำพูดด้วย local dictionary, Ollama หรือ Hugging Face โดยไม่บันทึก token ถาวร</p>
      </div>
      <div class="hero-card">
        <span class="pulse"></span>
        <strong>Realtime-ish overlay</strong>
        <small>เหมาะกับ iPhone, Safari และ PWA</small>
      </div>
    </header>

    <main class="shell">
      <section class="controls panel">
        <div class="tabs" role="tablist" aria-label="reader mode">
          <button class="tab ${state.mode === 'reader' ? 'active' : ''}" data-action="set-mode" data-mode="reader">โหลดรูป</button>
          <button class="tab ${state.mode === 'web' ? 'active' : ''}" data-action="set-mode" data-mode="web">เว็บซ้อนเว็บ</button>
        </div>

        ${state.mode === 'reader' ? renderReaderControls() : renderWebControls()}
        ${renderProviderControls()}

        <div class="button-row">
          <button class="primary" data-action="translate-all" ${state.isTranslating ? 'disabled' : ''}>${state.isTranslating ? 'กำลังแปล…' : 'แปล overlay ทั้งหมด'}</button>
          <button class="secondary" data-action="add-bubble">เพิ่มกรอบคำพูด</button>
          <button class="secondary" data-action="reset-demo">รีเซ็ตเดโม</button>
        </div>
        <p class="status">${escapeHtml(state.status)}</p>
      </section>

      <section class="workspace">
        ${state.mode === 'web' ? renderWebFrame() : renderPages()}
      </section>
    </main>
  `;
}

function renderReaderControls() {
  return `
    <label>
      <span>URL รูปภาพตอนมังงะ (หนึ่ง URL ต่อบรรทัด)</span>
      <textarea id="imageList" placeholder="https://example.com/chapter/page-1.jpg\nhttps://example.com/chapter/page-2.jpg">${escapeHtml(state.imageList)}</textarea>
    </label>
    <div class="hint">ถ้าเว็บปลายทางบล็อก hotlink/CORS ให้ดาวน์โหลดภาพมาใส่เอง หรือทำ proxy ฝั่ง server ที่คุณควบคุมและเคารพเงื่อนไขเว็บต้นทาง</div>
    <button class="secondary full" data-action="load-images">โหลดรูปเข้า reader</button>
  `;
}

function renderWebControls() {
  return `
    <label>
      <span>URL เว็บมังงะสำหรับฝัง iframe</span>
      <input id="sourceUrl" inputmode="url" placeholder="https://example.com/manga/chapter" value="${escapeHtml(state.sourceUrl)}" />
    </label>
    <div class="hint">เว็บจำนวนมากตั้งค่า X-Frame-Options/CSP ทำให้ฝังไม่ได้ และเราไม่ควรบายพาส paywall หรือระบบป้องกันของเว็บ</div>
    <button class="secondary full" data-action="load-web">เปิดเว็บซ้อนเว็บ</button>
  `;
}

function renderProviderControls() {
  return `
    <div class="grid-2">
      <label>
        <span>ตัวแปล</span>
        <select id="provider">
          <option value="local" ${state.provider === 'local' ? 'selected' : ''}>Local เร็วสุด (dictionary/mock)</option>
          <option value="ollama" ${state.provider === 'ollama' ? 'selected' : ''}>Ollama local</option>
          <option value="huggingface" ${state.provider === 'huggingface' ? 'selected' : ''}>Hugging Face cloud</option>
        </select>
      </label>
      <label>
        <span>ภาษาเป้าหมาย</span>
        <input id="targetLanguage" value="${escapeHtml(state.targetLanguage)}" />
      </label>
    </div>
    <details ${state.provider !== 'local' ? 'open' : ''}>
      <summary>ตั้งค่า provider ขั้นสูง</summary>
      <label><span>Ollama endpoint</span><input id="ollamaUrl" value="${escapeHtml(state.ollamaUrl)}" /></label>
      <label><span>Ollama model</span><input id="ollamaModel" value="${escapeHtml(state.ollamaModel)}" /></label>
      <label><span>Hugging Face model</span><input id="hfModel" value="${escapeHtml(state.hfModel)}" /></label>
      <label><span>Hugging Face token (เก็บเฉพาะ session นี้)</span><input id="hfToken" type="password" autocomplete="off" value="${escapeHtml(state.hfToken)}" /></label>
    </details>
  `;
}

function renderWebFrame() {
  const src = normalizeUrl(state.sourceUrl);
  return `
    <div class="phone-frame panel">
      ${src ? `<iframe title="Manga source" src="${escapeHtml(src)}" sandbox="allow-scripts allow-same-origin allow-forms allow-popups"></iframe>` : renderEmptyState('วาง URL เว็บมังงะแล้วกดเปิดเว็บซ้อนเว็บ')}
    </div>
  `;
}

function renderPages() {
  if (!state.pages.length) return renderEmptyState('ยังไม่มีภาพมังงะ');
  return state.pages.map((page, pageIndex) => `
    <article class="manga-page panel" data-page-index="${pageIndex}">
      ${page.src ? `<img src="${escapeHtml(page.src)}" alt="${escapeHtml(page.alt || `Manga page ${pageIndex + 1}`)}" crossorigin="anonymous" loading="lazy" />` : renderDemoPanel()}
      <div class="overlay-layer">
        ${page.bubbles.map((bubble) => renderBubble(bubble, pageIndex)).join('')}
      </div>
    </article>
  `).join('');
}

function renderDemoPanel() {
  return `
    <div class="demo-art" role="img" aria-label="Demo manga page">
      <div class="moon"></div><div class="speed one"></div><div class="speed two"></div><div class="hero-silhouette"></div><div class="dragon"></div>
    </div>
  `;
}

function renderBubble(bubble, pageIndex) {
  const text = bubble.translated || bubble.text || 'แตะเพื่อแก้ข้อความ';
  return `
    <button class="bubble ${state.selectedBubbleId === bubble.id ? 'selected' : ''}" data-action="select-bubble" data-page-index="${pageIndex}" data-bubble-id="${bubble.id}" style="left:${bubble.x}%;top:${bubble.y}%;width:${bubble.w}%;min-height:${bubble.h}%;">
      <span>${escapeHtml(text)}</span>
    </button>
  `;
}

function renderEmptyState(message) {
  return `<div class="empty"><strong>${escapeHtml(message)}</strong><span>เริ่มจากเดโมหรือเพิ่ม URL รูปภาพได้ทันที</span></div>`;
}

$app.addEventListener('input', (event) => {
  const { id, value } = event.target;
  if (!id) return;
  if (id === 'hfToken') sessionStorage.setItem('hfToken', value);
  if (id in state) state[id] = value;
});

$app.addEventListener('change', (event) => {
  const { id, value } = event.target;
  if (!id) return;
  if (id in state) state[id] = value;
  render();
});

$app.addEventListener('click', async (event) => {
  const target = event.target.closest('[data-action]');
  if (!target) return;
  const action = target.dataset.action;

  if (action === 'set-mode') {
    state.mode = target.dataset.mode;
    render();
  }
  if (action === 'load-images') loadImages();
  if (action === 'load-web') {
    state.status = normalizeUrl(state.sourceUrl) ? 'เปิด iframe แล้ว ถ้าเว็บไม่แสดงแปลว่าเว็บต้นทางไม่อนุญาตให้ฝัง' : 'กรุณาใส่ URL ที่ถูกต้อง';
    render();
  }
  if (action === 'translate-all') await translateAll();
  if (action === 'add-bubble') addBubble();
  if (action === 'reset-demo') {
    state.pages = cloneDemoPages();
    state.imageList = '';
    state.status = 'รีเซ็ตเป็นเดโมแล้ว';
    render();
  }
  if (action === 'select-bubble') editBubble(Number(target.dataset.pageIndex), target.dataset.bubbleId);
});

function loadImages() {
  const urls = state.imageList.split('\n').map((url) => normalizeUrl(url.trim())).filter(Boolean);
  state.pages = urls.map((src) => ({ src, alt: 'Imported manga page', bubbles: [] }));
  state.status = urls.length ? `โหลด ${urls.length} รูปแล้ว กด “เพิ่มกรอบคำพูด” เพื่อวาง overlay` : 'ยังไม่มี URL รูปภาพที่ถูกต้อง';
  render();
}

function addBubble() {
  if (!state.pages.length) state.pages = cloneDemoPages();
  state.pages[0].bubbles.push({ id: createId(), x: 12, y: 12, w: 42, h: 12, text: 'hello', translated: '' });
  state.status = 'เพิ่มกรอบคำพูดแล้ว แตะกรอบเพื่อแก้ข้อความต้นฉบับ/ตำแหน่ง';
  render();
}

function editBubble(pageIndex, bubbleId) {
  const bubble = state.pages[pageIndex]?.bubbles.find((item) => item.id === bubbleId);
  if (!bubble) return;
  const text = prompt('ข้อความต้นฉบับในกรอบคำพูด', bubble.text) ?? bubble.text;
  const translated = prompt('คำแปลที่ต้องการแสดง (เว้นว่างเพื่อให้ระบบแปล)', bubble.translated) ?? bubble.translated;
  const position = prompt('ตำแหน่ง x,y,w,h เป็นเปอร์เซ็นต์', `${bubble.x},${bubble.y},${bubble.w},${bubble.h}`);
  if (position) {
    const [x, y, w, h] = position.split(',').map((part) => Number(part.trim()));
    if ([x, y, w, h].every((number) => Number.isFinite(number))) Object.assign(bubble, { x, y, w, h });
  }
  Object.assign(bubble, { text, translated });
  state.selectedBubbleId = bubbleId;
  render();
}

async function translateAll() {
  state.isTranslating = true;
  state.status = 'กำลังแปลข้อความใน overlay…';
  render();
  try {
    for (const page of state.pages) {
      for (const bubble of page.bubbles) {
        if (!bubble.text.trim()) continue;
        bubble.translated = await translateText(bubble.text);
      }
    }
    state.status = 'แปลเสร็จแล้ว';
  } catch (error) {
    state.status = `แปลไม่สำเร็จ: ${error.message}`;
  } finally {
    state.isTranslating = false;
    render();
  }
}

async function translateText(text) {
  if (state.provider === 'ollama') return translateWithOllama(text);
  if (state.provider === 'huggingface') return translateWithHuggingFace(text);
  return translateLocal(text);
}

function translateLocal(text) {
  const normalized = text.trim().toLowerCase();
  if (LOCAL_DICTIONARY.has(normalized)) return LOCAL_DICTIONARY.get(normalized);
  return `[${state.targetLanguage}] ${text}`;
}

async function translateWithOllama(text) {
  const response = await fetch(state.ollamaUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: state.ollamaModel,
      stream: false,
      prompt: `Translate this manga dialogue to ${state.targetLanguage}. Keep it short and natural. Return only the translation.\n\n${text}`
    })
  });
  if (!response.ok) throw new Error(`Ollama HTTP ${response.status}`);
  const data = await response.json();
  return data.response?.trim() || translateLocal(text);
}

async function translateWithHuggingFace(text) {
  if (!state.hfToken.trim()) throw new Error('ต้องใส่ Hugging Face token ก่อน');
  const response = await fetch(`https://api-inference.huggingface.co/models/${encodeURIComponent(state.hfModel)}`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${state.hfToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      inputs: `Translate this manga dialogue to ${state.targetLanguage}. Return only the translation: ${text}`,
      parameters: { max_new_tokens: 80, temperature: 0.2 }
    })
  });
  if (!response.ok) throw new Error(`Hugging Face HTTP ${response.status}`);
  const data = await response.json();
  const generated = Array.isArray(data) ? data[0]?.generated_text : data.generated_text;
  return generated?.replace(/^.*translation:\s*/i, '').trim() || translateLocal(text);
}

function normalizeUrl(url) {
  try {
    if (!url) return '';
    return new URL(url).href;
  } catch {
    return '';
  }
}

function escapeHtml(value) {
  return String(value).replace(/[&<>'"]/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' })[char]);
}

render();


function createId() {
  return globalThis.crypto?.randomUUID?.() || `bubble-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function cloneDemoPages() {
  return DEMO_PAGES.map((page) => ({
    ...page,
    bubbles: page.bubbles.map((bubble) => ({ ...bubble, id: createId() }))
  }));
}


if ('serviceWorker' in navigator && location.protocol !== 'file:') {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('./sw.js').catch(() => {
      // PWA cache is optional; the reader still works without service worker support.
    });
  });
}

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
  ['no way!', 'เป็นไปไม่ได้!'],
  ['yes', 'ใช่'],
  ['no', 'ไม่'],
  ['stop!', 'หยุดนะ!'],
  ['help me!', 'ช่วยด้วย!'],
  ['i love you', 'ฉันรักเธอ'],
  ['good morning', 'อรุณสวัสดิ์'],
  ['good night', 'ราตรีสวัสดิ์']
]);

const DEFAULT_BUBBLE = { w: 42, h: 12 };
const SEARCH_ENGINES = {
  duckduckgo: { label: 'DuckDuckGo', url: 'https://duckduckgo.com/?q=' },
  google: { label: 'Google', url: 'https://www.google.com/search?q=' },
  bing: { label: 'Bing', url: 'https://www.bing.com/search?q=' },
  brave: { label: 'Brave Search', url: 'https://search.brave.com/search?q=' }
};
const translationCache = new Map();

const state = {
  mode: 'reader',
  sourceUrl: '',
  imageList: '',
  extractHtml: '',
  searchQuery: '',
  searchScope: 'manga',
  searchEngine: 'duckduckgo',
  searchEndpoint: '',
  searchResults: [],
  isSearching: false,
  pages: cloneDemoPages(),
  provider: 'local',
  targetLanguage: 'Thai',
  autoTranslate: true,
  ollamaUrl: 'http://localhost:11434/api/generate',
  ollamaCloudUrl: 'https://ollama.com/api/generate',
  ollamaModel: 'gemma3:4b',
  ollamaCloudModel: 'gemma4:e4b',
  ollamaApiKey: sessionStorage.getItem('ollamaApiKey') || '',
  hfModel: 'google/gemma-2-2b-it',
  hfToken: sessionStorage.getItem('hfToken') || '',
  selectedBubbleId: null,
  isTranslating: false,
  status: 'พร้อมใช้งาน: โหมด local ทำงานทันทีและเร็วที่สุดบน iPhone'
};

const $app = document.querySelector('#app');

function render() {
  $app.innerHTML = `
    <header class="hero">
      <div>
        <p class="eyebrow">Manga Overlay Translator</p>
        <h1>แปลมังงะด้วย overlay เร็วบนมือถือ</h1>
        <p class="lede">ค้นหาเว็บมังงะหรือเว็บทั่วไป วาง URL รูป/HTML ที่คุณมีสิทธิ์อ่าน แล้วซ้อนคำแปลบนภาพแบบ local-first พร้อมต่อ Ollama, Ollama Cloud หรือ Hugging Face ได้</p>
      </div>
      <div class="hero-card">
        <span class="pulse"></span>
        <strong>Local-first + PWA</strong>
        <small>แตะภาพเพื่อวางกรอบ / cache คำแปล / เหมาะกับ Safari iPhone</small>
      </div>
    </header>

    <main class="shell">
      <section class="controls panel">
        <div class="tabs" role="tablist" aria-label="reader mode">
          <button class="tab ${state.mode === 'reader' ? 'active' : ''}" data-action="set-mode" data-mode="reader">โหลดรูป</button>
          <button class="tab ${state.mode === 'web' ? 'active' : ''}" data-action="set-mode" data-mode="web">เว็บซ้อนเว็บ</button>
          <button class="tab ${state.mode === 'search' ? 'active' : ''}" data-action="set-mode" data-mode="search">ค้นหาเว็บ</button>
        </div>

        ${renderModeControls()}
        ${state.mode !== 'search' ? renderProviderControls() : renderSearchTips()}
        ${renderUsageNotes()}

        <div class="button-row">
          ${state.mode === 'search'
            ? `<button class="primary" data-action="open-search-engine">เปิดผลค้นหา</button><button class="secondary" data-action="search-web" ${state.isSearching ? 'disabled' : ''}>${state.isSearching ? 'กำลังค้นหา…' : 'ค้นหาในแอป'}</button><button class="secondary" data-action="clear-search">ล้างผล</button>`
            : `<button class="primary" data-action="translate-all" ${state.isTranslating ? 'disabled' : ''}>${state.isTranslating ? 'กำลังแปล…' : 'แปล overlay ทั้งหมด'}</button><button class="secondary" data-action="add-bubble">เพิ่มกรอบ</button><button class="secondary" data-action="reset-demo">เดโม</button>`}
        </div>
        <p class="status" role="status">${escapeHtml(state.status)}</p>
      </section>

      <section class="workspace">
        ${renderWorkspace()}
      </section>
    </main>
  `;
}

function renderModeControls() {
  if (state.mode === 'search') return renderSearchControls();
  if (state.mode === 'web') return renderWebControls();
  return renderReaderControls();
}

function renderReaderControls() {
  return `
    <label>
      <span>URL รูปภาพตอนมังงะ (หนึ่ง URL ต่อบรรทัด)</span>
      <textarea id="imageList" placeholder="https://example.com/chapter/page-1.jpg\nhttps://example.com/chapter/page-2.jpg">${escapeHtml(state.imageList)}</textarea>
    </label>
    <div class="mini-actions">
      <button class="secondary" data-action="load-images">โหลดรูปเข้า reader</button>
      <button class="secondary" data-action="clear-pages">ล้างหน้า</button>
    </div>
    <details>
      <summary>ดึง URL รูปจาก HTML ที่คัดลอกมา</summary>
      <label>
        <span>วาง HTML/source ของหน้าเว็บมังงะ</span>
        <textarea id="extractHtml" placeholder="วางโค้ด HTML ที่มี <img src=...> หรือ URL รูปภาพ">${escapeHtml(state.extractHtml)}</textarea>
      </label>
      <button class="secondary full" data-action="extract-images">แยก URL รูปภาพจากข้อความ</button>
      <p class="hint">เพื่อความถูกต้องตามกฎหมาย แอปไม่ bypass CORS, paywall, anti-hotlink หรือระบบป้องกันของเว็บต้นทาง</p>
    </details>
  `;
}

function renderWebControls() {
  return `
    <label>
      <span>URL เว็บมังงะสำหรับฝัง iframe</span>
      <input id="sourceUrl" inputmode="url" placeholder="https://example.com/manga/chapter" value="${escapeHtml(state.sourceUrl)}" />
    </label>
    <div class="hint">โหมดเว็บซ้อนเว็บทำได้เฉพาะเว็บที่อนุญาต iframe เท่านั้น ถ้าไม่แสดงให้ใช้โหมดโหลดรูปแทน</div>
    <button class="secondary full" data-action="load-web">เปิดเว็บซ้อนเว็บ</button>
  `;
}


function renderSearchControls() {
  return `
    <label>
      <span>ค้นหาเว็บมังงะหรือเว็บทั่วไป</span>
      <input id="searchQuery" type="search" enterkeyhint="search" placeholder="ชื่อเรื่อง / เว็บ / คำค้น" value="${escapeHtml(state.searchQuery)}" />
    </label>
    <div class="grid-2">
      <label>
        <span>ประเภท</span>
        <select id="searchScope">
          <option value="manga" ${state.searchScope === 'manga' ? 'selected' : ''}>มังงะ / อ่านถูกลิขสิทธิ์</option>
          <option value="web" ${state.searchScope === 'web' ? 'selected' : ''}>เว็บทั่วไป</option>
          <option value="images" ${state.searchScope === 'images' ? 'selected' : ''}>ค้นหารูปภาพ</option>
        </select>
      </label>
      <label>
        <span>Search engine</span>
        <select id="searchEngine">
          ${Object.entries(SEARCH_ENGINES).map(([key, engine]) => `<option value="${key}" ${state.searchEngine === key ? 'selected' : ''}>${engine.label}</option>`).join('')}
        </select>
      </label>
    </div>
    <details>
      <summary>ค้นหาในแอปด้วย SearXNG (ตัวเลือก)</summary>
      <label>
        <span>SearXNG JSON endpoint ที่เปิด CORS</span>
        <input id="searchEndpoint" inputmode="url" placeholder="https://searx.example.com/search" value="${escapeHtml(state.searchEndpoint)}" />
      </label>
      <p class="hint">ถ้าไม่ใส่ endpoint แอปจะเปิดผลค้นหาใน engine ที่เลือกแทน เพราะ search engine ส่วนใหญ่บล็อกการดึงผลจาก browser โดยตรง</p>
    </details>
  `;
}

function renderSearchTips() {
  return `
    <details class="note-card" open>
      <summary>ทำเป็นเว็บไซต์จริง + ค้นหาเว็บได้อย่างไร</summary>
      <ul>
        <li>เว็บนี้เป็น static site: deploy ฟรีบน GitHub Pages, Netlify หรือ Vercel ได้จาก repo นี้</li>
        <li>การค้นหาทำได้แบบเปิดผลค้นหาใน DuckDuckGo/Google/Bing/Brave ทันที และถ้ามี SearXNG endpoint ที่เปิด CORS จะดึงผลมาแสดงในแอปได้</li>
        <li>เมื่อเจอเว็บ/ตอนที่ต้องการ ให้นำ URL ไปเปิดใน “เว็บซ้อนเว็บ” หรือคัดลอก URL/HTML รูปกลับมาใส่ “โหลดรูป”</li>
      </ul>
    </details>
  `;
}

function renderProviderControls() {
  return `
    <div class="grid-2">
      <label>
        <span>ตัวแปล</span>
        <select id="provider">
          <option value="local" ${state.provider === 'local' ? 'selected' : ''}>Local เร็วสุด (dictionary/cache)</option>
          <option value="ollama" ${state.provider === 'ollama' ? 'selected' : ''}>Ollama local</option>
          <option value="ollama-cloud" ${state.provider === 'ollama-cloud' ? 'selected' : ''}>Ollama Cloud</option>
          <option value="huggingface" ${state.provider === 'huggingface' ? 'selected' : ''}>Hugging Face cloud</option>
        </select>
      </label>
      <label>
        <span>ภาษาเป้าหมาย</span>
        <input id="targetLanguage" value="${escapeHtml(state.targetLanguage)}" />
      </label>
    </div>
    <label class="toggle-row">
      <input id="autoTranslate" type="checkbox" ${state.autoTranslate ? 'checked' : ''} />
      <span>แปลทันทีเมื่อแก้ข้อความในกรอบ (ใช้ cache เพื่อลดเวลา)</span>
    </label>
    <details ${state.provider !== 'local' ? 'open' : ''}>
      <summary>ตั้งค่า provider ขั้นสูง</summary>
      <label><span>Ollama local endpoint</span><input id="ollamaUrl" value="${escapeHtml(state.ollamaUrl)}" /></label>
      <label><span>Ollama local model</span><input id="ollamaModel" value="${escapeHtml(state.ollamaModel)}" placeholder="gemma3:4b หรือ gemma4:e4b ถ้ามีในเครื่อง" /></label>
      <label><span>Ollama Cloud endpoint</span><input id="ollamaCloudUrl" value="${escapeHtml(state.ollamaCloudUrl)}" /></label>
      <label><span>Ollama Cloud model</span><input id="ollamaCloudModel" value="${escapeHtml(state.ollamaCloudModel)}" placeholder="เช่น gemma4:e4b หรือ model cloud ที่บัญชีคุณรองรับ" /></label>
      <label><span>Ollama API key (เก็บเฉพาะ session นี้)</span><input id="ollamaApiKey" type="password" autocomplete="off" value="${escapeHtml(state.ollamaApiKey)}" /></label>
      <label><span>Hugging Face model</span><input id="hfModel" value="${escapeHtml(state.hfModel)}" /></label>
      <label><span>Hugging Face token (เก็บเฉพาะ session นี้)</span><input id="hfToken" type="password" autocomplete="off" value="${escapeHtml(state.hfToken)}" /></label>
    </details>
  `;
}

function renderUsageNotes() {
  return `
    <details class="note-card">
      <summary>คำตอบเรื่อง Gemma/Ollama/iPhone</summary>
      <ul>
        <li>บน iPhone ให้ใช้ local dictionary/cache เพื่อเร็วสุด หรือเรียก cloud ผ่าน HTTPS</li>
        <li>Ollama local จาก iPhone ต้องให้เครื่องที่รัน Ollama เปิด CORS/เครือข่ายและเปลี่ยน endpoint เป็น IP ในวง Wi‑Fi</li>
        <li>Ollama Cloud ใช้ได้ถ้ามี API key และ model นั้นเปิดให้บัญชีคุณใช้งาน; ใส่ชื่อ Gemma ที่รองรับในช่อง model ได้</li>
        <li>OCR เต็มรูปแบบยังไม่รวมใน static app นี้: แตะภาพเพื่อเพิ่มกรอบและพิมพ์ข้อความ หรือเชื่อม backend OCR/vision model ภายหลัง</li>
      </ul>
    </details>
  `;
}

function renderWorkspace() {
  if (state.mode === 'search') return renderSearchWorkspace();
  if (state.mode === 'web') return renderWebFrame();
  return renderPages();
}


function renderSearchWorkspace() {
  const query = buildSearchQuery();
  const searchUrl = buildSearchUrl(query);
  return `
    <section class="search-board panel">
      <div class="search-hero">
        <p class="eyebrow">Search launcher</p>
        <h2>ค้นหาเว็บก่อน แล้วส่งต่อเข้า reader/iframe</h2>
        <p>Static website ไม่สามารถ scrape Google หรือเว็บมังงะจาก browser ได้โดยตรงอย่างเสถียรเพราะ CORS/ToS ดังนั้นโหมดนี้จะเปิดผลค้นหาอย่างรวดเร็ว และรองรับ SearXNG JSON หากคุณตั้ง endpoint เอง</p>
        <div class="search-actions">
          <a class="primary link-button" href="${escapeHtml(searchUrl)}" target="_blank" rel="noopener noreferrer">เปิด ${escapeHtml(getSearchEngine().label)}</a>
          <button class="secondary" data-action="search-web" ${state.isSearching ? 'disabled' : ''}>${state.isSearching ? 'กำลังค้นหา…' : 'ค้นหาในแอป'}</button>
        </div>
      </div>
      <div class="search-query-preview">
        <strong>คำค้นที่จะใช้</strong>
        <code>${escapeHtml(query || 'ยังไม่ได้ใส่คำค้น')}</code>
      </div>
      ${state.searchResults.length ? renderSearchResults() : renderSearchEmpty()}
    </section>
  `;
}

function renderSearchResults() {
  return `
    <div class="result-list">
      ${state.searchResults.map((result, index) => `
        <article class="result-card">
          <span>ผลลัพธ์ #${index + 1}</span>
          <h3>${escapeHtml(result.title || result.url)}</h3>
          <p>${escapeHtml(result.content || result.url)}</p>
          <div class="result-actions">
            <a class="secondary link-button" href="${escapeHtml(result.url)}" target="_blank" rel="noopener noreferrer">เปิดเว็บ</a>
            <button class="secondary" data-action="use-result-url" data-url="${escapeHtml(result.url)}">เปิดในเว็บซ้อนเว็บ</button>
            <button class="secondary" data-action="copy-result-url" data-url="${escapeHtml(result.url)}">คัดลอก URL</button>
          </div>
        </article>
      `).join('')}
    </div>
  `;
}

function renderSearchEmpty() {
  return `
    <div class="empty search-empty">
      <strong>ยังไม่มีผลค้นหาในแอป</strong>
      <span>กด “เปิดผลค้นหา” เพื่อค้นหาผ่าน engine ที่เลือก หรือใส่ SearXNG endpoint แล้วกด “ค้นหาในแอป”</span>
    </div>
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
    <article class="manga-page panel" data-action="page-tap" data-page-index="${pageIndex}">
      ${page.src ? `<img src="${escapeHtml(page.src)}" alt="${escapeHtml(page.alt || `Manga page ${pageIndex + 1}`)}" crossorigin="anonymous" loading="lazy" />` : renderDemoPanel()}
      <div class="overlay-layer">
        ${page.bubbles.map((bubble) => renderBubble(bubble, pageIndex)).join('')}
      </div>
      <div class="page-tools">หน้า ${pageIndex + 1} · แตะพื้นที่ว่างเพื่อเพิ่มกรอบ</div>
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
  return `<div class="empty panel"><strong>${escapeHtml(message)}</strong><span>เริ่มจากเดโม วาง URL รูปภาพ หรือวาง HTML เพื่อดึงรูปได้ทันที</span></div>`;
}

$app.addEventListener('input', (event) => {
  const { id, value, type, checked } = event.target;
  if (!id) return;
  const nextValue = type === 'checkbox' ? checked : value;
  if (id === 'hfToken') sessionStorage.setItem('hfToken', value);
  if (id === 'ollamaApiKey') sessionStorage.setItem('ollamaApiKey', value);
  if (id in state) state[id] = nextValue;
});

$app.addEventListener('change', (event) => {
  const { id, value, type, checked } = event.target;
  if (!id) return;
  if (id in state) state[id] = type === 'checkbox' ? checked : value;
  render();
});

$app.addEventListener('keydown', async (event) => {
  if (event.key === 'Enter' && event.target.id === 'searchQuery') {
    event.preventDefault();
    openSearchEngine();
  }
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
  if (action === 'clear-pages') {
    state.pages = [];
    state.status = 'ล้างหน้า reader แล้ว';
    render();
  }
  if (action === 'extract-images') extractImagesFromText();
  if (action === 'load-web') {
    state.status = normalizeUrl(state.sourceUrl) ? 'เปิด iframe แล้ว ถ้าเว็บไม่แสดงแปลว่าเว็บต้นทางไม่อนุญาตให้ฝัง' : 'กรุณาใส่ URL ที่ถูกต้อง';
    render();
  }
  if (action === 'open-search-engine') openSearchEngine();
  if (action === 'search-web') await searchWeb();
  if (action === 'clear-search') {
    state.searchResults = [];
    state.status = 'ล้างผลค้นหาแล้ว';
    render();
  }
  if (action === 'use-result-url') {
    state.sourceUrl = target.dataset.url;
    state.mode = 'web';
    state.status = 'ส่ง URL จากผลค้นหาไปยังโหมดเว็บซ้อนเว็บแล้ว';
    render();
  }
  if (action === 'copy-result-url') await copyText(target.dataset.url);
  if (action === 'translate-all') await translateAll();
  if (action === 'add-bubble') addBubble();
  if (action === 'reset-demo') {
    state.pages = cloneDemoPages();
    state.imageList = '';
    state.extractHtml = '';
    state.status = 'รีเซ็ตเป็นเดโมแล้ว';
    render();
  }
  if (action === 'select-bubble') {
    event.stopPropagation();
    await editBubble(Number(target.dataset.pageIndex), target.dataset.bubbleId);
  }
  if (action === 'page-tap' && !event.target.closest('.bubble')) addBubbleAtPoint(target, event);
});

function buildSearchQuery() {
  const query = state.searchQuery.trim();
  if (!query) return '';
  if (state.searchScope === 'manga') return `${query} manga official chapter read online`;
  if (state.searchScope === 'images') return `${query} manga page image`;
  return query;
}

function getSearchEngine() {
  return SEARCH_ENGINES[state.searchEngine] || SEARCH_ENGINES.duckduckgo;
}

function buildSearchUrl(query = buildSearchQuery()) {
  return `${getSearchEngine().url}${encodeURIComponent(query || 'manga')}`;
}

function openSearchEngine() {
  const query = buildSearchQuery();
  if (!query) {
    state.status = 'กรุณาใส่คำค้นก่อน';
    render();
    return;
  }
  window.open(buildSearchUrl(query), '_blank', 'noopener,noreferrer');
  state.status = 'เปิดผลค้นหาในแท็บใหม่แล้ว เมื่อเจอหน้าที่ต้องการให้คัดลอก URL กลับมาโหลดในแอป';
  render();
}

async function searchWeb() {
  const query = buildSearchQuery();
  if (!query) {
    state.status = 'กรุณาใส่คำค้นก่อน';
    render();
    return;
  }
  const endpoint = normalizeUrl(state.searchEndpoint.trim());
  if (!endpoint) {
    openSearchEngine();
    return;
  }

  state.isSearching = true;
  state.status = 'กำลังค้นหาผ่าน SearXNG endpoint…';
  render();
  try {
    const url = new URL(endpoint);
    url.searchParams.set('q', query);
    url.searchParams.set('format', 'json');
    const response = await fetch(url);
    if (!response.ok) throw new Error(`Search HTTP ${response.status}`);
    const data = await response.json();
    state.searchResults = (data.results || [])
      .map((item) => ({ title: item.title || item.url, url: normalizeUrl(item.url), content: item.content || item.pretty_url || '' }))
      .filter((item) => item.url)
      .slice(0, 12);
    state.status = state.searchResults.length ? `พบผลค้นหา ${state.searchResults.length} รายการ` : 'ไม่พบผลค้นหาจาก endpoint นี้';
  } catch (error) {
    state.status = `ค้นหาในแอปไม่สำเร็จ: ${error.message} — ลองกดเปิดผลค้นหาแทน`;
  } finally {
    state.isSearching = false;
    render();
  }
}

async function copyText(value) {
  try {
    await navigator.clipboard.writeText(value);
    state.status = 'คัดลอก URL แล้ว';
  } catch {
    state.status = 'คัดลอกอัตโนมัติไม่ได้ ให้กดเปิดเว็บแล้ว copy จากแถบที่อยู่แทน';
  }
  render();
}

function loadImages() {
  const urls = state.imageList.split('\n').map((url) => normalizeUrl(url.trim())).filter(Boolean);
  state.pages = urls.map((src, index) => ({ src, alt: `Imported manga page ${index + 1}`, bubbles: [] }));
  state.status = urls.length ? `โหลด ${urls.length} รูปแล้ว แตะภาพเพื่อวาง overlay` : 'ยังไม่มี URL รูปภาพที่ถูกต้อง';
  render();
}

function extractImagesFromText() {
  const urls = extractImageUrls(state.extractHtml);
  state.imageList = urls.join('\n');
  state.pages = urls.map((src, index) => ({ src, alt: `Extracted manga page ${index + 1}`, bubbles: [] }));
  state.status = urls.length ? `แยก URL รูปภาพได้ ${urls.length} รายการและโหลดเข้า reader แล้ว` : 'ไม่พบ URL รูปภาพในข้อความที่วาง';
  render();
}

function addBubble() {
  if (!state.pages.length) state.pages = cloneDemoPages();
  state.pages[0].bubbles.push({ id: createId(), x: 12, y: 12, ...DEFAULT_BUBBLE, text: 'hello', translated: '' });
  state.status = 'เพิ่มกรอบคำพูดแล้ว แตะกรอบเพื่อแก้ข้อความ/ตำแหน่ง';
  render();
}

function addBubbleAtPoint(pageElement, event) {
  const pageIndex = Number(pageElement.dataset.pageIndex);
  const rect = pageElement.getBoundingClientRect();
  const x = clamp(((event.clientX - rect.left) / rect.width) * 100 - DEFAULT_BUBBLE.w / 2, 0, 100 - DEFAULT_BUBBLE.w);
  const y = clamp(((event.clientY - rect.top) / rect.height) * 100 - DEFAULT_BUBBLE.h / 2, 0, 100 - DEFAULT_BUBBLE.h);
  state.pages[pageIndex].bubbles.push({ id: createId(), x: round1(x), y: round1(y), ...DEFAULT_BUBBLE, text: '', translated: '' });
  state.status = 'วางกรอบใหม่แล้ว แตะกรอบเพื่อใส่ข้อความต้นฉบับ';
  render();
}

async function editBubble(pageIndex, bubbleId) {
  const bubble = state.pages[pageIndex]?.bubbles.find((item) => item.id === bubbleId);
  if (!bubble) return;
  const text = prompt('ข้อความต้นฉบับในกรอบคำพูด', bubble.text) ?? bubble.text;
  const translated = prompt('คำแปลที่ต้องการแสดง (เว้นว่างเพื่อให้ระบบแปล)', bubble.translated) ?? bubble.translated;
  const position = prompt('ตำแหน่ง x,y,w,h เป็นเปอร์เซ็นต์', `${bubble.x},${bubble.y},${bubble.w},${bubble.h}`);
  if (position) {
    const [x, y, w, h] = position.split(',').map((part) => Number(part.trim()));
    if ([x, y, w, h].every((number) => Number.isFinite(number))) {
      Object.assign(bubble, { x: clamp(x, 0, 99), y: clamp(y, 0, 99), w: clamp(w, 10, 100), h: clamp(h, 6, 60) });
    }
  }
  Object.assign(bubble, { text, translated });
  state.selectedBubbleId = bubbleId;

  if (state.autoTranslate && text.trim() && !translated.trim()) {
    state.status = 'กำลังแปลกรอบที่เลือก…';
    render();
    try {
      bubble.translated = await translateText(text);
      state.status = 'แปลกรอบที่เลือกแล้ว';
    } catch (error) {
      state.status = `แปลไม่สำเร็จ: ${error.message}`;
    }
  }
  render();
}

async function translateAll() {
  state.isTranslating = true;
  state.status = 'กำลังแปลข้อความใน overlay…';
  render();
  try {
    const jobs = state.pages.flatMap((page) => page.bubbles.filter((bubble) => bubble.text.trim()));
    for (const bubble of jobs) {
      bubble.translated = await translateText(bubble.text);
    }
    state.status = jobs.length ? `แปลเสร็จแล้ว ${jobs.length} กรอบ` : 'ยังไม่มีข้อความให้แปลในกรอบ overlay';
  } catch (error) {
    state.status = `แปลไม่สำเร็จ: ${error.message}`;
  } finally {
    state.isTranslating = false;
    render();
  }
}

async function translateText(text) {
  const cacheKey = `${state.provider}|${state.targetLanguage}|${text.trim().toLowerCase()}`;
  if (translationCache.has(cacheKey)) return translationCache.get(cacheKey);

  let translated;
  if (state.provider === 'ollama') translated = await translateWithOllama(text, state.ollamaUrl, state.ollamaModel);
  else if (state.provider === 'ollama-cloud') translated = await translateWithOllama(text, state.ollamaCloudUrl, state.ollamaCloudModel, state.ollamaApiKey);
  else if (state.provider === 'huggingface') translated = await translateWithHuggingFace(text);
  else translated = translateLocal(text);

  translationCache.set(cacheKey, translated);
  return translated;
}

function translateLocal(text) {
  const normalized = text.trim().toLowerCase();
  if (LOCAL_DICTIONARY.has(normalized)) return LOCAL_DICTIONARY.get(normalized);
  return `[${state.targetLanguage}] ${text}`;
}

async function translateWithOllama(text, endpoint, model, apiKey = '') {
  if (!normalizeUrl(endpoint)) throw new Error('Ollama endpoint ไม่ถูกต้อง');
  if (!model.trim()) throw new Error('ต้องใส่ชื่อ Ollama model');
  if (endpoint.startsWith('https://ollama.com') && !apiKey.trim()) throw new Error('Ollama Cloud ต้องใช้ API key');

  const headers = { 'Content-Type': 'application/json' };
  if (apiKey.trim()) headers.Authorization = `Bearer ${apiKey.trim()}`;

  const response = await fetch(endpoint, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      model: model.trim(),
      stream: false,
      prompt: buildTranslatePrompt(text)
    })
  });
  if (!response.ok) throw new Error(`Ollama HTTP ${response.status}`);
  const data = await response.json();
  return data.response?.trim() || data.message?.content?.trim() || translateLocal(text);
}

async function translateWithHuggingFace(text) {
  if (!state.hfToken.trim()) throw new Error('ต้องใส่ Hugging Face token ก่อน');
  const response = await fetch(`https://api-inference.huggingface.co/models/${encodeURIComponent(state.hfModel)}`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${state.hfToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      inputs: buildTranslatePrompt(text),
      parameters: { max_new_tokens: 80, temperature: 0.2 }
    })
  });
  if (!response.ok) throw new Error(`Hugging Face HTTP ${response.status}`);
  const data = await response.json();
  const generated = Array.isArray(data) ? data[0]?.generated_text : data.generated_text;
  return cleanupTranslation(generated, text) || translateLocal(text);
}

function buildTranslatePrompt(text) {
  return `Translate this manga dialogue to ${state.targetLanguage}. Keep it short, natural, and suitable for a speech bubble. Return only the translation.\n\n${text}`;
}

function cleanupTranslation(value, originalText) {
  if (!value) return '';
  return String(value)
    .replace(buildTranslatePrompt(originalText), '')
    .replace(/^.*translation:\s*/i, '')
    .trim();
}

function extractImageUrls(value) {
  const urls = new Set();
  const text = String(value || '');
  const imageUrlPattern = /https?:\/\/[^\s"'<>]+?\.(?:avif|webp|png|jpe?g|gif)(?:\?[^\s"'<>]*)?/gi;
  for (const match of text.matchAll(imageUrlPattern)) urls.add(decodeHtml(match[0]));

  try {
    const doc = new DOMParser().parseFromString(text, 'text/html');
    doc.querySelectorAll('img, source').forEach((node) => {
      const candidates = [node.getAttribute('src'), node.getAttribute('data-src'), node.getAttribute('data-original'), node.getAttribute('srcset')]
        .filter(Boolean)
        .flatMap((item) => item.split(',').map((part) => part.trim().split(/\s+/)[0]));
      candidates.map(decodeHtml).map(normalizeUrl).filter(Boolean).forEach((url) => urls.add(url));
    });
  } catch {
    // Plain text extraction above is enough when DOMParser cannot parse a fragment.
  }

  return [...urls].filter((url) => /\.(?:avif|webp|png|jpe?g|gif)(?:\?|$)/i.test(url));
}

function normalizeUrl(url) {
  try {
    if (!url) return '';
    return new URL(url).href;
  } catch {
    return '';
  }
}

function decodeHtml(value) {
  const textarea = document.createElement('textarea');
  textarea.innerHTML = value;
  return textarea.value;
}

function escapeHtml(value) {
  return String(value).replace(/[&<>'"]/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' })[char]);
}

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

function round1(value) {
  return Math.round(value * 10) / 10;
}

function createId() {
  return globalThis.crypto?.randomUUID?.() || `bubble-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function cloneDemoPages() {
  return DEMO_PAGES.map((page) => ({
    ...page,
    bubbles: page.bubbles.map((bubble) => ({ ...bubble, id: createId() }))
  }));
}

render();

if ('serviceWorker' in navigator && location.protocol !== 'file:') {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('./sw.js').catch(() => {
      // PWA cache is optional; the reader still works without service worker support.
    });
  });
}

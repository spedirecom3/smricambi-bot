import { Buffer as Buffer2 } from "node:buffer";

var CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type"
};
var WA_API = "https://graph.facebook.com/v20.0";
var WA_PHONE_ID = "1138721115984287";

function formatWhatsAppText(text) {
  if (!text) return "";
  return text.replace(/\*\*(.*?)\*\*/g, "*$1*");
}

function escapeHTML(str) {
  if (!str) return '';
  return str.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#039;");
}

var src_default = {
  async getSafeJSON(env2, key, defaultVal) {
    try {
      const DB = env2.SMR_DB || env2.DB;
      const raw = await DB.get(key);
      if (!raw || raw === "null") return defaultVal;
      return JSON.parse(raw);
    } catch (e) { return defaultVal; }
  },

  async saveLog(p, obj, env2, statusObj) {
    const DB = env2.SMR_DB || env2.DB;
    let chat = await this.getSafeJSON(env2, `chat_${p}`, []);
    if (!Array.isArray(chat)) chat = [];
    if (obj.text && obj.text.startsWith("data:image") && obj.text.length > 1000) {
      obj.text = "[Immagine Elaborata dall'OCR del Sistema]";
    }
    chat.push(obj);
    await DB.put(`chat_${p}`, JSON.stringify(chat.slice(-150)));
    
    let snap = await this.getSafeJSON(env2, "crm_snapshot", {});
    if (!snap[p]) snap[p] = {};
    snap[p].status = statusObj || await this.getSafeJSON(env2, `status_${p}`, { name: "Cliente", channel: "web" });
    snap[p].lastMessage = obj;
    snap[p].lastUpdate = Date.now();
    await DB.put("crm_snapshot", JSON.stringify(snap));
  },

  async processImageOCR(mediaId, mediaType, from, env2, st) {
    try {
      const BUCKET = env2.SMR_BUCKET || env2.BUCKET;
      const DB = env2.SMR_DB || env2.DB;
      let base64Image = "";
      if (mediaType === "image") {
        if (mediaId.startsWith("r2_")) {
          let obj = await BUCKET.get(mediaId.replace("r2_", ""));
          let arrBuffer = await obj.arrayBuffer();
          base64Image = "data:image/jpeg;base64," + Buffer2.from(arrBuffer).toString("base64");
        } else {
          const infoRes = await fetch(`${WA_API}/${mediaId}`, { headers: { "Authorization": `Bearer ${env2.WHATSAPP_TOKEN}` } });
          const info3 = await infoRes.json();
          const mediaRes = await fetch(info3.url, { headers: { "Authorization": `Bearer ${env2.WHATSAPP_TOKEN}` } });
          let arrBuffer = await mediaRes.arrayBuffer();
          base64Image = "data:image/jpeg;base64," + Buffer2.from(arrBuffer).toString("base64");
        }
      }
      if (base64Image) {
        const aiRes = await fetch("https://api.openai.com/v1/chat/completions", {
          method: "POST",
          headers: { "Authorization": `Bearer ${env2.OPENAI_API_KEY}`, "Content-Type": "application/json" },
          body: JSON.stringify({
            model: "gpt-4o-mini",
            messages: [{ role: "user", content: [
              { type: "text", text: "Estrai SOLAMENTE questi dati se presenti: Codice Caldaia/Clima, Matricola completa, Modello completo, Anno. Rispondi in formato elenco pulito." },
              { type: "image_url", image_url: { url: base64Image } }
            ] }],
            temperature: 0.1
          })
        });
        const aiData = await aiRes.json();
        let extractedContent = aiData.choices[0].message.content;
        st.ocrData = extractedContent;
        await DB.put(`status_${from}`, JSON.stringify(st));
        await this.saveLog(from, { from: "system", text: `📝 DATI ESTRATTI DALLA TARGHETTA:\n${extractedContent}`, timestamp: Date.now() }, env2, st);
      }
    } catch (e) { console.error("OCR Failed", e); }
  },

  async fetch(request, env2, ctx) {
    const url = new URL(request.url);
    if (request.method === "OPTIONS") return new Response(null, { headers: CORS });
    const DB = env2.SMR_DB || env2.DB;

    try {
      if (url.pathname === "/admin") return new Response(this.getAdminHTML(), { headers: { "Content-Type": "text/html;charset=UTF-8" } });
      
      if (url.pathname === "/api/chats") {
        let list = await DB.list({ prefix: "chat_" });
        let snapshotData = [];
        for (const k of list.keys) {
          const phone = k.name.replace("chat_", "");
          const messages = await this.getSafeJSON(env2, k.name, []);
          const status = await this.getSafeJSON(env2, `status_${phone}`, { name: "Cliente Anonimo", channel: "web", email: "-", cellulare: "-" });
          if (messages.length > 0) {
            snapshotData.push({
              phone,
              ...status,
              lastUpdate: messages[messages.length - 1].timestamp || Date.now(),
              msgCount: messages.length,
              lastMsgText: messages[messages.length - 1].text || "📎 Allegato Multimediale"
            });
          }
        }
        snapshotData.sort((a, b) => b.lastUpdate - a.lastUpdate);
        return new Response(JSON.stringify(snapshotData), { headers: CORS });
      }
      
      if (url.pathname === "/api/chat_detail") {
        const phone = url.searchParams.get("phone");
        const messages = await this.getSafeJSON(env2, `chat_${phone}`, []);
        return new Response(JSON.stringify(messages), { headers: CORS });
      }

      if (url.pathname === "/api/reply" && request.method === "POST") {
        const { phone, text } = await request.json();
        let st = await this.getSafeJSON(env2, `status_${phone}`, { name: "Cliente", channel: "web" });
        await this.saveLog(phone, { from: "admin", text: text, timestamp: Date.now() }, env2, st);
        return new Response(JSON.stringify({ ok: true }), { headers: CORS });
      }

      if (url.pathname === "/api/toggle" && request.method === "POST") {
        const { phone, manual } = await request.json();
        let st = await this.getSafeJSON(env2, `status_${phone}`, {});
        st.manual = manual; st.until = manual ? Date.now() + 864e5 * 2 : 0;
        await DB.put(`status_${phone}`, JSON.stringify(st));
        await this.saveLog(phone, { from: "system", text: manual ? "L'operatore ha preso il controllo manuale della chat." : "Controllo ripassato all'Intelligenza Artificiale.", timestamp: Date.now() }, env2, st);
        return new Response(JSON.stringify({ ok: true }), { headers: CORS });
      }

      if (url.pathname === "/api/resolve" && request.method === "POST") {
        const { phone } = await request.json();
        let st = await this.getSafeJSON(env2, `status_${phone}`, {});
        st.resolved = true; st.manual = false; st.until = 0;
        await DB.put(`status_${phone}`, JSON.stringify(st));
        await this.saveLog(phone, { from: "system", text: "Conversazione archiviata con successo.", timestamp: Date.now() }, env2, st);
        return new Response(JSON.stringify({ ok: true }), { headers: CORS });
      }

      return new Response("SMR OS ACTIVE");
    } catch (err) {
      return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: CORS });
    }
  },

  getAdminHTML() {
    return `<!DOCTYPE html>
<html lang="it">
<head>
  <meta charset="UTF-8">
  <title>SMR OS - Control Center v56</title>
  <script src="https://cdn.tailwindcss.com"><\/script>
  <style>
    body { margin: 0; padding: 0; background-color: #09090b; color: #f4f4f5; font-family: system-ui, -apple-system, sans-serif; height: 100vh; width: 100vw; overflow: hidden; display: flex; flex-direction: row; }
    #nav-bar { width: 72px; height: 100%; background-color: #09090b; border-right: 1px solid #27272a; flex-shrink: 0; display: flex; flex-direction: column; align-items: center; padding-top: 24px; box-sizing: border-box; }
    #list-panel { width: 350px; height: 100%; background-color: #121214; border-right: 1px solid #27272a; flex-shrink: 0; display: flex; flex-direction: column; box-sizing: border-box; }
    #chat-panel { flex-grow: 1; height: 100%; display: flex; flex-direction: column; background-color: #09090b; min-w-0; box-sizing: border-box; overflow: hidden; }
    #info-panel { width: 300px; height: 100%; background-color: #121214; border-left: 1px solid #27272a; flex-shrink: 0; display: flex; flex-direction: column; padding: 20px; box-sizing: border-box; overflow-y: auto; }
    .chat-item { border-left: 4px solid transparent; transition: background 0.15s; padding: 16px; border-bottom: 1px solid #27272a; cursor: pointer; display: flex; justify-content: space-between; align-items: center; }
    .chat-item.active { background-color: #1c1c1f; border-left-color: #2563eb; }
    .msg-stream-area { flex-grow: 1; overflow-y: auto; padding: 24px; display: flex; flex-direction: column; gap: 16px; }
    .msg-wrap { display: flex; flex-direction: column; width: 100%; margin-bottom: 12px; }
    .msg-box { max-width: 75%; padding: 12px 16px; border-radius: 16px; font-size: 14px; line-height: 1.5; word-wrap: break-word; }
    .msg-in { background-color: #27272a; color: #f4f4f5; border-bottom-left-radius: 4px; align-self: flex-start; }
    .msg-out { background-color: #2563eb; color: white; border-bottom-right-radius: 4px; align-self: flex-end; }
    #replyForm { padding: 16px; background-color: #121214; border-top: 1px solid #27272a; display: flex; gap: 12px; flex-shrink: 0; }
    #replyInput { flex-grow: 1; border: 1px solid #27272a; background: #1c1c1f; border-radius: 12px; padding: 12px; font-size: 14px; color: white; outline: none; resize: none; }
    .send-btn { background-color: #2563eb; color: white; border: none; border-radius: 12px; padding: 0 24px; font-weight: 700; font-size: 14px; cursor: pointer; }
  </style>
</head>
<body>

  <aside id="nav-bar">
    <div style="width: 40px; height: 40px; background-color: #2563eb; border-radius: 12px; display: flex; align-items: center; justify-content: center; font-weight: 700; color: white;">SM</div>
  </aside>

  <aside id="list-panel">
    <div style="padding: 16px; border-bottom: 1px solid #27272a; flex-shrink: 0;">
      <h2 style="font-size: 20px; font-weight: 700; margin: 0 0 12px 0; tracking: -0.025em;">Inbox Live</h2>
      <input type="text" id="search" placeholder="Cerca cliente..." style="width: 100%; background: #1c1c1f; border: 1px solid #27272a; border-radius: 8px; padding: 8px 12px; font-size: 12px; color: white; outline: none;" oninput="renderList()">
    </div>
    <div id="chatListContainer" style="flex-grow: 1; overflow-y: auto;"></div>
  </aside>

  <main id="chat-panel">
    <div id="empty-state" style="flex-grow: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; color: #52525b;">
      <p style="font-size: 14px; font-weight: 500;">Seleziona una chat dalla lista per rispondere</p>
    </div>
    
    <div id="chat-active-core" style="display: none; flex-direction: column; height: 100%; overflow: hidden;">
      <header style="height: 70px; border-bottom: 1px solid #27272a; padding: 0 24px; display: flex; align-items: center; background-color: #121214; flex-shrink: 0;">
        <h3 id="activeHeaderName" style="font-weight: 700; font-size: 16px; margin: 0;"></h3>
      </header>
      <div id="msgStream" class="msg-stream-area"></div>
      <form id="replyForm">
        <textarea id="replyInput" rows="1" placeholder="Rispondi al cliente..."></textarea>
        <button type="submit" class="send-btn">Invia</button>
      </form>
    </div>
  </main>

  <aside id="info-panel">
    <h3 style="color: #a1a1aa; font-weight: 700; font-size: 12px; text-transform: uppercase; letter-spacing: 0.05em; margin: 0 0 16px 0; border-bottom: 1px solid #27272a; padding-bottom: 8px;">Scheda Lead CRM</h3>
    <div id="crm-placeholder" style="font-size: 12px; color: #52525b; font-style: italic;">Seleziona una chat attiva per visualizzare i metadati di contatto.</div>
    <div id="crm-content" style="display: none;">
      <div style="margin-bottom: 16px;"><label style="font-size: 10px; color: #52525b; font-weight: 600; text-transform: uppercase; display: block;">Nome Completo</label><p id="crmName" style="font-size: 14px; font-weight: 700; color: white; margin: 4px 0 0 0;">-</p></div>
      <div style="margin-bottom: 16px;"><label style="font-size: 10px; color: #52525b; font-weight: 600; text-transform: uppercase; display: block;">Email</label><p id="crmEmail" style="font-size: 14px; font-weight: 500; color: #3b82f6; margin: 4px 0 0 0; word-break: break-all;">-</p></div>
      <div style="margin-bottom: 16px;"><label style="font-size: 10px; color: #52525b; font-weight: 600; text-transform: uppercase; display: block;">Telefono / Cellulare</label><p id="crmPhone" style="font-size: 14px; font-weight: 500; color: white; margin: 4px 0 0 0;">-</p></div>
      <div style="margin-bottom: 16px;"><label style="font-size: 10px; color: #52525b; font-weight: 600; text-transform: uppercase; display: block;">Origine</label><p id="crmChannel" style="font-size: 14px; font-weight: 500; color: #cbd5e1; margin: 4px 0 0 0; text-transform: uppercase;">-</p></div>
      <div style="padding-top: 8px; border-top: 1px solid #27272a;"><label style="font-size: 10px; color: #52525b; font-weight: 600; text-transform: uppercase; display: block; margin-bottom: 4px;">Pagina Attiva</label><a id="crmPage" href="#" target="_blank" style="font-size: 12px; color: #3b82f6; text-decoration: none; display: block; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">-</a></div>
      <div id="crmOcrCard" style="display: none; padding-top: 12px; margin-top: 12px; border-top: 1px dashed #334155;">
         <label style="font-size: 10px; color: #f59e0b; font-weight: 600; text-transform: uppercase; display: block; margin-bottom: 4px;">Dati Caldaia Estratti (OCR)</label>
         <div id="crmOcrText" style="font-size: 12px; color: #e2e8f0; background: #09090b; padding: 10px; border-radius: 8px; border: 1px solid #27272a; white-space: pre-wrap;"></div>
      </div>
    </div>
  </aside>

<script>
var curr = null, chats = [], currentMsgCount = 0;

function escapeHTML(str) { return !str ? '' : str.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#039;"); }

async function synchronize() {
    try {
        var res = await fetch('/api/chats?v=' + Date.now());
        if (!res.ok) return;
        chats = await res.json();
        renderList();
        if (curr) {
            var activeChatExists = chats.find(function(x) { return x.phone === curr; });
            if (activeChatExists) fetchActiveChatStream(curr);
        }
    } catch(e) {}
}

function renderList() {
    var searchVal = document.getElementById('search').value.toLowerCase();
    var filtered = chats.filter(function(c) { return (c.name || '').toLowerCase().includes(searchVal) || (c.phone || '').includes(searchVal); });
    
    document.getElementById('chatListContainer').innerHTML = filtered.map(function(c) {
        var d = new Date(c.lastUpdate);
        var dateStr = d.toLocaleDateString('it-IT', { day: '2-digit', month: '2-digit', year: 'numeric' });
        var timeStr = d.toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' });
        var isUnread = c.msgCount > (localStorage.getItem('counter_' + c.phone) || 0);
        
        var styleStr = 'padding: 16px; border-bottom: 1px solid #27272a; cursor: pointer; display: flex; justify-content: space-between; align-items: center;';
        if (curr === c.phone) {
            styleStr += ' background-color: #1c1c1f; border-left: 4px solid #2563eb;';
        }
        
        var html = '<div onclick="selectChat(\'' + c.phone + '\')" style="' + styleStr + '">';
        html += '<div style="min-w-0; flex: 1; overflow: hidden; padding-right: 8px;">';
        html += '<div style="font-weight: 700; font-size: 14px; color: white; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">' + escapeHTML(c.name || c.phone) + '</div>';
        html += '<div style="font-size: 12px; color: #94a3b8; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; margin-top: 4px;">' + escapeHTML(c.lastMsgText || '') + '</div>';
        html += '</div>';
        html += '<div style="text-align: right; flex-shrink: 0; display: flex; flex-direction: column; align-items: flex-end; gap: 4px;">';
        html += '<div style="font-size: 10px; color: #64748b; font-weight: 500; line-height: 1.3;">' + dateStr + '<br>' + timeStr + '</div>';
        if (isUnread && curr !== c.phone) {
            html += '<span style="width: 10px; height: 10px; background-color: #3b82f6; border-radius: 50%; display: block;"></span>';
        }
        html += '</div>';
        html += '</div>';
        return html;
    }).join('');
}

function selectChat(p) {
    curr = p;
    var target = chats.find(function(x) { return x.phone === p; });
    if (target) localStorage.setItem('counter_' + p, target.msgCount);
    
    document.getElementById('empty-state').style.display = 'none';
    document.getElementById('chat-active-core').style.display = 'flex';
    document.getElementById('crm-placeholder').style.display = 'none';
    document.getElementById('crm-content').style.display = 'block';
    
    currentMsgCount = -1; 
    fetchActiveChatStream(p);
    renderList();
}

async function fetchActiveChatStream(p) {
    try {
        var res = await fetch('/api/chat_detail?phone=' + p + '&v=' + Date.now());
        if (!res.ok) return;
        var msgs = await res.json();
        var c = chats.find(function(x) { return x.phone === p; });
        var stream = document.getElementById('msgStream');
        
        if (c) {
            document.getElementById('activeHeaderName').innerText = c.name || c.phone;
            document.getElementById('crmName').innerText = c.name || c.phone;
            document.getElementById('crmEmail').innerText = c.email || "-";
            document.getElementById('crmPhone').innerText = c.cellulare || (c.channel === 'whatsapp' ? '+' + c.phone : "-");
            document.getElementById('crmChannel').innerText = c.channel === 'web' ? "Widget Web" : "WhatsApp Live";
            
            var pLink = document.getElementById('crmPage');
            if (c.activePage) { pLink.innerText = c.activePage; pLink.href = c.activePage; } else { pLink.innerText = "Nessuna traccia"; pLink.href = "#"; }
            
            if (c.ocrData) {
                document.getElementById('crmOcrCard').style.display = 'block';
                document.getElementById('crmOcrText').innerText = c.ocrData;
            } else { document.getElementById('crmOcrCard').style.display = 'none'; }
        }

        var isAnchored = (stream.scrollHeight - stream.scrollTop - stream.clientHeight) < 60;
        var previousScroll = stream.scrollTop;

        if (currentMsgCount !== msgs.length) {
            var lastBubbleDate = "";
            stream.innerHTML = msgs.map(function(m) {
                var mDate = new Date(m.timestamp || Date.now());
                var mDateStr = mDate.toLocaleDateString('it-IT', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
                var mTimeStr = mDate.toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' });
                var dateHeader = "";
                
                if (mDateStr !== lastBubbleDate) {
                    lastBubbleDate = mDateStr;
                    dateHeader = '<div style="display: flex; justify-content: center; margin: 16px 0;"><span style="background-color: #27272a; color: #a1a1aa; font-size: 11px; font-weight: 600; padding: 4px 12px; border-radius: 12px; text-transform: capitalize;">' + mDateStr + '</span></div>';
                }

                if (m.from === 'system') return dateHeader + '<div style="display: flex; justify-content: center; margin: 12px 0;"><span style="background-color: #27272a; color: #cbd5e1; border-radius: 12px; font-size: 12px; padding: 6px 12px; max-width: 90%; text-align: center; word-break: break-word;">' + escapeHTML(m.text) + '</span></div>';
                var isMe = m.from === 'admin';
                
                var bubbleStyle = isMe ? 'background-color: #2563eb; color: white; border-bottom-right-radius: 4px; align-self: flex-end;' : 'background-color: #27272a; color: #f4f4f5; border-bottom-left-radius: 4px; align-self: flex-start;';
                var wrapStyle = isMe ? 'align-items: flex-end;' : 'align-items: flex-start;';
                
                return dateHeader + '<div style="display: flex; flex-direction: column; width: 100%; margin-bottom: 12px; ' + wrapStyle + '">' +
                    '<div style="font-size: 10px; color: #52525b; margin-bottom: 4px; padding: 0 4px;">' + (isMe ? 'Tu' : (m.from === 'bot' ? 'IA SMR' : (c.name || 'Cliente'))) + ' · ' + mTimeStr + '</div>' +
                    '<div style="max-width: 75%; padding: 12px 16px; border-radius: 16px; font-size: 14px; line-height: 1.5; word-wrap: break-word; white-space: pre-wrap; ' + bubbleStyle + '">' + escapeHTML(m.text || '') + '</div>' +
                '</div>';
            }).join('');
            
            currentMsgCount = msgs.length;
            
            if (isAnchored || previousScroll === 0) {
                stream.scrollTop = stream.scrollHeight;
            } else {
                stream.scrollTop = previousScroll;
            }
        }
    } catch(e) {}
}

document.getElementById('replyForm').onsubmit = async function(e) {
    e.preventDefault();
    var inputEl = document.getElementById('replyInput');
    var val = inputEl.value.trim();
    if (!val || !curr) return;
    
    inputEl.value = '';
    await fetch('/api/reply', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone: curr, text: val })
    });
    synchronize();
};

document.getElementById('replyInput').addEventListener('keydown', function(e) {
    if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
        e.preventDefault();
        document.getElementById('replyForm').dispatchEvent(new Event('submit'));
    }
});

setInterval(synchronize, 2500);
synchronize();
</script>
</body>
</html>`;
  }
};
export { src_default as default };

#!/bin/bash
set -e

echo "=== Fase 1: Ricerca cartella attiva del progetto SMR OS ==="
TARGET_DIR=$(find ~ -name "wrangler.toml" -not -path "*/node_modules/*" -not -path "*/.*" 2>/dev/null | head -n 1 | xargs dirname)

if [ -z "$TARGET_DIR" ]; then
    echo "⚠️ wrangler.toml non trovato nelle sottocartelle utente. Uso cartella di default..."
    TARGET_DIR="$HOME/smricambi-bot"
fi

echo "-> Cartella di progetto individuata in: $TARGET_DIR"
cd "$TARGET_DIR"

echo "=== Fase 2: Identificazione file di Entrypoint ==="
ENTRYPOINT=$(grep "main =" wrangler.toml | head -n 1 | cut -d'"' -f2 | cut -d"'" -f2 || echo "")
if [ -z "$ENTRYPOINT" ]; then
    ENTRYPOINT="src/main.js"
fi
echo "-> File sorgente da aggiornare: $ENTRYPOINT"

mkdir -p $(dirname "$ENTRYPOINT")

cat << 'INNER_EOF' > "$ENTRYPOINT"
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
      const raw = await env2.SMR_DB.get(key);
      if (!raw || raw === "null") return defaultVal;
      return JSON.parse(raw);
    } catch (e) { return defaultVal; }
  },

  async saveLog(p, obj, env2, statusObj) {
    let chat = await this.getSafeJSON(env2, `chat_${p}`, []);
    if (!Array.isArray(chat)) chat = [];
    if (obj.text && obj.text.startsWith("data:image") && obj.text.length > 1000) {
      obj.text = "[Immagine Elaborata dall'OCR del Sistema]";
    }
    chat.push(obj);
    await env2.SMR_DB.put(`chat_${p}`, JSON.stringify(chat.slice(-150)));
    
    let snap = await this.getSafeJSON(env2, "crm_snapshot", {});
    if (!snap[p]) snap[p] = {};
    snap[p].status = statusObj || await this.getSafeJSON(env2, `status_${p}`, { name: "Cliente", channel: "web" });
    snap[p].lastMessage = obj;
    snap[p].lastUpdate = Date.now();
    await env2.SMR_DB.put("crm_snapshot", JSON.stringify(snap));
  },

  async processImageOCR(mediaId, mediaType, from, env2, st) {
    try {
      let base64Image = "";
      if (mediaType === "image") {
        if (mediaId.startsWith("r2_")) {
          let obj = await env2.SMR_BUCKET.get(mediaId.replace("r2_", ""));
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
        await env2.SMR_DB.put(`status_${from}`, JSON.stringify(st));
        await this.saveLog(from, { from: "system", text: `📝 DATI ESTRATTI DALLA TARGHETTA:\n${extractedContent}`, timestamp: Date.now() }, env2, st);
      }
    } catch (e) { console.error("OCR Failed", e); }
  },

  async fetch(request, env2, ctx) {
    const url = new URL(request.url);
    if (request.method === "OPTIONS") return new Response(null, { headers: CORS });

    try {
      if (url.pathname === "/admin") return new Response(this.getAdminHTML(), { headers: { "Content-Type": "text/html;charset=UTF-8" } });
      
      if (url.pathname === "/api/chats") {
        let list = await env2.SMR_DB.list({ prefix: "chat_" });
        let chats = [];
        for (const k of list.keys) {
          const phone = k.name.replace("chat_", "");
          const messages = await this.getSafeJSON(env2, k.name, []);
          const status = await this.getSafeJSON(env2, `status_${phone}`, { name: "Cliente Anonimo", channel: "web", email: "-", cellulare: "-" });
          if (messages.length > 0) {
            chats.push({
              phone,
              ...status,
              lastUpdate: messages[messages.length - 1].timestamp || Date.now(),
              msgCount: messages.length,
              lastMsgText: messages[messages.length - 1].text || "📎 Allegato Multimediale"
            });
          }
        }
        chats.sort((a, b) => b.lastUpdate - a.lastUpdate);
        return new Response(JSON.stringify(chats), { headers: CORS });
      }
      
      if (url.pathname === "/api/chat_detail") {
        const phone = url.searchParams.get("phone");
        const messages = await this.getSafeJSON(env2, `chat_${phone}`, []);
        return new Response(JSON.stringify(messages), { headers: CORS });
      }

      if (url.pathname === "/api/widget" && request.method === "POST") {
        const body = await request.json();
        const channelId = `web_${body.userId}`;
        let st = await this.getSafeJSON(env2, `status_${channelId}`, { manual: false, tag: "NEUTRO" });
        st.name = body.name || st.name || "Visitatore Web";
        st.email = body.email || st.email || "-";
        st.cellulare = body.cellulare || st.cellulare || "-";
        st.channel = "web";
        if (body.analytics?.url) st.activePage = body.analytics.url;

        await env2.SMR_DB.put(`status_${channelId}`, JSON.stringify(st));
        if (body.text) {
          await this.saveLog(channelId, { from: "user", text: body.text, timestamp: Date.now() }, env2, st);
        }
        return new Response(JSON.stringify({ reply: "OK" }), { headers: CORS });
      }

      if (url.pathname === "/api/reply" && request.method === "POST") {
        const { phone, text } = await request.json();
        let st = await this.getSafeJSON(env2, `status_${phone}`, { name: "Cliente", channel: "web" });
        await this.saveLog(phone, { from: "admin", text: text, timestamp: Date.now() }, env2, st);
        return new Response(JSON.stringify({ ok: true }), { headers: CORS });
      }

      if (url.pathname === "/api/toggle") {
        const { phone, manual } = await request.json();
        let st = await this.getSafeJSON(env2, `status_${phone}`, {});
        st.manual = manual; st.until = manual ? Date.now() + 864e5 * 2 : 0;
        await env2.SMR_DB.put(`status_${phone}`, JSON.stringify(st));
        await this.saveLog(phone, { from: "system", text: manual ? "L'operatore ha preso il controllo manuale della chat." : "Controllo ripassato all'Intelligenza Artificiale.", timestamp: Date.now() }, env2, st);
        return new Response(JSON.stringify({ ok: true }), { headers: CORS });
      }

      if (url.pathname === "/api/resolve") {
        const { phone } = await request.json();
        let st = await this.getSafeJSON(env2, `status_${phone}`, {});
        st.resolved = true; st.manual = false; st.until = 0;
        await env2.SMR_DB.put(`status_${phone}`, JSON.stringify(st));
        await this.saveLog(phone, { from: "system", text: "Conversazione archiviata con successo.", timestamp: Date.now() }, env2, st);
        return new Response(JSON.stringify({ ok: true }), { headers: CORS });
      }

      if (url.pathname === "/api/delete") {
        const { phone } = await request.json();
        await env2.SMR_DB.delete(`chat_${phone}`);
        await env2.SMR_DB.delete(`status_${phone}`);
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
  <title>SMR OS - Control Center v54</title>
  <script src="https://cdn.tailwindcss.com"><\/script>
</head>
<body style="margin: 0; padding: 0; background-color: #09090b; color: #f4f4f5; font-family: system-ui, -apple-system, sans-serif; height: 100vh; width: 100vw; overflow: hidden; display: flex; flex-direction: row;">

  <aside style="width: 72px; height: 100%; background-color: #09090b; border-right: 1px solid #27272a; flex-shrink: 0; display: flex; flex-direction: column; align-items: center; padding-top: 24px; box-sizing: border-box;">
    <div class="w-10 h-10 bg-blue-600 rounded-xl flex items-center justify-center text-white font-bold shadow-lg">SM</div>
  </aside>

  <aside style="width: 350px; height: 100%; background-color: #121214; border-right: 1px solid #27272a; flex-shrink: 0; display: flex; flex-direction: column; box-sizing: border-box;">
    <div class="p-4 border-b border-slate-800 shrink-0">
      <h2 class="text-xl font-bold text-white tracking-tight mb-3">Inbox Live</h2>
      <input type="text" id="search" placeholder="Cerca cliente..." class="w-full text-xs bg-[#1c1c1f] px-3 py-2 rounded-lg border border-slate-700 text-white outline-none focus:border-blue-500" oninput="renderList()">
    </div>
    <div id="chatListContainer" style="flex-1; overflow-y: auto;"></div>
  </aside>

  <main style="flex-grow: 1; height: 100%; display: flex; flex-direction: column; background-color: #09090b; min-w-0; box-sizing: border-box; overflow: hidden;">
    <div id="empty-state" style="flex: 1; display: flex; flex-direction: column; items-center: center; justify-content: center; align-items: center; color: #52525b;">
      <p class="text-sm font-medium">Seleziona una chat dalla lista per rispondere</p>
    </div>
    
    <div id="chat-active-core" style="display: none; flex-direction: column; height: 100%; overflow: hidden;">
      <header class="h-[70px] border-b border-slate-800 px-6 flex items-center justify-between bg-[#121214] shrink-0">
        <h3 id="activeHeaderName" class="font-bold text-white text-base"></h3>
        <div class="flex gap-2">
            <button id="resolveBtn" onclick="resolveChat()" class="px-3 py-1.5 rounded-lg text-xs font-bold text-emerald-400 bg-emerald-500/10 border border-emerald-500/20">Risolvi</button>
            <button id="toggleBtn" onclick="toggleM()" class="px-3 py-1.5 rounded-lg text-xs font-bold text-white bg-blue-600">Prendi Controllo</button>
        </div>
      </header>
      <div id="msgStream" style="flex-grow: 1; overflow-y: auto; padding: 24px; display: flex; flex-direction: column; gap: 16px;"></div>
      <form id="replyForm" class="p-4 bg-[#121214] border-t border-slate-800 flex gap-3 shrink-0">
        <textarea id="replyInput" class="flex-1 bg-[#1c1c1f] border border-slate-700 rounded-xl px-4 py-3 text-sm text-white outline-none resize-none" rows="1" placeholder="Rispondi al cliente..."></textarea>
        <button type="submit" class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-xl font-bold text-sm">Invia</button>
      </form>
    </div>
  </main>

  <aside style="width: 300px; height: 100%; background-color: #121214; border-left: 1px solid #27272a; flex-shrink: 0; display: flex; flex-direction: column; padding: 20px; box-sizing: border-box; overflow-y: auto;">
    <h3 class="text-slate-400 font-bold text-xs uppercase tracking-wider mb-4 border-b border-slate-800 pb-2">Scheda Lead CRM</h3>
    <div id="crm-placeholder" class="text-xs text-slate-500 italic">Seleziona una chat attiva per visualizzare i metadati di contatto.</div>
    <div id="crm-content" class="space-y-4" style="display: none;">
      <div><label class="text-[10px] text-slate-500 font-semibold block uppercase tracking-wider">Nome Completo</label><p id="crmName" class="text-sm font-bold text-white mt-0.5">-</p></div>
      <div><label class="text-[10px] text-slate-500 font-semibold block uppercase tracking-wider">Email</label><p id="crmEmail" class="text-sm font-medium text-blue-400 break-all mt-0.5">-</p></div>
      <div><label class="text-[10px] text-slate-500 font-semibold block uppercase tracking-wider">Telefono / Cellulare</label><p id="crmPhone" class="text-sm font-medium text-white mt-0.5">-</p></div>
      <div><label class="text-[10px] text-slate-500 font-semibold block uppercase tracking-wider">Origine</label><p id="crmChannel" class="text-sm font-medium text-slate-300 mt-0.5 uppercase">-</p></div>
      <div class="pt-2 border-t border-slate-800"><label class="text-[10px] text-slate-500 font-semibold block uppercase tracking-wider mb-1">Pagina Attiva</label><a id="crmPage" href="#" target="_blank" class="text-xs text-blue-400 hover:underline block truncate">-</a></div>
      <div id="crmOcrCard" class="pt-3 mt-2 border-t border-dashed border-slate-700" style="display: none;">
         <label class="text-[10px] text-amber-400 font-semibold block uppercase tracking-wider mb-1">Dati Caldaia Estratti (OCR)</label>
         <div id="crmOcrText" class="text-xs text-slate-300 bg-slate-900 p-2.5 rounded-lg border border-slate-800 whitespace-pre-wrap"></div>
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
        if (curr) fetchActiveChatStream(curr);
    } catch(e) {}
}

function renderList() {
    var searchVal = document.getElementById('search').value.toLowerCase();
    var filtered = chats.filter(c => (c.name || '').toLowerCase().includes(searchVal) || (c.phone || '').includes(searchVal));
    
    document.getElementById('chatListContainer').innerHTML = filtered.map(c => {
        var d = new Date(c.lastUpdate);
        var dateStr = d.toLocaleDateString('it-IT', { day: '2-digit', month: '2-digit', year: 'numeric' });
        var timeStr = d.toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' });
        var isUnread = c.msgCount > (localStorage.getItem('counter_' + c.phone) || 0);
        
        return \`<div onclick="selectChat('\${c.phone}')" class="chat-item p-4 border-b border-slate-800 cursor-pointer \${curr === c.phone ? 'active' : ''}">
            <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 4px;">
                <div style="font-weight: 700; font-size: 14px; color: white; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; flex: 1;">\${c.name || c.phone}</div>
                <div style="font-size: 10px; color: #64748b; text-align: right; margin-left: 8px; font-weight: 500; line-height: 1.3;">\${dateStr}<br>\${timeStr}</div>
            </div>
            <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 4px;">
                <div style="font-size: 12px; color: #94a3b8; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; flex: 1; padding-right: 8px;">\${c.lastMsgText || ''}</div>
                \${isUnread && curr !== c.phone ? '<span style="width: 10px; height: 10px; background-color: #3b82f6; border-radius: 50%; display: block; flex-shrink: 0;"></span>' : ''}
            </div>
        </div>\`;
    }).join('');
}

function selectChat(p) {
    curr = p;
    var target = chats.find(x => x.phone === p);
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
        var c = chats.find(x => x.phone === p);
        var stream = document.getElementById('msgStream');
        
        if (c) {
            document.getElementById('crmName').innerText = c.name || c.phone;
            document.getElementById('crmEmail').innerText = c.email || "-";
            document.getElementById('crmPhone').innerText = c.cellulare || (c.channel === 'whatsapp' ? '+' + c.phone : "-");
            document.getElementById('crmChannel').innerText = c.channel === 'web' ? "Widget Web" : "WhatsApp Live";
            
            var pLink = document.getElementById('crmPage');
            if (c.activePage) { pLink.innerText = c.activePage; pLink.href = c.activePage; } else { pLink.innerText = "Nessuna traccia"; pLink.href = "#"; }
            
            var tb = document.getElementById('toggleBtn');
            if (c.manual) { tb.innerText = "Riattiva Bot"; tb.className = "px-3 py-1.5 rounded-lg text-xs font-bold text-slate-300 bg-slate-800 border border-slate-700"; }
            else { tb.innerText = "Prendi Controllo"; tb.className = "px-3 py-1.5 rounded-lg text-xs font-bold text-white bg-blue-600"; }
            
            if (c.ocrData) {
                document.getElementById('crmOcrCard').style.display = 'block';
                document.getElementById('crmOcrText').innerText = c.ocrData;
            } else { document.getElementById('crmOcrCard').style.display = 'none'; }
        }

        // VERIFICA DELLO SCROLL LOCK: Se l'operatore ha letto in alto (> 60px dal fondo), blocca il repaint automatico
        var isAnchored = (stream.scrollHeight - stream.scrollTop - stream.clientHeight) < 60;
        var previousScroll = stream.scrollTop;

        if (currentMsgCount !== msgs.length) {
            var lastBubbleDate = "";
            stream.innerHTML = msgs.map(m => {
                var mDate = new Date(m.timestamp || Date.now());
                var mDateStr = mDate.toLocaleDateString('it-IT', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
                var mTimeStr = mDate.toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' });
                var dateHeader = "";
                
                if (mDateStr !== lastBubbleDate) {
                    lastBubbleDate = mDateStr;
                    dateHeader = \`<div style="display: flex; justify-content: center; margin: 16px 0;"><span style="background-color: #27272a; color: #a1a1aa; font-size: 11px; font-weight: 600; padding: 4px 12px; border-radius: 12px; text-transform: capitalize;">\${mDateStr}</span></div>\`;
                }

                if (m.from === 'system') return dateHeader + \`<div class="msg-system" style="background-color: #27272a; color: #cbd5e1; border-radius: 12px; font-size: 12px; padding: 8px 12px; text-align: center; width: 100%; box-sizing: border-box;">\${escapeHTML(m.text)}</div>\`;
                var isMe = m.from === 'admin';
                
                return dateHeader + \`<div class="msg-wrap" style="display: flex; flex-direction: column; width: 100%; \${isMe ? 'align-items: flex-end;' : 'align-items: flex-start;'}">
                    <div style="font-size: 10px; color: #52525b; margin-bottom: 4px; padding: 0 4px;">\${isMe ? 'Tu' : (m.from === 'bot' ? 'IA SMR' : (c.name || 'Cliente'))} · \${mTimeStr}</div>
                    <div class="msg-box \${isMe ? 'msg-out' : 'msg-in'} whitespace-pre-wrap">\${escapeHTML(m.text)}</div>
                </div>\`;
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

document.getElementById('replyForm').onsubmit = async (e) => {
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

async function toggleM() {
    var target = chats.find(x => x.phone === curr);
    if (!target) return;
    await fetch('/api/toggle', { method: 'POST', body: JSON.stringify({ phone: curr, manual: !target.manual }) });
    synchronize();
}

async function resolveChat() {
    if (!confirm("Archiviare la conversazione attuale?")) return;
    await fetch('/api/resolve', { method: 'POST', body: JSON.stringify({ phone: curr }) });
    curr = null;
    location.reload();
}

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
INNER_EOF

echo "=== Fase 3: Esecuzione del deploy definitivo tramite Wrangler ==="
npx wrangler deploy

echo "=== SMR OS V54 ONLINE ==="

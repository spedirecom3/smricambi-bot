#!/bin/bash
set -e

echo "=== Compilazione SMR OS V53 - Enterprise Final Fix ==="

cd ~/smricambi-bot

cat << 'INNER_EOF' > src/main.js
import { Buffer as Buffer2 } from "node:buffer";

var CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type"
};

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
    chat.push(obj);
    await env2.SMR_DB.put(`chat_${p}`, JSON.stringify(chat.slice(-150)));
    
    let snap = await this.getSafeJSON(env2, "crm_snapshot", {});
    if (!snap[p]) snap[p] = {};
    snap[p].status = statusObj || await this.getSafeJSON(env2, `status_${p}`, { name: "Cliente", channel: "whatsapp" });
    snap[p].lastMessage = obj;
    snap[p].lastUpdate = Date.now();
    await env2.SMR_DB.put("crm_snapshot", JSON.stringify(snap));
  },

  async fetch(request, env2, ctx) {
    const url = new URL(request.url);
    if (request.method === "OPTIONS") return new Response(null, { headers: CORS });

    try {
      if (url.pathname === "/admin") return new Response(this.getAdminHTML(), { headers: { "Content-Type": "text/html;charset=UTF-8" } });
      
      if (url.pathname === "/api/chats") {
        let list = await env2.SMR_DB.list({ prefix: "chat_" });
        let snapshotData = [];
        for (const k of list.keys) {
          const phone = k.name.replace("chat_", "");
          const messages = await this.getSafeJSON(env2, k.name, []);
          const status = await this.getSafeJSON(env2, `status_${phone}`, { name: "Cliente Sconosciuto", channel: "web", email: "-", cellulare: "-" });
          if (messages.length > 0) {
            snapshotData.push({
              phone,
              ...status,
              lastUpdate: messages[messages.length - 1].timestamp || Date.now(),
              msgCount: messages.length,
              lastMsgText: messages[messages.length - 1].text || "📎 Allegato"
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
  <title>SMR OS - Control Center</title>
  <script src="https://cdn.tailwindcss.com"><\/script>
  <style>
    body { margin: 0; padding: 0; background-color: #09090b; color: #f4f4f5; font-family: system-ui, sans-serif; height: 100vh; width: 100vw; overflow: hidden; display: flex; flex-direction: row; }
    #nav-bar { width: 72px; height: 100%; background-color: #09090b; border-right: 1px solid #27272a; flex-shrink: 0; display: flex; flex-direction: column; align-items: center; padding-top: 24px; }
    #list-panel { width: 350px; height: 100%; background-color: #121214; border-right: 1px solid #27272a; flex-shrink: 0; display: flex; flex-direction: column; }
    #chat-panel { flex-grow: 1; height: 100%; display: flex; flex-direction: column; background-color: #09090b; min-w-0; }
    #info-panel { width: 320px; height: 100%; background-color: #121214; border-left: 1px solid #27272a; flex-shrink: 0; display: flex; flex-direction: column; padding: 20px; box-sizing: border-box; }
    .chat-item { border-left: 4px solid transparent; transition: background 0.15s; }
    .chat-item.active { background-color: #1c1c1f; border-left-color: #2563eb; }
    .msg-stream-area { flex-grow: 1; overflow-y: auto; padding: 24px; display: flex; flex-direction: column; gap: 16px; }
    .msg-wrap { display: flex; flex-direction: column; width: 100%; }
    .msg-box { max-width: 80%; padding: 12px 16px; border-radius: 16px; font-size: 14px; line-height: 1.5; word-wrap: break-word; }
    .msg-in { background-color: #27272a; color: #f4f4f5; border-bottom-left-radius: 4px; align-self: flex-start; }
    .msg-out { background-color: #2563eb; color: white; border-bottom-right-radius: 4px; align-self: flex-end; }
  </style>
</head>
<body>

  <aside id="nav-bar">
    <div class="w-10 h-10 bg-blue-600 rounded-xl flex items-center justify-center text-white font-bold shadow-lg">SM</div>
  </aside>

  <aside id="list-panel">
    <div class="p-4 border-b border-slate-800">
      <h2 class="text-xl font-bold text-white tracking-tight mb-3">Conversazioni</h2>
      <input type="text" id="search" placeholder="Cerca cliente..." class="w-full text-xs bg-[#1c1c1f] px-3 py-2 rounded-lg border border-slate-700 text-white outline-none focus:border-blue-500" oninput="renderList()">
    </div>
    <div id="chatListContainer" class="flex-1 overflow-y-auto"></div>
  </aside>

  <main id="chat-panel">
    <div id="empty-state" class="flex-1 flex flex-col items-center justify-center text-slate-500">
      <p class="text-sm font-medium">Seleziona una sessione per rispondere</p>
    </div>
    
    <div id="chat-active-core" style="display: none; flex-direction: column; height: 100%; overflow: hidden;">
      <header class="h-[70px] border-b border-slate-800 px-6 flex items-center bg-[#121214] shrink-0">
        <h3 id="activeHeaderName" class="font-bold text-white text-base"></h3>
      </header>
      <div id="msgStream" class="msg-stream-area" data-msg-count="0"></div>
      <form id="replyForm" class="p-4 bg-[#121214] border-t border-slate-800 flex gap-3 shrink-0">
        <textarea id="replyInput" class="flex-1 bg-[#1c1c1f] border border-slate-700 rounded-xl px-4 py-3 text-sm text-white outline-none resize-none" rows="1" placeholder="Scrivi una risposta..."></textarea>
        <button type="submit" class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-xl font-bold text-sm">Invia</button>
      </form>
    </div>
  </main>

  <aside id="info-panel">
    <h3 class="text-slate-400 font-bold text-xs uppercase tracking-wider mb-4 border-b border-slate-800 pb-2">Scheda Lead CRM</h3>
    <div id="crm-content" class="space-y-4" style="display: none;">
      <div><label class="text-[10px] text-slate-500 font-semibold block uppercase tracking-wider">Nome Completo</label><p id="crmName" class="text-sm font-bold text-white mt-0.5">-</p></div>
      <div><label class="text-[10px] text-slate-500 font-semibold block uppercase tracking-wider">Email</label><p id="crmEmail" class="text-sm font-medium text-blue-400 break-all mt-0.5">-</p></div>
      <div><label class="text-[10px] text-slate-500 font-semibold block uppercase tracking-wider">Telefono</label><p id="crmPhone" class="text-sm font-medium text-white mt-0.5">-</p></div>
      <div><label class="text-[10px] text-slate-500 font-semibold block uppercase tracking-wider">Origine</label><p id="crmChannel" class="text-sm font-medium text-slate-300 mt-0.5 uppercase">-</p></div>
      <div class="pt-2 border-t border-slate-800"><label class="text-[10px] text-slate-500 font-semibold block uppercase tracking-wider mb-1">Pagina Attiva</label><a id="crmPage" href="#" target="_blank" class="text-xs text-blue-400 hover:underline block truncate">-</a></div>
    </div>
  </aside>

<script>
var curr = null, chats = [], currentMsgCount = 0;

async function synchronize() {
    try {
        var res = await fetch('/api/chats?v=' + Date.now());
        if (!res.ok) return;
        chats = await res.json(); // FIX: Rimosso 'var' per mappare la variabile globale
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
            <div class="flex justify-between items-start mb-1">
                <div class="font-bold text-sm text-white truncate flex-1">\${c.name || c.phone}</div>
                <div class="text-[10px] text-slate-500 shrink-0 ml-2 text-right">\${dateStr}<br>\${timeStr}</div>
            </div>
            <div class="flex justify-between items-center mt-1">
                <div class="text-xs text-slate-400 truncate flex-1 pr-2">\${c.lastMsgText || ''}</div>
                \place_holder_unread\${isUnread && curr !== c.phone ? '<span class="w-2.5 h-2.5 bg-blue-500 rounded-full shrink-0 shadow-lg shadow-blue-500/50"></span>' : ''}
            </div>
        </div>\`;
    }).join('').replace('place_holder_unread', '');
}

function selectChat(p) {
    curr = p;
    var target = chats.find(x => x.phone === p);
    if (target) localStorage.setItem('counter_' + p, target.msgCount);
    
    document.getElementById('empty-state').style.display = 'none';
    document.getElementById('chat-active-core').style.display = 'flex';
    document.getElementById('crm-content').style.display = 'block';
    
    currentMsgCount = 0; 
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
            document.getElementById('activeHeaderName').innerText = c.name || c.phone;
            document.getElementById('crmName').innerText = c.name || "Visitatore";
            document.getElementById('crmEmail').innerText = c.email || "-";
            document.getElementById('crmPhone').innerText = c.cellulare || (c.channel === 'whatsapp' ? '+' + c.phone : "-");
            document.getElementById('crmChannel').innerText = c.channel === 'web' ? "Widget Web" : "WhatsApp";
            
            var pLink = document.getElementById('crmPage');
            if (c.activePage) { pLink.innerText = c.activePage; pLink.href = c.activePage; } else { pLink.innerText = "Nessuna traccia"; pLink.href = "#"; }
        }

        // SCROLL LOCK PROTOCOL: Se la distanza dal fondo supera i 45px, l'utente sta consultando lo storico
        var isAnchored = (stream.scrollHeight - stream.scrollTop - stream.clientHeight) < 45;

        if (currentMsgCount !== msgs.length) {
            stream.innerHTML = msgs.map(m => {
                if (m.from === 'system') return \`<div class="msg-system break-words">\${escapeHTML(m.text)}</div>\`;
                var isMe = m.from === 'admin';
                return \`<div class="msg-wrap \${isMe ? 'items-end' : 'items-start'}">
                    <div class="msg-box \${isMe ? 'msg-out' : 'msg-in'} whitespace-pre-wrap">\${escapeHTML(m.text)}</div>
                </div>\`;
            }).join('');
            
            currentMsgCount = msgs.length;
            
            // Forza lo scroll lock solo se ancorato al fondo o alla prima apertura
            if (isAnchored || stream.scrollTop === 0) {
                stream.scrollTop = stream.scrollHeight;
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

setInterval(synchronize, 2500);
synchronize();
</script>
</body>
</html>`;
  }
};
export { src_default as default };
INNER_EOF

npx wrangler deploy
echo "=== Aggiornamento Completato. Esegui Hard Refresh ==="

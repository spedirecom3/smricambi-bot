#!/bin/bash
set -e

echo "=== Applicazione Patch Layout e Scroll Lock Dinamico ==="

cd ~/smricambi-bot

# Sostituzione integrale del file sorgente
cat << 'INNER_EOF' > src/main.js
import { Buffer as Buffer2 } from "node:buffer";
var CORS = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Methods": "GET, POST, OPTIONS", "Access-Control-Allow-Headers": "Content-Type" };
var WA_API = "https://graph.facebook.com/v20.0";
var WA_PHONE_ID = "1138721115984287";

function formatWhatsAppText(text) { return !text ? "" : text.replace(/\*\*(.*?)\*\*/g, "*$1*"); }
function escapeHTML(str) { return !str ? '' : str.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#039;"); }

var src_default = {
  async getSafeJSON(env2, key, defaultVal) {
    try { if (!env2.SMR_DB) return defaultVal; const raw = await env2.SMR_DB.get(key); return (raw && raw !== "null") ? JSON.parse(raw) : defaultVal; } catch (e) { return defaultVal; }
  },
  async fetch(request, env2, ctx) {
    const url = new URL(request.url);
    if (request.method === "OPTIONS") return new Response(null, { headers: CORS });
    try {
      if (url.pathname === "/admin") return new Response(this.getAdminHTML(), { headers: { "Content-Type": "text/html;charset=UTF-8" } });
      if (url.pathname === "/api/chats") return this.handleChatSnapshot(request, env2);
      if (url.pathname === "/api/chat_detail") return this.handleSingleChat(request, env2);
      if (url.pathname === "/api/widget") return this.handleWidget(request, env2, ctx);
      if (url.pathname === "/api/reply") return this.handleReply(request, env2);
      if (url.pathname === "/api/upload" && request.method === "POST") return this.handleUpload(request, env2);
      if (url.pathname.startsWith("/api/media/")) return this.handleMedia(url, env2);
      if (request.method === "POST") {
        const body = await request.json();
        const msg = body?.entry?.[0]?.changes?.[0]?.value?.messages?.[0];
        if (msg) ctx.waitUntil(this.handleWhatsApp(msg, env2, ctx));
        return new Response("OK");
      }
      return new Response("SMR OS v48 ACTIVE");
    } catch (err) { return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: CORS }); }
  },
  
  async handleChatSnapshot(request, env2) {
    let list = await env2.SMR_DB.list({ prefix: "chat_" });
    let chats = [];
    for (const k of list.keys) {
      let phone = k.name.replace("chat_", "");
      let msgs = await this.getSafeJSON(env2, k.name, []);
      let st = await this.getSafeJSON(env2, `status_${phone}`, { name: "Cliente", channel: "web" });
      chats.push({ phone, ...st, lastUpdate: msgs.length ? msgs[msgs.length-1].timestamp : 0 });
    }
    return new Response(JSON.stringify(chats.sort((a,b) => b.lastUpdate - a.lastUpdate)), { headers: CORS });
  },

  async handleSingleChat(request, env2) {
    const phone = new URL(request.url).searchParams.get("phone");
    return new Response(JSON.stringify(await this.getSafeJSON(env2, `chat_${phone}`, [])), { headers: CORS });
  },

  async saveLog(p, obj, env2, statusObj) {
    let chat = await this.getSafeJSON(env2, `chat_${p}`, []);
    chat.push(obj);
    await env2.SMR_DB.put(`chat_${p}`, JSON.stringify(chat.slice(-150)));
  },

  async handleWidget(request, env2, ctx) {
    const body = await request.json();
    const phone = 'web_' + body.userId;
    let st = await this.getSafeJSON(env2, `status_${phone}`, { name: body.name, email: body.email, cellulare: body.cellulare, channel: 'web' });
    st.activePage = body.analytics?.url;
    await env2.SMR_DB.put(`status_${phone}`, JSON.stringify(st));
    if (body.text) await this.saveLog(phone, { from: "user", text: body.text, timestamp: Date.now() }, env2, st);
    return new Response(JSON.stringify({ reply: "Ricevuto." }), { headers: CORS });
  },

  async handleReply(request, env2) {
    const { phone, text, isNote } = await request.json();
    await this.saveLog(phone, { from: isNote ? "system" : "admin", text: text, timestamp: Date.now() }, env2);
    return new Response(JSON.stringify({ ok: true }), { headers: CORS });
  },

  getAdminHTML() {
    return `<!DOCTYPE html>
<html>
<head>
  <script src="https://cdn.tailwindcss.com"></script>
  <style>
    body { background: #0f172a; color: white; font-family: sans-serif; }
    .col-layout { display: grid; grid-template-columns: 72px 350px 1fr 300px; height: 100vh; }
  </style>
</head>
<body class="col-layout">
  <aside class="bg-[#0b1120] flex flex-col items-center py-6 gap-6 border-r border-slate-800">
    <div class="w-10 h-10 bg-blue-600 rounded-xl flex items-center justify-center font-bold">SM</div>
  </aside>
  <aside class="bg-[#121214] border-r border-slate-800 overflow-y-auto" id="chatList"></aside>
  <main class="flex flex-col bg-[#0f172a] overflow-hidden">
    <header id="chatH" class="hidden h-[70px] border-b border-slate-800 p-4 flex items-center justify-between">
      <div id="hName" class="font-bold"></div>
    </header>
    <div id="msgA" class="flex-1 overflow-y-auto p-4 space-y-4"></div>
    <form id="comp" class="p-3 bg-[#121214] border-t border-slate-800 flex gap-2">
      <textarea id="msgI" class="flex-1 bg-[#1e293b] p-2 rounded text-sm text-white" placeholder="Rispondi..."></textarea>
      <button class="bg-blue-600 px-4 py-2 rounded">Invia</button>
    </form>
  </main>
  <aside id="profileCard" class="bg-[#121214] border-l border-slate-800 p-5 flex flex-col gap-4">
    <h3 class="text-xs text-slate-500 uppercase font-bold">Anagrafica</h3>
    <div><div class="text-[10px] text-slate-500">NOME</div><div id="pCardName" class="text-sm">-</div></div>
    <div><div class="text-[10px] text-slate-500">EMAIL</div><div id="pCardEmail" class="text-sm text-blue-400">-</div></div>
  </aside>

<script>
var curr=null, chats=[];
window.userScrollingUp = false;

// Gestione Scroll Intelligente
const msgA = document.getElementById('msgA');
msgA.onscroll = () => {
    // Se l'utente è a più di 100px dal fondo, smette di scrollare automaticamente
    window.userScrollingUp = (msgA.scrollHeight - msgA.scrollTop - msgA.clientHeight) > 100;
};

async function load() {
    var res = await fetch('/api/chats');
    chats = await res.json();
    renderL();
    if(curr) fetchChatDetailAndRender(curr);
}

function renderL() {
    var html = chats.map(c => \`<div onclick="openChat('\${c.phone}')" class="p-4 border-b border-slate-800 cursor-pointer \${curr===c.phone?'bg-[#1e293b]':''}">\${c.name}</div>\`).join('');
    document.getElementById('chatList').innerHTML = html;
}

function openChat(p) { curr = p; fetchChatDetailAndRender(p); }

async function fetchChatDetailAndRender(p) {
    var res = await fetch('/api/chat_detail?phone=' + p);
    var msgs = await res.json();
    var c = chats.find(x => x.phone === p);
    
    // Aggiornamento DOM
    document.getElementById('chatH').classList.remove('hidden');
    document.getElementById('msgA').classList.remove('hidden');
    document.getElementById('compWrapper').classList.remove('hidden');
    
    document.getElementById('hName').innerText = c.name;
    document.getElementById('pCardName').innerText = c.name;
    document.getElementById('pCardEmail').innerText = c.email || "-";
    
    var html = msgs.map(m => \`<div class="\${m.from==='admin'?'text-right':'text-left'} p-2"><div class="inline-block p-2 rounded \${m.from==='admin'?'bg-blue-600':'bg-slate-700'}">\${escapeHTML(m.text)}</div></div>\`).join('');
    msgA.innerHTML = html;

    // SCROLL LOCK LOGIC: scrolla solo se l'utente NON stava leggendo sopra
    if (!window.userScrollingUp) {
        msgA.scrollTop = msgA.scrollHeight;
    }
}

document.getElementById('comp').onsubmit = async(e) => {
    e.preventDefault();
    await fetch('/api/reply', { method:'POST', body: JSON.stringify({phone: curr, text: document.getElementById('msgI').value}) });
    document.getElementById('msgI').value = '';
    load();
};

setInterval(load, 3000);
load();
</script>
</body>
</html>
`;
  }
};
export { src_default as default };
INNER_EOF

npx wrangler deploy
echo "=== Deploy Completato. Esegui Hard Refresh (Cmd+Shift+R) ==="

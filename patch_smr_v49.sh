#!/bin/bash
set -e

echo "=== Iniezione SMR OS V49 - Stabilizzazione Layout e MarkAsRead ==="

cd ~/smricambi-bot

# Sostituzione con una versione che ignora la cache CSS e forza il rendering JS
cat << 'INNER_EOF' > src/main.js
import { Buffer as Buffer2 } from "node:buffer";
var CORS = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Methods": "GET, POST, OPTIONS", "Access-Control-Allow-Headers": "Content-Type" };

function formatWhatsAppText(text) { return !text ? "" : text.replace(/\*\*(.*?)\*\*/g, "*$1*"); }
function escapeHTML(str) { return !str ? '' : str.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#039;"); }

var src_default = {
  async getSafeJSON(env2, key, defaultVal) {
    try { const raw = await env2.SMR_DB.get(key); return (raw && raw !== "null") ? JSON.parse(raw) : defaultVal; } catch (e) { return defaultVal; }
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
      return new Response("OK");
    } catch (err) { return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: CORS }); }
  },
  
  async handleChatSnapshot(request, env2) {
    let list = await env2.SMR_DB.list({ prefix: "chat_" });
    let chats = [];
    for (const k of list.keys) {
      let phone = k.name.replace("chat_", "");
      let msgs = await this.getSafeJSON(env2, k.name, []);
      let st = await this.getSafeJSON(env2, `status_${phone}`, { name: "Cliente", channel: "web" });
      chats.push({ phone, ...st, lastUpdate: msgs.length ? msgs[msgs.length-1].timestamp : 0, lastMsg: msgs.length ? msgs[msgs.length-1] : null });
    }
    return new Response(JSON.stringify(chats.sort((a,b) => b.lastUpdate - a.lastUpdate)), { headers: CORS });
  },

  async handleSingleChat(request, env2) {
    const phone = new URL(request.url).searchParams.get("phone");
    return new Response(JSON.stringify(await this.getSafeJSON(env2, `chat_${phone}`, [])), { headers: CORS });
  },

  async saveLog(p, obj, env2) {
    let chat = await this.getSafeJSON(env2, `chat_${p}`, []);
    chat.push(obj);
    await env2.SMR_DB.put(`chat_${p}`, JSON.stringify(chat.slice(-150)));
  },

  getAdminHTML() {
    return `<!DOCTYPE html>
<html>
<head>
  <script src="https://cdn.tailwindcss.com"></script>
  <style>
    body { background: #0f172a; color: white; font-family: sans-serif; overflow: hidden; }
    .app-grid { display: grid; grid-template-columns: 72px 350px 1fr 300px; height: 100vh; }
  </style>
</head>
<body class="app-grid">
  <aside class="bg-[#0b1120] border-r border-slate-800 flex flex-col items-center py-6 gap-6">
    <div class="w-10 h-10 bg-blue-600 rounded-xl flex items-center justify-center font-bold">SM</div>
  </aside>
  <aside id="chatList" class="bg-[#121214] border-r border-slate-800 overflow-y-auto"></aside>
  <main class="flex flex-col bg-[#0f172a] overflow-hidden">
    <header id="chatH" class="hidden h-[70px] border-b border-slate-800 p-4 flex items-center justify-between">
      <div id="hName" class="font-bold"></div>
    </header>
    <div id="msgA" class="flex-1 overflow-y-auto p-4 space-y-4"></div>
    <form id="comp" class="hidden p-3 bg-[#121214] border-t border-slate-800 flex gap-2">
      <textarea id="msgI" class="flex-1 bg-[#1e293b] p-2 rounded text-sm text-white" placeholder="Rispondi..."></textarea>
      <button class="bg-blue-600 px-4 py-2 rounded font-bold">Invia</button>
    </form>
  </main>
  <aside id="profileCard" class="bg-[#121214] border-l border-slate-800 p-5 flex flex-col gap-4">
    <h3 class="text-xs text-slate-500 uppercase font-bold">Anagrafica Lead</h3>
    <div id="pData" class="space-y-3">
        <div><div class="text-[10px] text-slate-500">NOME</div><div id="pCardName">-</div></div>
        <div><div class="text-[10px] text-slate-500">EMAIL</div><div id="pCardEmail" class="text-blue-400">-</div></div>
    </div>
  </aside>

<script>
var curr=null, chats=[];
async function load() {
    var res = await fetch('/api/chats'); chats = await res.json();
    renderL(); if(curr) renderM(curr);
}

function renderL() {
    document.getElementById('chatList').innerHTML = chats.map(c => {
        var last = c.lastMsg || {};
        var isUnread = last.from === 'user' && last.timestamp > (localStorage.getItem('read_'+c.phone)||0);
        return \`<div onclick="openChat('\${c.phone}')" class="p-4 border-b border-slate-800 cursor-pointer \${curr===c.phone?'bg-[#1e293b]':''}">
            <div class="flex justify-between">
                <span class="font-bold">\${c.name}</span>
                \${isUnread ? '<div class="w-2 h-2 bg-blue-500 rounded-full"></div>' : ''}
            </div>
        </div>\`;
    }).join('');
}

function openChat(p) { 
    curr = p; 
    // Mark as read IMMEDIATAMENTE
    var c = chats.find(x => x.phone === p);
    if(c && c.lastMsg) localStorage.setItem('read_'+p, c.lastMsg.timestamp);
    renderL();
    renderM(p); 
}

async function renderM(p) {
    var res = await fetch('/api/chat_detail?phone='+p);
    var msgs = await res.json();
    var c = chats.find(x => x.phone === p);
    
    document.getElementById('chatH').classList.remove('hidden');
    document.getElementById('msgA').classList.remove('hidden');
    document.getElementById('comp').classList.remove('hidden');
    document.getElementById('profileCard').style.display = 'flex';
    
    document.getElementById('hName').innerText = c.name;
    document.getElementById('pCardName').innerText = c.name;
    document.getElementById('pCardEmail').innerText = c.email || "-";
    
    msgA.innerHTML = msgs.map(m => \`<div class="\${m.from==='admin'?'text-right':'text-left'}"><div class="inline-block p-2 rounded \${m.from==='admin'?'bg-blue-600':'bg-slate-700'}">\${escapeHTML(m.text)}</div></div>\`).join('');
    msgA.scrollTop = msgA.scrollHeight;
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
echo "=== Deploy Completato. Esegui Cmd+Shift+R sul browser! ==="

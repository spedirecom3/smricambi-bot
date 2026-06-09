#!/bin/bash
set -e
echo "=== Applicazione Patch Layout e Virtual DOM Diffing ==="
cd ~/smricambi-bot

cat << 'INNER_EOF' > src/main.js
import { Buffer as Buffer2 } from "node:buffer";

function escapeHTML(str) { return !str ? '' : str.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#039;"); }

var src_default = {
  async fetch(request, env2, ctx) {
    const url = new URL(request.url);
    if (url.pathname === "/admin") return new Response(this.getAdminHTML(), { headers: { "Content-Type": "text/html;charset=UTF-8" } });
    if (url.pathname === "/api/chats") {
      let list = await env2.SMR_DB.list({ prefix: "chat_" });
      let chats = [];
      for (const k of list.keys) {
        let phone = k.name.replace("chat_", "");
        let msgs = JSON.parse(await env2.SMR_DB.get(k.name) || "[]");
        let st = JSON.parse(await env2.SMR_DB.get(`status_${phone}`) || "{}");
        chats.push({ phone, ...st, lastUpdate: msgs.length ? msgs[msgs.length-1].timestamp : 0 });
      }
      return new Response(JSON.stringify(chats.sort((a,b) => b.lastUpdate - a.lastUpdate)), { headers: {'Access-Control-Allow-Origin': '*'} });
    }
    if (url.pathname === "/api/chat_detail") {
      const phone = url.searchParams.get("phone");
      return new Response(await env2.SMR_DB.get(`chat_${phone}`), { headers: {'Access-Control-Allow-Origin': '*'} });
    }
    return new Response("OK");
  },

  getAdminHTML() {
    return \`<!DOCTYPE html>
<html>
<head>
  <script src="https://cdn.tailwindcss.com"></script>
  <style>
    body { background: #09090b; color: white; font-family: sans-serif; overflow: hidden; }
    .grid-layout { display: grid; grid-template-columns: 72px 350px 1fr 300px; height: 100vh; }
  </style>
</head>
<body class="grid-layout">
  <aside class="bg-[#0b1120] border-r border-slate-800 flex flex-col items-center py-6">
    <div class="w-10 h-10 bg-blue-600 rounded-xl flex items-center justify-center font-bold">SM</div>
  </aside>
  <aside id="chatList" class="bg-[#121214] border-r border-slate-800 overflow-y-auto"></aside>
  <main class="flex flex-col bg-[#09090b] overflow-hidden">
    <header id="chatH" class="hidden h-[70px] border-b border-slate-800 p-4 flex items-center justify-between">
      <div id="hName" class="font-bold"></div>
    </header>
    <div id="msgA" class="flex-1 overflow-y-auto p-4 space-y-4" data-msg-count="0"></div>
    <form id="comp" class="hidden p-3 bg-[#121214] border-t border-slate-800 flex gap-2">
      <textarea id="msgI" class="flex-1 bg-[#1e293b] p-2 rounded text-sm text-white" placeholder="Rispondi..."></textarea>
      <button class="bg-blue-600 px-4 py-2 rounded">Invia</button>
    </form>
  </main>
  <aside id="profileCard" class="bg-[#121214] border-l border-slate-800 p-5 flex flex-col gap-4">
    <h3 class="text-xs text-slate-500 uppercase font-bold">Anagrafica Lead</h3>
    <div id="pData" class="space-y-3">
        <div><div class="text-[10px] text-slate-500">NOME</div><div id="pCardName" class="text-sm">-</div></div>
        <div><div class="text-[10px] text-slate-500">EMAIL</div><div id="pCardEmail" class="text-sm text-blue-400">-</div></div>
    </div>
  </aside>

<script>
var curr=null;
async function load() {
    var res = await fetch('/api/chats');
    var chats = await res.json();
    document.getElementById('chatList').innerHTML = chats.map(c => \`<div onclick="openChat('\${c.phone}')" class="p-4 border-b border-slate-800 cursor-pointer \${curr===c.phone?'bg-[#1e293b]':''}">\${c.name}</div>\`).join('');
    if(curr) renderM(curr);
}

function openChat(p) { curr = p; renderM(p); }

async function renderM(p) {
    var res = await fetch('/api/chat_detail?phone='+p);
    var msgs = await res.json();
    var msgA = document.getElementById('msgA');
    
    // VIRTUAL DOM DIFFING: Aggiorna solo se il numero di messaggi è cambiato
    if (msgA.dataset.msgCount == msgs.length) return;

    document.getElementById('chatH').classList.remove('hidden');
    document.getElementById('msgA').classList.remove('hidden');
    document.getElementById('comp').classList.remove('hidden');
    
    var isScrolledToBottom = (msgA.scrollHeight - msgA.scrollTop - msgA.clientHeight) < 100;
    
    msgA.innerHTML = msgs.map(m => \`<div class="\${m.from==='admin'?'text-right':'text-left'} p-2"><div class="inline-block p-2 rounded \${m.from==='admin'?'bg-blue-600':'bg-slate-700'}">\${escapeHTML(m.text)}</div></div>\`).join('');
    msgA.dataset.msgCount = msgs.length;
    
    if (isScrolledToBottom) msgA.scrollTop = msgA.scrollHeight;
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
</html>\`;
  }
};
export { src_default as default };
INNER_EOF
npx wrangler deploy
echo "=== Deploy Completato. Eseguire Hard Refresh ==="

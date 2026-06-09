#!/bin/bash
set -e
cd ~/smricambi-bot

cat << 'INNER_EOF' > src/main.js
import { Buffer as Buffer2 } from "node:buffer";

// Helper sanitizzazione
function escapeHTML(str) { return !str ? '' : str.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }

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
            chats.push({ phone, ...st, lastMsg: msgs.length ? msgs[msgs.length-1] : null, msgCount: msgs.length });
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
<html class="h-full">
<head>
  <script src="https://cdn.tailwindcss.com"></script>
  <style>
    body { background: #0f172a; color: white; font-family: sans-serif; overflow: hidden; height: 100vh; }
    /* Layout fisso: 4 colonne, nessuna media query che nasconde */
    .app-grid { display: grid; grid-template-columns: 72px 350px 1fr 300px; height: 100vh; }
    #msgA { scroll-behavior: auto; }
  </style>
</head>
<body class="app-grid">
  <aside class="bg-[#0b1120] border-r border-slate-800 flex flex-col items-center py-6"><div class="w-10 h-10 bg-blue-600 rounded-xl flex items-center justify-center font-bold">SM</div></aside>
  <aside id="chatList" class="bg-[#121214] border-r border-slate-800 overflow-y-auto"></aside>
  <main class="flex flex-col bg-[#0f172a] overflow-hidden">
    <header id="chatH" class="hidden h-[70px] border-b border-slate-800 p-4 font-bold"></header>
    <div id="msgA" class="flex-1 overflow-y-auto p-4 space-y-4" data-msg-count="0"></div>
    <form id="comp" class="hidden p-3 bg-[#121214] border-t border-slate-800 flex gap-2">
      <textarea id="msgI" class="flex-1 bg-[#1e293b] p-2 rounded text-sm"></textarea>
      <button class="bg-blue-600 px-4 py-2 rounded">Invia</button>
    </form>
  </main>
  <aside id="profileCard" class="bg-[#121214] border-l border-slate-800 p-5 flex flex-col gap-4">
    <h3 class="text-xs text-slate-500 uppercase font-bold">Anagrafica Lead</h3>
    <div id="pCardContent" class="space-y-3 text-sm"></div>
  </aside>

<script>
var curr=null;
// Funzione di caricamento lista
async function loadList() {
    var res = await fetch('/api/chats?v='+Date.now());
    var chats = await res.json();
    document.getElementById('chatList').innerHTML = chats.map(c => \`
        <div onclick="openChat('\${c.phone}')" class="p-4 border-b border-slate-800 cursor-pointer \${curr===c.phone?'bg-[#1e293b]':''} flex justify-between">
            <div>
                <div class="font-bold text-sm">\${c.name}</div>
                <div class="text-[10px] text-slate-500">\${c.channel}</div>
            </div>
            <div id="badge-\${c.phone}" class="w-2 h-2 rounded-full hidden bg-blue-500"></div>
        </div>\`).join('');
    
    // Aggiorna badge unread
    chats.forEach(c => {
        var isUnread = c.msgCount > (localStorage.getItem('count_'+c.phone)||0);
        if(isUnread && curr !== c.phone) document.getElementById('badge-'+c.phone).classList.remove('hidden');
    });
}

function openChat(p) { 
    curr = p;
    // Reset badge
    document.getElementById('badge-'+p).classList.add('hidden');
    var c = chats.find(x=>x.phone==p);
    localStorage.setItem('count_'+p, c.msgCount);
    renderM(p); 
    loadList();
}

async function renderM(p) {
    var res = await fetch('/api/chat_detail?phone='+p+'&v='+Date.now());
    var msgs = await res.json();
    var msgA = document.getElementById('msgA');
    
    // VIRTUAL DOM FIX: Se il numero messaggi è uguale, non toccare il DOM
    if (msgA.dataset.msgCount == msgs.length) return;

    document.getElementById('chatH').classList.remove('hidden');
    document.getElementById('comp').classList.remove('hidden');
    
    // Check se utente è in fondo prima del render
    var isNearBottom = (msgA.scrollHeight - msgA.scrollTop - msgA.clientHeight) < 100;
    
    msgA.innerHTML = msgs.map(m => \`<div class="\${m.from==='admin'?'text-right':'text-left'} p-2"><div class="inline-block p-2 rounded \${m.from==='admin'?'bg-blue-600':'bg-slate-700'}">\${escapeHTML(m.text)}</div></div>\`).join('');
    msgA.dataset.msgCount = msgs.length;
    
    if (isNearBottom) msgA.scrollTop = msgA.scrollHeight;
}

setInterval(loadList, 3000);
loadList();
</script>
</body>
</html>\`;
  }
};
export { src_default as default };
INNER_EOF
npx wrangler deploy
echo "=== Deploy completato. Ricarica con Cmd+Shift+R ==="

#!/bin/bash
set -e
echo "=== Installazione SMR OS V51 (Hard Reset Layout & Scroll) ==="
cd ~/smricambi-bot

cat << 'INNER_EOF' > src/main.js
import { Buffer as Buffer2 } from "node:buffer";
var CORS = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Methods": "GET, POST, OPTIONS", "Access-Control-Allow-Headers": "Content-Type" };

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
        chats.push({ phone, ...st, lastUpdate: msgs.length ? msgs[msgs.length-1].timestamp : 0, msgCount: msgs.length });
      }
      return new Response(JSON.stringify(chats.sort((a,b) => b.lastUpdate - a.lastUpdate)), { headers: {'Access-Control-Allow-Origin': '*'} });
    }
    if (url.pathname === "/api/chat_detail") {
      const phone = url.searchParams.get("phone");
      return new Response(await env2.SMR_DB.get(`chat_${phone}`), { headers: {'Access-Control-Allow-Origin': '*'} });
    }
    return new Response("OK", { headers: {'Access-Control-Allow-Origin': '*'} });
  },

  getAdminHTML() {
    return `<!DOCTYPE html>
<html>
<head>
  <script src="https://cdn.tailwindcss.com"></script>
  <style>
    body { background: #0f172a; height: 100vh; overflow: hidden; }
    .app-grid { display: grid; grid-template-columns: 72px 350px 1fr 300px; height: 100vh; }
    #msgA { scroll-behavior: auto; }
  </style>
</head>
<body class="app-grid">
  <aside class="bg-[#0b1120] border-r border-slate-800 flex flex-col items-center py-6"><div class="w-10 h-10 bg-blue-600 rounded-xl flex items-center justify-center font-bold">SM</div></aside>
  <aside id="chatList" class="bg-[#121214] border-r border-slate-800 overflow-y-auto"></aside>
  <main class="flex flex-col bg-[#0f172a] overflow-hidden">
    <header id="chatH" class="hidden h-[70px] border-b border-slate-800 p-4 font-bold flex items-center justify-between">
        <div id="hName"></div>
    </header>
    <div id="msgA" class="flex-1 overflow-y-auto p-4 space-y-4" data-msg-count="0"></div>
    <form id="comp" class="hidden p-3 bg-[#121214] border-t border-slate-800 flex gap-2">
      <textarea id="msgI" class="flex-1 bg-[#1e293b] p-2 rounded text-sm text-white" placeholder="Rispondi..."></textarea>
      <button class="bg-blue-600 px-4 py-2 rounded text-white font-bold">Invia</button>
    </form>
  </main>
  <aside id="profileCard" class="bg-[#121214] border-l border-slate-800 p-5 flex-col gap-4 hidden">
    <h3 class="text-xs text-slate-500 uppercase font-bold">Anagrafica Lead</h3>
    <div class="space-y-3 text-sm">
        <div><div class="text-[10px] text-slate-500 uppercase">Nome</div><div id="pCardName"></div></div>
        <div><div class="text-[10px] text-slate-500 uppercase">Email</div><div id="pCardEmail" class="text-blue-400"></div></div>
    </div>
  </aside>

<script>
var curr=null;
async function load() {
    var res = await fetch('/api/chats?v='+Date.now());
    var chats = await res.json();
    document.getElementById('chatList').innerHTML = chats.map(c => {
        var d = new Date(c.lastUpdate);
        var dateStr = d.toLocaleDateString('it-IT', {day:'2-digit', month:'2-digit'});
        var isUnread = c.msgCount > (localStorage.getItem('count_'+c.phone)||0);
        return \`<div onclick="openChat('\${c.phone}')" class="p-4 border-b border-slate-800 cursor-pointer \${curr===c.phone?'bg-[#1e293b]':''}">
            <div class="flex justify-between font-bold text-sm text-white mb-1">
                \${c.name} <span class="text-[10px] text-slate-500">\${dateStr}</span>
            </div>
            \${isUnread && curr!==c.phone ? '<div class="w-2 h-2 bg-blue-500 rounded-full"></div>' : ''}
        </div>\`;
    }).join('');
    if(curr) renderM(curr);
}

function openChat(p) { 
    curr = p; 
    localStorage.setItem('count_'+p, chats.find(x=>x.phone==p).msgCount);
    renderM(p);
    load(); // Refresh list to remove badge
}

async function renderM(p) {
    var res = await fetch('/api/chat_detail?phone='+p+'&v='+Date.now());
    var msgs = await res.json();
    var c = chats.find(x=>x.phone==p);
    var msgA = document.getElementById('msgA');
    
    // Aggiornamento Pannello Destro
    document.getElementById('profileCard').style.display = 'flex';
    document.getElementById('pCardName').innerText = c.name;
    document.getElementById('pCardEmail').innerText = c.email || "-";
    
    // Auto-Scroll Logic: scrolla solo se l'utente NON è risalito manualmente
    var isNearBottom = (msgA.scrollHeight - msgA.scrollTop - msgA.clientHeight) < 150;
    
    if (msgA.dataset.msgCount != msgs.length) {
        document.getElementById('chatH').classList.remove('hidden');
        document.getElementById('comp').classList.remove('hidden');
        document.getElementById('hName').innerText = c.name;
        
        msgA.innerHTML = msgs.map(m => \`<div class="\${m.from==='admin'?'text-right':'text-left'} p-2"><div class="inline-block p-2 rounded \${m.from==='admin'?'bg-blue-600':'bg-slate-700'}">\${escapeHTML(m.text)}</div></div>\`).join('');
        msgA.dataset.msgCount = msgs.length;
        
        if (isNearBottom || msgA.dataset.msgCount == 0) msgA.scrollTop = msgA.scrollHeight;
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
</html>\`;
  }
};
export { src_default as default };
INNER_EOF

npx wrangler deploy
echo "=== Deploy Completato. ESEGUI: Cmd+Shift+R ==="

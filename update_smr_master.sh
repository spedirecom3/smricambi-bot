#!/bin/bash
set -e

echo "=== Iniezione SMR OS Enterprise (Patch Sicurezza, Layout e UX) ==="

cd ~/smricambi-bot

cat << 'INNER_EOF' > src/main.js
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

var src_default = {
  async getSafeJSON(env2, key, defaultVal) {
    try {
      if (!env2.SMR_DB) return defaultVal;
      const raw = await env2.SMR_DB.get(key);
      if (raw === null || raw === "null" || typeof raw === "undefined") return defaultVal;
      return JSON.parse(raw);
    } catch (e) { return defaultVal; }
  },

  async scheduled(event, env2, ctx) {
    if (!env2.SMR_DB || !env2.SMR_BUCKET) return;
    try {
      const list = await env2.SMR_DB.list();
      let backupData = {};
      for (const k of list.keys) backupData[k.name] = await env2.SMR_DB.get(k.name);
      await env2.SMR_BUCKET.put(`backup/db_backup_${new Date().toISOString().split("T")[0]}.json`, JSON.stringify(backupData), { httpMetadata: { contentType: "application/json" } });
    } catch (e) { console.error("Backup Error", e); }
  },

  async fetch(request, env2, ctx) {
    const url = new URL(request.url);
    if (request.method === "OPTIONS") return new Response(null, { headers: CORS });
    if (!env2.SMR_DB) return new Response("ERRORE: SMR_DB non trovato.", { status: 500, headers: CORS });

    try {
      if (url.pathname === "/admin") return new Response(this.getAdminHTML(), { headers: { "Content-Type": "text/html;charset=UTF-8" } });
      if (url.pathname === "/api/chats") return this.handleChatSnapshot(request, env2);
      if (url.pathname === "/api/chat_detail") return this.handleSingleChat(request, env2);
      if (url.pathname === "/api/widget") return this.handleWidget(request, env2, ctx);
      if (url.pathname === "/api/reply") return this.handleReply(request, env2);
      if (url.pathname === "/api/ingest") return this.handleIngest(request, env2);
      if (url.pathname === "/api/toggle") return this.handleToggle(request, env2);
      if (url.pathname === "/api/resolve") return this.handleResolve(request, env2);
      if (url.pathname === "/api/delete") return this.handleDelete(request, env2);
      if (url.pathname === "/api/reset-db") return this.handleResetDB(env2);
      if (url.pathname === "/api/upload" && request.method === "POST") return this.handleUpload(request, env2);
      if (url.pathname.startsWith("/api/media/")) return this.handleMedia(url, env2);

      if (request.method === "POST") {
        const body = await request.json();
        const msg = body?.entry?.[0]?.changes?.[0]?.value?.messages?.[0];
        const name = body?.entry?.[0]?.changes?.[0]?.value?.contacts?.[0]?.profile?.name || "Cliente WA";
        if (msg) ctx.waitUntil(this.handleWhatsApp(msg, name, env2, ctx));
        return new Response("OK");
      }
      return new Response("SMR OS TIER ENTERPRISE ACTIVE");
    } catch (err) { return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: CORS }); }
  },

  async handleChatSnapshot(request, env2) {
    const url = new URL(request.url);
    const forceSync = url.searchParams.get("force") === "true";
    let snapshot = await this.getSafeJSON(env2, "crm_snapshot", null);

    if (forceSync || !snapshot || Object.keys(snapshot).length === 0) {
      snapshot = snapshot || {};
      try {
        const list = await env2.SMR_DB.list({ prefix: "chat_" });
        for (const k of list.keys) {
          const phone = k.name.replace("chat_", "");
          const messages = await this.getSafeJSON(env2, k.name, []);
          const status = await this.getSafeJSON(env2, `status_${phone}`, { name: "Sconosciuto", channel: "whatsapp", resolved: false });
          if (messages.length > 0) {
            snapshot[phone] = { status, lastMessage: messages[messages.length - 1], lastUpdate: messages[messages.length - 1].timestamp };
          }
        }
        await env2.SMR_DB.put("crm_snapshot", JSON.stringify(snapshot));
      } catch (e) { console.error("Sync Error", e); }
    }
    let chats = Object.keys(snapshot).map((phone) => {
      let data = snapshot[phone];
      return { phone, ...data.status || {}, messages: data.lastMessage ? [data.lastMessage] : [], lastUpdate: data.lastUpdate || 0 };
    });
    chats.sort((a, b) => b.lastUpdate - a.lastUpdate);
    return new Response(JSON.stringify(chats), { headers: CORS });
  },

  async handleSingleChat(request, env2) {
    const phone = new URL(request.url).searchParams.get("phone");
    if (!phone) return new Response("[]", { headers: CORS });
    const messages = await this.getSafeJSON(env2, `chat_${phone}`, []);
    return new Response(JSON.stringify(messages), { headers: CORS });
  },

  // FIX: Prevenzione Race Conditions con retry e Jitter
  async saveLog(p, obj, env2, statusObj) {
    let retries = 3;
    while(retries > 0) {
      try {
        let chat = await this.getSafeJSON(env2, `chat_${p}`, []);
        if (typeof chat !== "object" || !Array.isArray(chat)) chat = [];
        if (obj.text && obj.text.startsWith("data:image") && obj.text.length > 1000) obj.text = "[Immagine Elaborata dall'OCR del Sistema]";
        chat.push(obj);
        await env2.SMR_DB.put(`chat_${p}`, JSON.stringify(chat.slice(-150)));
        let snap = await this.getSafeJSON(env2, "crm_snapshot", {});
        if (!snap[p]) snap[p] = {};
        snap[p].status = statusObj || await this.getSafeJSON(env2, `status_${p}`, {});
        snap[p].lastMessage = obj;
        snap[p].lastUpdate = Date.now();
        await env2.SMR_DB.put("crm_snapshot", JSON.stringify(snap));
        return;
      } catch(e) {
        retries--;
        await new Promise(r => setTimeout(r, Math.random() * 100 + 50));
      }
    }
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
        let note = `📝 DATI ESTRATTI DALLA TARGHETTA:\n${aiData.choices[0].message.content}`;
        await this.saveLog(from, { from: "system", text: note, timestamp: Date.now() }, env2, st);
      }
    } catch (e) { console.error("OCR Failed", e); }
  },

  // FIX: Validazione e Sicurezza File
  async handleUpload(request, env2) {
    try {
      const formData = await request.formData();
      const file = formData.get("file");
      if (!file || !file.name) return new Response("Nessun file", { status: 400, headers: CORS });
      
      const allowedTypes = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];
      if (!allowedTypes.includes(file.type) || file.size > 10 * 1024 * 1024) {
        return new Response(JSON.stringify({ error: "File non supportato o maggiore di 10MB" }), { status: 415, headers: CORS });
      }

      const ext = file.name.split(".").pop().replace(/[^a-zA-Z0-9]/g, "");
      const fileName = `smr_${Date.now()}_${Math.random().toString(36).substring(7)}.${ext}`;
      await env2.SMR_BUCKET.put(fileName, file.stream(), { httpMetadata: { contentType: file.type } });
      return new Response(JSON.stringify({ url: `/api/media/r2_${fileName}`, type: file.type, name: file.name, id: `r2_${fileName}` }), { headers: CORS });
    } catch (e) { return new Response(JSON.stringify({ error: e.message }), { status: 500, headers: CORS }); }
  },

  async handleMedia(url, env2) {
    const mediaId = url.pathname.split("/")[3];
    if (!mediaId) return new Response("Missing ID", { status: 400, headers: CORS });
    try {
      if (mediaId.startsWith("r2_")) {
        const object = await env2.SMR_BUCKET.get(mediaId.replace("r2_", ""));
        if (!object) return new Response("Not found", { status: 404, headers: CORS });
        const headers = new Headers();
        object.writeHttpMetadata(headers);
        headers.set("Access-Control-Allow-Origin", "*");
        return new Response(object.body, { headers });
      } else {
        const infoRes = await fetch(`${WA_API}/${mediaId}`, { headers: { "Authorization": `Bearer ${env2.WHATSAPP_TOKEN}` } });
        const info3 = await infoRes.json();
        const mediaRes = await fetch(info3.url, { headers: { "Authorization": `Bearer ${env2.WHATSAPP_TOKEN}` } });
        return new Response(mediaRes.body, { headers: { "Content-Type": mediaRes.headers.get("content-type"), ...CORS } });
      }
    } catch (e) { return new Response("Error", { status: 500, headers: CORS }); }
  },

  async handleWidget(request, env2, ctx) {
    const { userId, text, name, email, cellulare, attachment, analytics } = await request.json();
    const channelId = `web_${userId}`;
    let st = await this.getSafeJSON(env2, `status_${channelId}`, { manual: false, resolved: false, tag: "NEUTRO" });
    st.name = name || st.name || "Visitatore Web";
    st.email = email || st.email;
    st.cellulare = cellulare || st.cellulare || "Non inserito";
    st.channel = "web";
    st.resolved = false;

    if (analytics && text) {
      st.activePage = analytics.url;
      await this.saveLog(channelId, { from: "system", text: `👁️ Visitatore sulla pagina: ${analytics.url}`, timestamp: Date.now() }, env2, st);
    }
    let msgText = text || "";
    let mediaId = null;
    let mediaType = null;
    let fileName = null;
    
    // FIX: Garantire il prefisso r2_ se proveniente da web widget
    if (attachment) {
      msgText = text || "📎 Allegato Inviato";
      mediaId = attachment.id || attachment.url.split("/").pop();
      if (!mediaId.startsWith("r2_")) mediaId = "r2_" + mediaId; 
      mediaType = attachment.type.includes("image") ? "image" : "document";
      fileName = attachment.name;
    }
    if (msgText) await this.saveLog(channelId, { from: "user", text: msgText, mediaId, mediaType, fileName, timestamp: Date.now() }, env2, st);
    
    if (mediaId) {
      st.manual = true;
      st.until = Date.now() + 864e5 * 2;
      st.tag = "VENDITA";
      await env2.SMR_DB.put(`status_${channelId}`, JSON.stringify(st));
      let reply = "Ho ricevuto il documento. Un nostro tecnico lo sta verificando e ti risponderà qui a breve.";
      await this.saveLog(channelId, { from: "bot", text: reply, timestamp: Date.now() }, env2, st);
      ctx.waitUntil(this.processImageOCR(mediaId, mediaType, channelId, env2, st));
      return new Response(JSON.stringify({ reply, buttons: null }), { headers: CORS });
    }
    if (st.manual && st.until > Date.now()) return new Response(JSON.stringify({ reply: "" }), { headers: CORS });
    const history = await this.getSafeJSON(env2, `chat_${channelId}`, []);
    const showBtns = history.length <= 3;
    const aiData = await this.generateAI(msgText, env2, showBtns, st);
    st.tag = aiData.tag;
    await env2.SMR_DB.put(`status_${channelId}`, JSON.stringify(st));
    await this.saveLog(channelId, { from: "bot", text: aiData.text, timestamp: Date.now() }, env2, st);
    return new Response(JSON.stringify({ reply: aiData.text, buttons: aiData.buttons }), { headers: CORS });
  },

  async handleWhatsApp(m, name, env2, ctx) {
    const from = m.from;
    let text = ""; let mediaId = null; let mediaType = null;
    if (m.type === "text") text = m.text.body;
    else if (m.type === "interactive") text = m.interactive?.button_reply?.title || m.interactive?.list_reply?.title || "";
    else if (m.type === "image") { text = m.image.caption || "📷 Foto Ricevuta"; mediaId = m.image.id; mediaType = "image"; } 
    else if (m.type === "document") { text = m.document.caption || "📄 Documento Ricevuto"; mediaId = m.document.id; mediaType = "document"; }
    
    if (!text && !mediaId) return;
    let st = await this.getSafeJSON(env2, `status_${from}`, { manual: false, resolved: false, tag: "NEUTRO" });
    st.name = name; st.channel = "whatsapp"; st.resolved = false; st.lastUserInteraction = Date.now();
    await this.saveLog(from, { from: "user", text, mediaId, mediaType, timestamp: Date.now() }, env2, st);
    
    const history = await this.getSafeJSON(env2, `chat_${from}`, []);
    if (history.length <= 1 && !mediaId) {
      let welcomeMsg = { messaging_product: "whatsapp", recipient_type: "individual", to: from, type: "interactive", interactive: { type: "button", body: { text: "Benvenuto! Sono l'assistente IA di S.M. Ricambi.\n\nSeleziona un'opzione:" }, action: { buttons: [ { type: "reply", reply: { id: "btn_ordini", title: "Stato Ordini" } }, { type: "reply", reply: { id: "btn_compat", title: "Compatibilità" } }, { type: "reply", reply: { id: "btn_assist", title: "Assistenza" } } ] } } };
      await fetch(`${WA_API}/${WA_PHONE_ID}/messages`, { method: "POST", headers: { "Authorization": `Bearer ${env2.WHATSAPP_TOKEN}`, "Content-Type": "application/json" }, body: JSON.stringify(welcomeMsg) });
      await this.saveLog(from, { from: "bot", text: "Benvenuto! [Inviati Pulsanti]", timestamp: Date.now() }, env2, st);
      return;
    }
    if (mediaId) {
      st.manual = true; st.until = Date.now() + 864e5 * 2; st.tag = "VENDITA";
      await env2.SMR_DB.put(`status_${from}`, JSON.stringify(st));
      let reply = "Ho ricevuto il documento. Passo subito la chat a un nostro operatore umano.";
      await fetch(`${WA_API}/${WA_PHONE_ID}/messages`, { method: "POST", headers: { "Authorization": `Bearer ${env2.WHATSAPP_TOKEN}`, "Content-Type": "application/json" }, body: JSON.stringify({ messaging_product: "whatsapp", to: from, text: { body: reply } }) });
      await this.saveLog(from, { from: "bot", text: reply, timestamp: Date.now() }, env2, st);
      ctx.waitUntil(this.processImageOCR(mediaId, mediaType, from, env2, st));
      return;
    }
    if (st.manual && st.until > Date.now()) { await env2.SMR_DB.put(`status_${from}`, JSON.stringify(st)); return; }
    
    const aiData = await this.generateAI(text, env2, false, st);
    st.tag = aiData.tag;
    await env2.SMR_DB.put(`status_${from}`, JSON.stringify(st));
    
    const metaFormattedText = formatWhatsAppText(aiData.text);
    await fetch(`${WA_API}/${WA_PHONE_ID}/messages`, { method: "POST", headers: { "Authorization": `Bearer ${env2.WHATSAPP_TOKEN}`, "Content-Type": "application/json" }, body: JSON.stringify({ messaging_product: "whatsapp", to: from, text: { body: metaFormattedText } }) });
    await this.saveLog(from, { from: "bot", text: aiData.text, timestamp: Date.now() }, env2, st);
  },

  async generateAI(userText, env2, showBtns, st) {
    const emb = await env2.AI.run("@cf/baai/bge-base-en-v1.5", { text: [userText] });
    const matches = await env2.VECTORIZE_INDEX.query(emb.data[0], { topK: 5, returnMetadata: "all" });
    const context2 = matches.matches.filter((x) => x.score > 0.45).map((x) => x.metadata.text).join("\n\n");
    const sysPrompt = `Sei l'assistente IA ufficiale di S.M. Ricambi (smricambi.com).
REGOLE TASSATIVE:
1. NOI SIAMO S.M. Ricambi. Mai nominare concorrenti.
2. PROTOCOLLO TARGHETTA: Per identificare un ricambio caldaia/scaldabagno, chiedi SEMPRE al cliente la foto della 'targhetta identificativa interna' con modello e matricola.
3. Se il cliente non ha la targhetta, digli che lo passi ad un operatore umano per sicurezza.
4. Non inventare MAI codici. Affidati a: ${context2}.
5. TRIAGE: Inizia SEMPRE la risposta con un Tag esatto seguito da un |: [VENDITA], [ORDINE], [TECNICO], [URGENTE], [NEUTRO].`;

    const res = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: { "Authorization": `Bearer ${env2.OPENAI_API_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({ model: "gpt-4o-mini", messages: [{ role: "system", content: sysPrompt }, { role: "user", content: userText }], temperature: 0.15 })
    });
    const data = await res.json();
    let rawText = data.choices[0].message.content;
    let tag = st.tag || "NEUTRO";
    if (rawText.includes("|")) {
      let parts = rawText.split("|");
      let potentialTag = parts[0].replace("[", "").replace("]", "").trim();
      if (["VENDITA", "ORDINE", "TECNICO", "URGENTE", "NEUTRO"].includes(potentialTag)) {
        tag = potentialTag; rawText = parts.slice(1).join("|").trim();
      }
    }
    return { text: rawText, tag, buttons: showBtns ? ["📦 Stato Ordini", "🔧 Compatibilità", "👨‍🔧 Assistenza"] : null };
  },

  async handleIngest(request, env2) {
    try {
      const body = await request.json();
      let type = body.type || "text"; let content = body.content || body.text || ""; let source = body.source || "SMR Vault"; let textToMemorize = "";
      if (type === "text") textToMemorize = content;
      else if (type === "url") {
        const res = await fetch(content);
        if (!res.ok) throw new Error("Link inaccessibile");
        textToMemorize = (await res.text()).replace(/<[^>]+>/ig, " ").replace(/\s{2,}/g, " ").trim();
      } else if (type === "image") {
        const aiRes = await fetch("https://api.openai.com/v1/chat/completions", { method: "POST", headers: { "Authorization": `Bearer ${env2.OPENAI_API_KEY}`, "Content-Type": "application/json" }, body: JSON.stringify({ model: "gpt-4o-mini", messages: [{ role: "user", content: [{ type: "text", text: "Estrai dati tecnici." }, { type: "image_url", image_url: { url: content } }] }], temperature: 0.1 }) });
        const aiData = await aiRes.json(); textToMemorize = aiData.choices[0].message.content;
      }
      if (!textToMemorize || textToMemorize.trim().length === 0) return new Response("Nessun dato", { status: 400, headers: CORS });
      const safeText = textToMemorize.substring(0, 1900);
      const kbId = `kb_${Date.now()}_${Math.random().toString(36).substring(7)}`;
      const emb = await env2.AI.run("@cf/baai/bge-base-en-v1.5", { text: [safeText] });
      await env2.VECTORIZE_INDEX.upsert([{ id: kbId, values: emb.data[0], metadata: { text: safeText, source } }]);
      await env2.SMR_DB.put(kbId, JSON.stringify({ text: safeText, type, source, timestamp: Date.now() }));
      return new Response(JSON.stringify({ ok: true, extracted: safeText }), { headers: CORS });
    } catch (e) { return new Response(JSON.stringify({ error: e.message }), { status: 500, headers: CORS }); }
  },

  async handleReply(request, env2) {
    const { phone, text, isNote, mediaUrl, mediaType, fileName, template } = await request.json();
    let st = await this.getSafeJSON(env2, `status_${phone}`, {});
    if (isNote) {
      await this.saveLog(phone, { from: "system", text: `📝 NOTA INTERNA: ${text}`, timestamp: Date.now() }, env2, st);
      return new Response(JSON.stringify({ ok: true }), { headers: CORS });
    }
    if (!phone.startsWith("web_")) {
      let payload = { messaging_product: "whatsapp", to: phone };
      if (template) { payload.type = "template"; payload.template = { name: template, language: { code: "it" } }; } 
      else if (mediaUrl) { let directUrl = new URL(request.url).origin + mediaUrl; payload.type = mediaType.includes("image") ? "image" : "document"; payload[payload.type] = { link: directUrl, caption: text || "" }; } 
      else { payload.type = "text"; payload.text = { body: formatWhatsAppText(text) }; }
      await fetch(`${WA_API}/${WA_PHONE_ID}/messages`, { method: "POST", headers: { "Authorization": `Bearer ${env2.WHATSAPP_TOKEN}`, "Content-Type": "application/json" }, body: JSON.stringify(payload) });
    }
    let logObj = { from: "admin", text, timestamp: Date.now() };
    if (mediaUrl) { logObj.mediaId = mediaUrl.split("/").pop().replace("r2_", ""); logObj.mediaType = mediaType; logObj.fileName = fileName; }
    await this.saveLog(phone, logObj, env2, st);
    return new Response(JSON.stringify({ ok: true }), { headers: CORS });
  },

  async handleToggle(request, env2) {
    const { phone, manual } = await request.json();
    let st = await this.getSafeJSON(env2, `status_${phone}`, {});
    st.manual = manual; st.until = manual ? Date.now() + 864e5 * 2 : 0; st.resolved = false;
    await env2.SMR_DB.put(`status_${phone}`, JSON.stringify(st));
    let snap = await this.getSafeJSON(env2, "crm_snapshot", {});
    if (snap[phone]) { snap[phone].status = st; snap[phone].lastUpdate = Date.now(); }
    await env2.SMR_DB.put("crm_snapshot", JSON.stringify(snap));
    await this.saveLog(phone, { from: "system", text: manual ? "L'operatore ha preso il controllo." : "Controllo ripassato all'Intelligenza Artificiale.", timestamp: Date.now() }, env2, st);
    return new Response(JSON.stringify({ ok: true }), { headers: CORS });
  },

  async handleResolve(request, env2) {
    const { phone } = await request.json();
    let st = await this.getSafeJSON(env2, `status_${phone}`, {});
    st.resolved = true; st.manual = false; st.until = 0;
    await env2.SMR_DB.put(`status_${phone}`, JSON.stringify(st));
    let snap = await this.getSafeJSON(env2, "crm_snapshot", {});
    if (snap[phone]) { snap[phone].status = st; snap[phone].lastUpdate = Date.now(); }
    await env2.SMR_DB.put("crm_snapshot", JSON.stringify(snap));
    await this.saveLog(phone, { from: "system", text: "Conversazione risolta e archiviata.", timestamp: Date.now() }, env2, st);
    return new Response(JSON.stringify({ ok: true }), { headers: CORS });
  },

  async handleResetDB(env2) {
    const list = await env2.SMR_DB.list({ prefix: "chat_" });
    for (const k of list.keys) { await env2.SMR_DB.delete(k.name); await env2.SMR_DB.delete(k.name.replace("chat_", "status_")); }
    await env2.SMR_DB.delete("crm_snapshot");
    return new Response(JSON.stringify({ ok: true }), { headers: CORS });
  },

  async handleDelete(request, env2) {
    const { phone } = await request.json();
    await env2.SMR_DB.delete(`chat_${phone}`); await env2.SMR_DB.delete(`status_${phone}`);
    let snap = await this.getSafeJSON(env2, "crm_snapshot", {}); delete snap[phone];
    await env2.SMR_DB.put("crm_snapshot", JSON.stringify(snap));
    return new Response(JSON.stringify({ ok: true }), { headers: CORS });
  },

  getAdminHTML() {
    return `<!DOCTYPE html>
<html lang="it">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>SMR OS - Enterprise Core</title>
  <script src="https://cdn.tailwindcss.com"><\/script>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background-color: #0f172a; overflow: hidden; }
    ::-webkit-scrollbar { width: 4px; height: 4px; } ::-webkit-scrollbar-thumb { background: #334155; border-radius: 10px; }
    .chat-item { transition: background 0.2s; border-left: 3px solid transparent; }
    .chat-item.active { background-color: #1e293b; border-left-color: #3b82f6; }
    .unread-wa { background-color: rgba(16, 185, 129, 0.05); border-left-color: #10b981; }
    .unread-web { background-color: rgba(59, 130, 246, 0.05); border-left-color: #3b82f6; }
    .msg-bubble { max-width: 85%; padding: 12px 16px; border-radius: 16px; font-size: 14px; line-height: 1.5; word-wrap: break-word; }
    .msg-admin { background: #2563eb; color: #ffffff; border-bottom-right-radius: 4px; }
    .msg-user { background: #1e293b; color: #f8fafc; border-bottom-left-radius: 4px; border: 1px solid #334155; }
    .msg-bot { background: rgba(59, 130, 246, 0.1); color: #93c5fd; border: 1px solid rgba(59, 130, 246, 0.2); border-bottom-left-radius: 4px; }
    .msg-system { background: #334155; color: #cbd5e1; border-radius: 12px; font-size: 12px; padding: 8px 12px; text-align: center; width: 100%; }
    
    /* Layout a Griglia Infallibile */
    @media (max-width: 767px) { .mobile-hide { display: none !important; } .col-grid { grid-template-columns: 1fr !important; } }
  </style>
</head>
<body class="h-screen w-screen grid grid-cols-1 md:grid-cols-[72px_320px_1fr] lg:grid-cols-[72px_320px_1fr_280px] xl:grid-cols-[72px_340px_1fr_300px] overflow-hidden bg-[#0f172a] text-slate-200 col-grid">

  <aside class="h-full bg-[#0b1120] flex flex-col items-center py-6 gap-6 border-r border-slate-800 shrink-0 mobile-hide">
    <div class="w-10 h-10 bg-blue-600 rounded-xl flex items-center justify-center text-white font-bold shadow-lg">SM</div>
    <div class="p-3 text-slate-400 hover:text-white rounded-xl cursor-pointer transition" onclick="showT()"><svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"></path><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"></path></svg></div>
    <div class="mt-auto p-3 text-slate-400 hover:text-blue-500 cursor-pointer transition" onclick="location.reload()"><svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path></svg></div>
  </aside>

  <aside id="chatListContainer" class="h-full bg-[#0f172a] border-r border-slate-800 flex flex-col overflow-hidden min-w-0">
    <div class="p-4 border-b border-slate-800">
      <h2 class="font-bold text-lg text-white mb-4">Inbox Live</h2>
      <div class="flex bg-[#1e293b] p-1 rounded-lg mb-3">
        <button onclick="setTab(false)" class="flex-1 py-1.5 text-xs font-semibold bg-blue-600 text-white rounded">Attive</button>
        <button onclick="setTab(true)" class="flex-1 py-1.5 text-xs font-semibold text-slate-400">Archivio</button>
      </div>
      <input type="text" id="search" placeholder="Cerca conversazione..." class="w-full text-xs bg-[#1e293b] px-3 py-2 rounded-lg border border-slate-700 text-white outline-none focus:border-blue-500" oninput="renderL()">
    </div>
    <div id="chatList" class="flex-1 overflow-y-auto"></div>
  </aside>

  <main id="chatAreaContainer" class="h-full flex flex-col relative bg-[#0b1120] border-r border-slate-800 overflow-hidden min-w-0 mobile-hide">
    <div id="empty" class="absolute inset-0 flex flex-col items-center justify-center text-slate-500 z-0">
      <p class="text-sm font-medium">Seleziona una chat</p>
    </div>

    <header id="chatH" class="h-[70px] border-b border-slate-800 px-4 flex items-center justify-between hidden bg-[#0f172a] shrink-0 z-10">
      <div class="flex items-center gap-3 min-w-0">
        <button onclick="closeChatMobile()" class="md:hidden text-slate-400"><svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M15 19l-7-7 7-7"></path></svg></button>
        <div id="hAvatar" class="w-10 h-10 rounded-full flex items-center justify-center font-bold text-white shrink-0"></div>
        <div class="min-w-0"><h3 id="hName" class="font-bold text-sm text-white truncate"></h3><p id="hDetails" class="text-xs text-slate-400 truncate"></p></div>
      </div>
      <div class="flex gap-2 shrink-0">
        <button id="resolveBtn" onclick="resolveChat()" class="px-3 py-1.5 rounded-lg text-xs font-bold text-emerald-400 bg-emerald-500/10 border border-emerald-500/20 hidden">Risolvi</button>
        <button id="toggleBtn" onclick="toggleM()" class="px-3 py-1.5 rounded-lg text-xs font-bold text-white bg-blue-600"></button>
      </div>
    </header>

    <div id="msgA" class="flex-1 overflow-y-auto p-4 space-y-4 hidden bg-[#0b1120]" data-last-render=""></div>

    <div id="compWrapper" class="hidden flex-col border-t border-slate-800 bg-[#0f172a] p-3 shrink-0">
      <form id="comp" class="flex gap-2 items-end">
        <input type="file" id="adminFile" class="hidden" onchange="document.getElementById('filePreview').innerText=this.files[0].name; document.getElementById('filePreview').classList.remove('hidden');">
        <button type="button" onclick="document.getElementById('adminFile').click()" class="p-2 text-slate-400 hover:text-white bg-[#1e293b] rounded-lg"><svg width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13"></path></svg></button>
        <div id="filePreview" class="hidden text-[10px] text-blue-400 bg-blue-900/20 px-2 py-1 rounded truncate max-w-[100px]"></div>
        <textarea id="msgI" class="flex-1 bg-[#1e293b] border border-slate-700 rounded-lg px-3 py-2 text-sm text-white outline-none resize-none" rows="1" style="min-height:38px; max-height:100px;" placeholder="Scrivi messaggio..."></textarea>
        <button type="submit" id="sendBtn" class="bg-blue-600 text-white px-4 py-2 rounded-lg font-bold text-sm">Invia</button>
      </form>
    </div>
  </main>

  <aside id="profileCard" class="h-full bg-[#0f172a] flex flex-col shrink-0 p-5 hidden lg:flex overflow-y-auto min-w-0">
    <h3 class="text-slate-400 font-bold text-xs uppercase tracking-wider mb-4 border-b border-slate-800 pb-2">Dettagli Utente</h3>
    <div class="space-y-4">
      <div><label class="text-[10px] text-slate-500 font-semibold block uppercase">Nome</label><p id="pCardName" class="text-sm font-bold text-white truncate">-</p></div>
      <div><label class="text-[10px] text-slate-500 font-semibold block uppercase">Email</label><p id="pCardEmail" class="text-sm text-blue-400 truncate">-</p></div>
      <div><label class="text-[10px] text-slate-500 font-semibold block uppercase">Telefono</label><p id="pCardPhone" class="text-sm text-white truncate">-</p></div>
      <div><label class="text-[10px] text-slate-500 font-semibold block uppercase">Origine</label><p id="pCardChannel" class="text-sm text-slate-300 uppercase">-</p></div>
    </div>
  </aside>

<script>
var curr=null, chats=[], currentManual=false, viewArchived=false;

function escapeHTML(str) { return !str ? '' : str.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#039;"); }

async function load(){ 
  try { 
    var r = await fetch('/api/chats'); if(!r.ok) return;
    chats = await r.json(); 
    renderL(); if(curr) fetchChatDetailAndRender(curr);
  } catch(e) {} 
}

async function fetchChatDetailAndRender(phone) {
    try {
        var r = await fetch('/api/chat_detail?phone=' + phone); if(!r.ok) return;
        var c = chats.find(x => x.phone === phone);
        if (c) { c.messages = await r.json(); renderM(phone); }
    } catch(e) {}
}

function renderL() { 
  try {
    var q = document.getElementById('search').value.toLowerCase();
    var filtered = chats.filter(c => ((c.name||'').toLowerCase().includes(q) || (c.phone||'').includes(q)) && !!c.resolved === viewArchived);
    var htmlContent = "";

    filtered.forEach(c => {
      var msgs = c.messages || []; var lastMsg = msgs.length ? msgs[msgs.length - 1] : null;
      var lastText = lastMsg ? (lastMsg.text || 'Allegato') : ''; 
      var isUnread = (lastMsg && lastMsg.from === 'user' && lastMsg.timestamp > (localStorage.getItem('read_'+c.phone)||0) && curr !== c.phone);
      var bgClass = isUnread ? 'bg-[#1e293b] border-l-blue-500' : (curr === c.phone ? 'active' : ''); 
      var avatarBg = c.channel === 'whatsapp' ? 'bg-emerald-600' : 'bg-blue-600';

      htmlContent += \`<div onclick="openChatMobile('\${c.phone}')" class="chat-item p-3 border-b border-slate-800 cursor-pointer \${bgClass}">
        <div class="flex items-center gap-3">
          <div class="w-10 h-10 rounded-full flex items-center justify-center text-white text-xs font-bold \${avatarBg}">\${(c.name||'?').charAt(0).toUpperCase()}</div>
          <div class="flex-1 min-w-0">
            <div class="font-semibold text-sm text-white truncate">\${c.name||c.phone}</div>
            <div class="text-xs truncate \${isUnread?'text-blue-400 font-bold':'text-slate-400'}">\${lastText}</div>
          </div>
        </div>
      </div>\`;
    });
    document.getElementById('chatList').innerHTML = htmlContent;
  } catch(e) {}
}

function renderM(p) { 
  try {
    var c = chats.find(x => x.phone === p); if(!c) return; 
    var msgA = document.getElementById('msgA');
    
    document.getElementById('empty').classList.add('hidden');
    ['chatH','msgA','compWrapper'].forEach(id => document.getElementById(id).classList.remove('hidden'));
    
    if (c.messages && c.messages.length > 0) localStorage.setItem('read_' + p, c.messages[c.messages.length-1].timestamp);

    currentManual = c.manual;
    document.getElementById('hAvatar').innerText = (c.name||'?').charAt(0).toUpperCase();
    document.getElementById('hAvatar').className = "w-10 h-10 rounded-full flex items-center justify-center font-bold text-white shrink-0 " + (c.channel === 'web' ? 'bg-blue-600' : 'bg-emerald-600');
    document.getElementById('hName').innerText = c.name || c.phone;
    
    document.getElementById('pCardName').innerText = c.name || "Anonimo";
    document.getElementById('pCardEmail').innerText = c.email || "-";
    document.getElementById('pCardPhone').innerText = c.cellulare || (c.channel === 'whatsapp' ? '+'+c.phone : "-");
    document.getElementById('pCardChannel').innerText = c.channel;
    
    var tb = document.getElementById('toggleBtn'); var rb = document.getElementById('resolveBtn');
    if(c.manual) { tb.innerHTML = "Attiva Bot"; tb.className = "px-3 py-1.5 rounded-lg text-xs font-bold bg-[#1e293b] border border-slate-700 text-slate-300"; rb.classList.remove('hidden'); } 
    else { tb.innerHTML = "Prendi Controllo"; tb.className = "px-3 py-1.5 rounded-lg text-xs font-bold text-white bg-blue-600"; rb.classList.add('hidden'); }

    var html = '';
    (c.messages||[]).forEach(m => { 
      if (m.from === 'system') { html += \`<div class="msg-system">\${escapeHTML(m.text)}</div>\`; return; }
      var isRight = m.from === 'admin';
      var mediaHtml = m.mediaId ? (m.mediaType === 'image' ? \`<a href="/api/media/\${m.mediaId}" target="_blank"><img src="/api/media/\${m.mediaId}" class="max-w-[200px] rounded-lg mb-2"></a>\` : \`<a href="/api/media/\${m.mediaId}" target="_blank" class="text-xs text-blue-200 block mb-1">📎 \${escapeHTML(m.fileName||'File')}</a>\`) : '';
      html += \`<div class="flex flex-col \${isRight?'items-end':'items-start'} w-full"><div class="msg-bubble \${isRight?'msg-admin':(m.from==='bot'?'msg-bot':'msg-user')}">\${mediaHtml}<div>\${escapeHTML(m.text||'')}</div></div></div>\`;
    }); 
    
    if (msgA.dataset.lastRender !== html) {
      var isAtBottom = Math.ceil(msgA.scrollTop + msgA.clientHeight) >= (msgA.scrollHeight - 5);
      var currentScroll = msgA.scrollTop;
      var isInitialOpen = (window.lastOpenedPhone !== p);
      window.lastOpenedPhone = p;
      
      msgA.innerHTML = html; 
      msgA.dataset.lastRender = html;
      
      if (isAtBottom || isInitialOpen) msgA.scrollTop = msgA.scrollHeight;
      else msgA.scrollTop = currentScroll;
    }
  } catch(e) {}
}

function openChatMobile(phone) { curr = phone; document.getElementById('chatListContainer').classList.add('mobile-hide'); document.getElementById('chatAreaContainer').classList.remove('mobile-hide'); fetchChatDetailAndRender(phone); }
function closeChatMobile() { curr = null; document.getElementById('chatListContainer').classList.remove('mobile-hide'); document.getElementById('chatAreaContainer').classList.add('mobile-hide'); document.getElementById('empty').classList.remove('hidden'); ['chatH','msgA','compWrapper'].forEach(id => document.getElementById(id).classList.add('hidden')); }

async function toggleM(){ await fetch('/api/toggle', {method: 'POST', body: JSON.stringify({phone: curr, manual: !currentManual})}); load(); }
async function resolveChat(){ await fetch('/api/resolve', {method: 'POST', body: JSON.stringify({phone: curr})}); curr=null; location.reload(); }

document.getElementById('msgI').addEventListener('input', function() { this.style.height = '38px'; this.style.height = (this.scrollHeight) + 'px'; });

// Keyboard Shortcuts (UX Upgrade)
document.addEventListener('keydown', (e) => {
  if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') { e.preventDefault(); document.getElementById('sendBtn').click(); }
  if (e.key === 'Escape' && curr && window.innerWidth >= 768) { curr = null; location.reload(); }
});

document.getElementById('comp').onsubmit = async(e) => { 
  e.preventDefault(); var i = document.getElementById('msgI'); var btn = document.getElementById('sendBtn'); var f = document.getElementById('adminFile').files[0]; var t = i.value.trim();
  if (!curr || (!t && !f)) return;
  i.disabled = true; btn.disabled = true; btn.innerText = "...";
  try {
    let payload = { phone: curr, text: t };
    if (f) {
      const fd = new FormData(); fd.append("file", f);
      const res = await fetch('/api/upload', { method: 'POST', body: fd }); const data = await res.json();
      payload.mediaUrl = data.url; payload.mediaType = data.type; payload.fileName = data.name;
      document.getElementById('adminFile').value = ""; document.getElementById('filePreview').classList.add('hidden');
    }
    await fetch('/api/reply', { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify(payload) }); 
  } catch(err) {}
  i.value = ''; i.style.height = '38px'; i.disabled = false; btn.disabled = false; btn.innerText = "Invia"; i.focus(); load(); 
};

setInterval(load, 3500); load();
<\/script></body></html>\`;
  }
};
export { src_default as default };
INNER_EOF

npx wrangler deploy
echo "=== Deploy Enterprise Eseguito Correttamente ==="

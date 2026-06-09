#!/bin/bash
set -e

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
    } catch (e) {
      return defaultVal;
    }
  },

  async scheduled(event, env2, ctx) {
    if (!env2.SMR_DB || !env2.SMR_BUCKET) return;
    try {
      const list = await env2.SMR_DB.list();
      let backupData = {};
      for (const k of list.keys) {
        backupData[k.name] = await env2.SMR_DB.get(k.name);
      }
      await env2.SMR_BUCKET.put(
        `backup/db_backup_${(/* @__PURE__ */ new Date()).toISOString().split("T")[0]}.json`,
        JSON.stringify(backupData),
        { httpMetadata: { contentType: "application/json" } }
      );
    } catch (e) {
      console.error("Backup Error", e);
    }
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
      return new Response("SMR OS ACTIVE");
    } catch (err) {
      return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: CORS });
    }
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
      } catch (e) {
        console.error("Sync Error", e);
      }
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

  async saveLog(p, obj, env2, statusObj) {
    let chat = await this.getSafeJSON(env2, `chat_${p}`, []);
    if (typeof chat !== "object" || !Array.isArray(chat)) chat = [];
    if (obj.text && obj.text.startsWith("data:image") && obj.text.length > 1000) {
      obj.text = "[Immagine Elaborata dall'OCR del Sistema]";
    }
    chat.push(obj);
    await env2.SMR_DB.put(`chat_${p}`, JSON.stringify(chat.slice(-150)));
    let snap = await this.getSafeJSON(env2, "crm_snapshot", {});
    if (!snap[p]) snap[p] = {};
    snap[p].status = statusObj || await this.getSafeJSON(env2, `status_${p}`, {});
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
        let note = `📝 DATI ESTRATTI DALLA TARGHETTA:\n${aiData.choices[0].message.content}`;
        await this.saveLog(from, { from: "system", text: note, timestamp: Date.now() }, env2, st);
      }
    } catch (e) {
      console.error("OCR Failed", e);
    }
  },

  async handleUpload(request, env2) {
    try {
      const formData = await request.formData();
      const file = formData.get("file");
      if (!file) return new Response("Nessun file", { status: 400, headers: CORS });
      const ext = file.name.split(".").pop();
      const fileName = `smr_${Date.now()}_${Math.random().toString(36).substring(7)}.${ext}`;
      await env2.SMR_BUCKET.put(fileName, file.stream(), { httpMetadata: { contentType: file.type } });
      return new Response(JSON.stringify({ url: `/api/media/r2_${fileName}`, type: file.type, name: file.name, id: fileName }), { headers: CORS });
    } catch (e) {
      return new Response(JSON.stringify({ error: e.message }), { status: 500, headers: CORS });
    }
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
    } catch (e) {
      return new Response("Error", { status: 500, headers: CORS });
    }
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
    if (attachment) {
      msgText = text || "📎 Allegato Inviato";
      mediaId = attachment.id || attachment.url.split("/").pop();
      mediaType = attachment.type.includes("image") ? "image" : "document";
      fileName = attachment.name;
    }
    if (msgText) {
      await this.saveLog(channelId, { from: "user", text: msgText, mediaId, mediaType, fileName, timestamp: Date.now() }, env2, st);
    }
    if (mediaId) {
      st.manual = true;
      st.until = Date.now() + 864e5 * 2;
      st.tag = "VENDITA";
      await env2.SMR_DB.put(`status_${channelId}`, JSON.stringify(st));
      let reply = "Ho ricevuto il documento. Un nostro tecnico specializzato lo sta verificando e ti risponderà qui a breve.";
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
    let text = "";
    let mediaId = null;
    let mediaType = null;
    if (m.type === "text") {
      text = m.text.body;
    } else if (m.type === "interactive") {
      text = m.interactive?.button_reply?.title || m.interactive?.list_reply?.title || "";
    } else if (m.type === "image") {
      text = m.image.caption || "📷 Foto Ricevuta";
      mediaId = m.image.id;
      mediaType = "image";
    } else if (m.type === "document") {
      text = m.document.caption || "📄 Documento Ricevuto";
      mediaId = m.document.id;
      mediaType = "document";
    }
    if (!text && !mediaId) return;
    let st = await this.getSafeJSON(env2, `status_${from}`, { manual: false, resolved: false, tag: "NEUTRO" });
    st.name = name;
    st.channel = "whatsapp";
    st.resolved = false;
    st.lastUserInteraction = Date.now();
    await this.saveLog(from, { from: "user", text, mediaId, mediaType, timestamp: Date.now() }, env2, st);
    const history = await this.getSafeJSON(env2, `chat_${from}`, []);
    if (history.length <= 1 && !mediaId) {
      let welcomeMsg = {
        messaging_product: "whatsapp",
        recipient_type: "individual",
        to: from,
        type: "interactive",
        interactive: {
          type: "button",
          body: { text: "Benvenuto! Sono l'assistente IA di S.M. Ricambi.\n\nSeleziona un'opzione o scrivi il tuo problema:" },
          action: {
            buttons: [
              { type: "reply", reply: { id: "btn_ordini", title: "Stato Ordini" } },
              { type: "reply", reply: { id: "btn_compat", title: "Compatibilita" } },
              { type: "reply", reply: { id: "btn_assist", title: "Assistenza" } }
            ]
          }
        }
      };
      await fetch(`${WA_API}/${WA_PHONE_ID}/messages`, {
        method: "POST",
        headers: { "Authorization": `Bearer ${env2.WHATSAPP_TOKEN}`, "Content-Type": "application/json" },
        body: JSON.stringify(welcomeMsg)
      });
      await this.saveLog(from, { from: "bot", text: "Benvenuto! Sono l'assistente IA di S.M. Ricambi. [Inviati Pulsanti Scelta Rapida]", timestamp: Date.now() }, env2, st);
      return;
    }
    if (mediaId) {
      st.manual = true;
      st.until = Date.now() + 864e5 * 2;
      st.tag = "VENDITA";
      await env2.SMR_DB.put(`status_${from}`, JSON.stringify(st));
      let reply = "Ho ricevuto il documento. Passo subito la chat a un nostro operatore umano che verificherà tutto e ti risponderà qui a breve.";
      await fetch(`${WA_API}/${WA_PHONE_ID}/messages`, { method: "POST", headers: { "Authorization": `Bearer ${env2.WHATSAPP_TOKEN}`, "Content-Type": "application/json" }, body: JSON.stringify({ messaging_product: "whatsapp", to: from, text: { body: reply } }) });
      await this.saveLog(from, { from: "bot", text: reply, timestamp: Date.now() }, env2, st);
      ctx.waitUntil(this.processImageOCR(mediaId, mediaType, from, env2, st));
      return;
    }
    if (st.manual && st.until > Date.now()) {
      await env2.SMR_DB.put(`status_${from}`, JSON.stringify(st));
      return;
    }
    const aiData = await this.generateAI(text, env2, false, st);
    st.tag = aiData.tag;
    await env2.SMR_DB.put(`status_${from}`, JSON.stringify(st));
    
    const metaFormattedText = formatWhatsAppText(aiData.text);

    await fetch(`${WA_API}/${WA_PHONE_ID}/messages`, {
      method: "POST",
      headers: { "Authorization": `Bearer ${env2.WHATSAPP_TOKEN}`, "Content-Type": "application/json" },
      body: JSON.stringify({ messaging_product: "whatsapp", to: from, text: { body: metaFormattedText } })
    });
    await this.saveLog(from, { from: "bot", text: aiData.text, timestamp: Date.now() }, env2, st);
  },

  async generateAI(userText, env2, showBtns, st) {
    const emb = await env2.AI.run("@cf/baai/bge-base-en-v1.5", { text: [userText] });
    const matches = await env2.VECTORIZE_INDEX.query(emb.data[0], { topK: 5, returnMetadata: "all" });
    const context2 = matches.matches.filter((x) => x.score > 0.45).map((x) => x.metadata.text).join("\n\n");
    const sysPrompt = `Sei l'assistente IA ufficiale di S.M. Ricambi (smricambi.com).
REGOLE TASSATIVE:
1. NOI SIAMO S.M. Ricambi. Mai nominare concorrenti.
2. PROTOCOLLO TARGHETTA: Per identificare un ricambio, chiedi SEMPRE al cliente la 'targhetta identificativa interna della caldaia/scaldabagno con indicati modello completo e matricola'.
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
        tag = potentialTag;
        rawText = parts.slice(1).join("|").trim();
      }
    }
    return {
      text: rawText,
      tag,
      buttons: showBtns ? ["📦 Stato Ordini", "🔧 Compatibilità", "👨‍🔧 Assistenza"] : null
    };
  },

  async handleIngest(request, env2) {
    try {
      const body = await request.json();
      let type = body.type || "text";
      let content = body.content || body.text || "";
      let source = body.source || "SMR Vault";
      let textToMemorize = "";
      if (type === "text") {
        textToMemorize = content;
      } else if (type === "url") {
        const res = await fetch(content);
        if (!res.ok) throw new Error("Link inaccessibile");
        textToMemorize = (await res.text()).replace(/<[^>]+>/ig, " ").replace(/\s{2,}/g, " ").trim();
      } else if (type === "image") {
        const aiRes = await fetch("https://api.openai.com/v1/chat/completions", {
          method: "POST",
          headers: { "Authorization": `Bearer ${env2.OPENAI_API_KEY}`, "Content-Type": "application/json" },
          body: JSON.stringify({ model: "gpt-4o-mini", messages: [{ role: "user", content: [{ type: "text", text: "Estrai dati tecnici." }, { type: "image_url", image_url: { url: content } }] }], temperature: 0.1 })
        });
        const aiData = await aiRes.json();
        textToMemorize = aiData.choices[0].message.content;
      }
      if (!textToMemorize || textToMemorize.trim().length === 0) return new Response("Nessun dato", { status: 400, headers: CORS });
      const safeText = textToMemorize.substring(0, 1900);
      const kbId = `kb_${Date.now()}_${Math.random().toString(36).substring(7)}`;
      const emb = await env2.AI.run("@cf/baai/bge-base-en-v1.5", { text: [safeText] });
      await env2.VECTORIZE_INDEX.upsert([{ id: kbId, values: emb.data[0], metadata: { text: safeText, source } }]);
      await env2.SMR_DB.put(kbId, JSON.stringify({ text: safeText, type, source, timestamp: Date.now() }));
      return new Response(JSON.stringify({ ok: true, extracted: safeText }), { headers: CORS });
    } catch (e) {
      return new Response(JSON.stringify({ error: e.message }), { status: 500, headers: CORS });
    }
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
      if (template) {
        payload.type = "template";
        payload.template = { name: template, language: { code: "it" } };
      } else if (mediaUrl) {
        let directUrl = new URL(request.url).origin + mediaUrl;
        payload.type = mediaType.includes("image") ? "image" : "document";
        payload[payload.type] = { link: directUrl, caption: text || "" };
      } else {
        payload.type = "text";
        payload.text = { body: formatWhatsAppText(text) };
      }
      await fetch(`${WA_API}/${WA_PHONE_ID}/messages`, { method: "POST", headers: { "Authorization": `Bearer ${env2.WHATSAPP_TOKEN}`, "Content-Type": "application/json" }, body: JSON.stringify(payload) });
    }
    let logObj = { from: "admin", text, timestamp: Date.now() };
    if (mediaUrl) {
      logObj.mediaId = mediaUrl.split("/").pop().replace("r2_", "");
      logObj.mediaType = mediaType;
      logObj.fileName = fileName;
    }
    await this.saveLog(phone, logObj, env2, st);
    return new Response(JSON.stringify({ ok: true }), { headers: CORS });
  },

  async handleToggle(request, env2) {
    const { phone, manual } = await request.json();
    let st = await this.getSafeJSON(env2, `status_${phone}`, {});
    st.manual = manual;
    st.until = manual ? Date.now() + 864e5 * 2 : 0;
    st.resolved = false;
    await env2.SMR_DB.put(`status_${phone}`, JSON.stringify(st));
    let snap = await this.getSafeJSON(env2, "crm_snapshot", {});
    if (snap[phone]) {
      snap[phone].status = st;
      snap[phone].lastUpdate = Date.now();
    }
    await env2.SMR_DB.put("crm_snapshot", JSON.stringify(snap));
    await this.saveLog(phone, { from: "system", text: manual ? "L'operatore ha preso il controllo." : "Controllo ripassato all'Intelligenza Artificiale.", timestamp: Date.now() }, env2, st);
    return new Response(JSON.stringify({ ok: true }), { headers: CORS });
  },

  async handleResolve(request, env2) {
    const { phone } = await request.json();
    let st = await this.getSafeJSON(env2, `status_${phone}`, {});
    st.resolved = true;
    st.manual = false;
    st.until = 0;
    await env2.SMR_DB.put(`status_${phone}`, JSON.stringify(st));
    let snap = await this.getSafeJSON(env2, "crm_snapshot", {});
    if (snap[phone]) {
      snap[phone].status = st;
      snap[phone].lastUpdate = Date.now();
    }
    await env2.SMR_DB.put("crm_snapshot", JSON.stringify(snap));
    await this.saveLog(phone, { from: "system", text: "Conversazione risolta e archiviata.", timestamp: Date.now() }, env2, st);
    return new Response(JSON.stringify({ ok: true }), { headers: CORS });
  },

  async handleResetDB(env2) {
    const list = await env2.SMR_DB.list({ prefix: "chat_" });
    for (const k of list.keys) {
      await env2.SMR_DB.delete(k.name);
      await env2.SMR_DB.delete(k.name.replace("chat_", "status_"));
    }
    await env2.SMR_DB.delete("crm_snapshot");
    return new Response(JSON.stringify({ ok: true }), { headers: CORS });
  },

  async handleDelete(request, env2) {
    const { phone } = await request.json();
    await env2.SMR_DB.delete(`chat_${phone}`);
    await env2.SMR_DB.delete(`status_${phone}`);
    let snap = await this.getSafeJSON(env2, "crm_snapshot", {});
    delete snap[phone];
    await env2.SMR_DB.put("crm_snapshot", JSON.stringify(snap));
    return new Response(JSON.stringify({ ok: true }), { headers: CORS });
  },

  getAdminHTML() {
    return `<!DOCTYPE html>
<html lang="it">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>SMR OS - Enterprise Edition</title>
  <script src="https://cdn.tailwindcss.com"><\/script>
  <link href="https://fonts.googleapis.com/css2 family=Plus+Jakarta+Sans:wght@400;500;600;700&display=swap" rel="stylesheet">
  <style>
    body { font-family: 'Plus Jakarta Sans', sans-serif; background-color: #09090b; color: #f4f4f5; overflow: hidden; }
    ::-webkit-scrollbar { width: 4px; height: 4px; }
    ::-webkit-scrollbar-thumb { background: #27272a; border-radius: 10px; }
    .chat-item { transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1); border-left: 4px solid transparent; }
    .chat-item.active { background-color: #18181b; border-left-color: #2563eb; }
    .unread-wa { background-color: rgba(16, 185, 129, 0.05); border-left-color: #10b981; }
    .unread-web { background-color: rgba(37, 99, 235, 0.05); border-left-color: #2563eb; }
    .msg-bubble { max-width: 75%; padding: 12px 16px; border-radius: 16px; font-size: 14px; line-height: 1.5; }
    .msg-admin { background: #2563eb; color: #ffffff; border-bottom-right-radius: 4px; }
    .msg-user { background: #27272a; color: #f4f4f5; border-bottom-left-radius: 4px; }
    .msg-bot { background: rgba(37, 99, 235, 0.1); color: #60a5fa; border: 1px solid rgba(37, 99, 235, 0.2); border-bottom-left-radius: 4px; }
    .msg-system { background: #1c1917; color: #e7e5e4; border: 1px solid #2e2a24; border-radius: 12px; font-size: 13px; width: 100%; padding: 10px 14px; }
    .badge-vendita { background: rgba(16, 185, 129, 0.15); color: #34d399; border: 1px solid rgba(16, 185, 129, 0.3); }
    .badge-tecnico { background: rgba(239, 68, 68, 0.15); color: #f87171; border: 1px solid rgba(239, 68, 68, 0.3); }
    .badge-ordine { background: rgba(59, 130, 246, 0.15); color: #60a5fa; border: 1px solid rgba(59, 130, 246, 0.3); }
    .badge-neutro { background: #27272a; color: #a1a1aa; border: 1px solid #3f3f46; }
  </style>
</head>
<body class="h-screen w-screen flex flex-row overflow-hidden bg-[#09090b]">

  <aside class="w-[72px] h-full bg-[#121214] flex flex-col items-center py-6 gap-6 border-r border-[#222226] shrink-0">
    <div class="w-10 h-10 bg-blue-600 rounded-xl flex items-center justify-center text-white font-bold shadow-lg shadow-blue-600/20">SM</div>
    <div class="p-3 bg-blue-600/10 text-blue-500 rounded-xl cursor-pointer"><svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"></path></svg></div>
    <div class="p-3 text-zinc-500 hover:text-white rounded-xl cursor-pointer transition" onclick="showT()"><svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"></path><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"></path></svg></div>
    <div class="mt-auto p-3 text-zinc-500 hover:text-blue-500 cursor-pointer transition" onclick="forceSync()"><svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path></svg></div>
  </aside>

  <aside id="chatListContainer" class="w-[350px] h-full bg-[#121214] border-r border-[#222226] flex flex-col shrink-0 overflow-hidden">
    <div class="p-5 border-b border-[#222226]">
      <div class="flex justify-between items-center mb-4">
        <h2 class="font-bold text-xl tracking-tight text-white">Inbox Live</h2>
        <span class="bg-emerald-500/15 text-emerald-400 px-2 py-0.5 rounded text-xs font-semibold border border-emerald-500/30">Online</span>
      </div>
      <div class="flex bg-[#1c1c1f] p-1 rounded-lg mb-4">
        <button id="tabOpen" onclick="setTab(false)" class="flex-1 py-1.5 rounded-md text-sm font-semibold transition bg-blue-600 text-white shadow-sm">Attive</button>
        <button id="tabArchived" onclick="setTab(true)" class="flex-1 py-1.5 rounded-md text-sm font-semibold transition text-zinc-400 hover:text-white">Archiviate</button>
      </div>
      <input type="text" id="search" placeholder="Cerca cliente o telefono..." class="w-full text-sm bg-[#1c1c1f] px-4 py-2 rounded-lg border border-[#2d2d34] text-white outline-none focus:border-blue-500 transition" oninput="renderL()">
    </div>
    <div id="chatList" class="flex-1 overflow-y-auto"></div>
  </aside>

  <main id="chatAreaContainer" class="flex-1 h-full flex flex-col relative bg-[#09090b] min-w-0 overflow-hidden">
    <div id="empty" class="absolute inset-0 flex flex-col items-center justify-center text-zinc-600 bg-[#09090b] z-0">
      <svg class="w-12 h-12 mb-3 opacity-20" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"></path></svg>
      <p class="text-sm font-medium">Seleziona una chat per rispondere</p>
    </div>

    <header id="chatH" class="h-[76px] border-b border-[#222226] px-6 flex items-center justify-between hidden bg-[#121214] shrink-0 z-10">
      <div class="flex items-center gap-4 min-w-0">
        <button onclick="closeChatMobile()" class="md:hidden text-zinc-400 mr-2"><svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M15 19l-7-7 7-7"></path></svg></button>
        <div id="hAvatar" class="w-11 h-11 rounded-xl flex items-center justify-center font-bold text-white shadow-md"></div>
        <div class="min-w-0">
          <div class="flex items-center gap-2">
            <h3 id="hName" class="font-bold text-white text-base truncate"></h3>
            <span id="hTagBadge" class="text-[10px] font-bold px-2 py-0.5 rounded uppercase hidden md:inline-block"></span>
          </div>
        </div>
      </div>
      <div class="flex items-center gap-2 shrink-0">
        <button id="resolveBtn" onclick="resolveChat()" class="px-3 py-1.5 rounded-lg text-xs font-bold text-emerald-400 bg-emerald-500/10 hover:bg-emerald-500/20 border border-emerald-500/20 transition hidden">Risolvi</button>
        <button id="toggleBtn" onclick="toggleM()" class="px-4 py-1.5 rounded-lg text-xs font-bold border transition shadow-sm"></button>
        <button onclick="delChat()" class="p-2 text-zinc-500 hover:text-red-400 transition"><svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path></svg></button>
      </div>
    </header>

    <div id="msgA" class="flex-1 overflow-y-auto p-6 space-y-4 hidden bg-[#09090b]"></div>

    <div id="compWrapper" class="hidden flex-col border-t border-[#222226] bg-[#121214] p-4 shrink-0">
      <div id="waNotice" class="hidden bg-amber-500/10 border border-amber-500/20 px-4 py-2 rounded-lg text-xs text-amber-400 font-medium mb-3 items-center justify-between">
        <span>⚠️ Limite 24h WhatsApp superato:</span>
        <select id="waTemplateSelect" class="bg-[#1c1c1f] border border-amber-500/30 rounded px-2 py-1 text-white font-semibold outline-none">
          <option value="">Seleziona...</option>
          <option value="ordine_spedito">Ordine Spedito</option>
          <option value="ricambio_disponibile">Ricambio Disponibile</option>
        </select>
      </div>
      <div class="flex gap-2 overflow-x-auto pb-2 mb-2 border-b border-[#222226]">
        <button onclick="sendNote()" class="text-xs font-medium bg-amber-500/10 text-amber-400 border border-amber-500/20 px-3 py-1 rounded-full shrink-0">📝 Nota Interna</button>
        <button onclick="insertQuick('Per verificare la compatibilità mi serve una foto della targhetta della caldaia.')" class="text-xs font-medium bg-[#1c1c1f] text-zinc-400 border border-[#2d2d34] px-3 py-1 rounded-full shrink-0 hover:text-white transition">Richiedi Targhetta</button>
        <button onclick="insertQuick('Il ricambio è disponibile a magazzino. Se ordini ora spediamo in giornata.')" class="text-xs font-medium bg-[#1c1c1f] text-zinc-400 border border-[#2d2d34] px-3 py-1 rounded-full shrink-0 hover:text-white transition">Disponibilità Rapida</button>
      </div>
      <form id="comp" class="flex gap-3 items-end">
        <input type="file" id="adminFile" class="hidden" onchange="previewFile()">
        <button type="button" onclick="document.getElementById('adminFile').click()" class="p-3 bg-[#1c1c1f] border border-[#2d2d34] text-zinc-400 hover:text-white rounded-xl transition"><svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13"></path></svg></button>
        <div id="filePreview" class="hidden text-xs font-bold text-blue-400 bg-blue-500/10 border border-blue-500/20 px-3 py-2 rounded-lg truncate shrink-0 max-w-[120px]"></div>
        <textarea id="msgI" class="flex-1 bg-[#1c1c1f] border border-[#2d2d34] focus:border-blue-500 rounded-xl px-4 py-3 text-sm text-white outline-none resize-none" rows="1" style="min-height: 44px; max-height: 120px;" placeholder="Scrivi una risposta..."></textarea>
        <button type="submit" id="sendBtn" class="bg-blue-600 hover:bg-blue-700 text-white px-5 py-3 rounded-xl font-bold transition flex items-center justify-center text-sm">Invia</button>
      </form>
    </div>
  </main>

  <aside id="profileCard" class="w-[300px] h-full bg-[#121214] flex flex-col shrink-0 p-5 border-l border-[#222226] overflow-y-auto" style="display: none;">
    <h3 class="text-zinc-400 font-bold text-xs uppercase tracking-wider mb-4 border-b border-[#222226] pb-2">Anagrafica Lead</h3>
    <div class="space-y-4">
      <div><label class="text-[10px] text-zinc-500 font-semibold block uppercase">Nome Cliente</label><p id="pCardName" class="text-sm font-bold text-white mt-0.5">-</p></div>
      <div><label class="text-[10px] text-zinc-500 font-semibold block uppercase">Email Address</label><p id="pCardEmail" class="text-sm font-medium text-blue-400 break-all mt-0.5">-</p></div>
      <div><label class="text-[10px] text-zinc-500 font-semibold block uppercase">Contatto Cellulare</label><p id="pCardPhone" class="text-sm font-medium text-white mt-0.5">-</p></div>
      <div><label class="text-[10px] text-zinc-500 font-semibold block uppercase">Canale Origine</label><p id="pCardChannel" class="text-sm font-medium mt-0.5 uppercase">-</p></div>
      <div class="pt-2 border-t border-[#222226]"><label class="text-[10px] text-zinc-500 font-semibold block uppercase mb-1">Live Track Page</label><a id="pCardPage" href="#" target="_blank" class="text-xs text-blue-400 hover:underline block truncate">-</a></div>
    </div>
  </aside>

  <div id="tZone" class="hidden absolute inset-0 bg-black/60 backdrop-blur-md z-50 flex items-center justify-center p-4">
    <div class="bg-[#121214] border border-[#222226] rounded-2xl p-6 w-full max-w-2xl shadow-2xl">
      <div class="flex justify-between items-center mb-4">
        <div><h2 class="text-lg font-bold text-white">🧠 SMR Vault - Addestramento IA</h2></div>
        <button onclick="hideT()" class="text-zinc-500 hover:text-white bg-[#1c1c1f] p-1.5 rounded-full w-8 h-8 flex items-center justify-center">✕</button>
      </div>
      <div class="flex gap-4 border-b border-[#222226] mb-4 text-sm font-medium">
        <div id="t-tab-text" class="py-2 cursor-pointer border-b-2 border-blue-500 text-blue-500 font-bold" onclick="switchTrainTab('text')">Regole Testuali</div>
        <div id="t-tab-link" class="py-2 cursor-pointer border-b-2 border-transparent text-zinc-400 hover:text-white" onclick="switchTrainTab('link')">Analisi Link</div>
        <div id="t-tab-img" class="py-2 cursor-pointer border-b-2 border-transparent text-zinc-400 hover:text-white" onclick="switchTrainTab('img')">Lettura Immagini</div>
      </div>
      <div id="t-content-text" class="block"><textarea id="tText" class="w-full h-40 border border-[#2d2d34] bg-[#1c1c1f] p-4 rounded-xl text-white text-sm outline-none focus:border-blue-500 resize-none"></textarea></div>
      <div id="t-content-link" class="hidden"><input type="url" id="tLink" class="w-full border border-[#2d2d34] bg-[#1c1c1f] p-3 rounded-xl text-white text-sm outline-none"></div>
      <div id="t-content-img" class="hidden"><input type="file" id="tImgFile" accept="image/*" class="w-full border border-[#2d2d34] bg-[#1c1c1f] p-3 rounded-xl text-zinc-400 text-sm" onchange="previewTrainImage()"><img id="tImgPreview" class="mt-4 max-h-24 rounded-lg hidden border border-[#2d2d34]"><input type="hidden" id="tImgBase64"></div>
      <div class="mt-6 flex justify-end gap-3 text-sm">
        <button onclick="hideT()" class="px-4 py-2 font-semibold text-zinc-400 hover:text-white">Annulla</button>
        <button onclick="saveOmni()" id="tBtn" class="bg-blue-600 hover:bg-blue-700 text-white px-5 py-2 rounded-xl font-bold">Salva nel Vault</button>
      </div>
    </div>
  </div>

<script>
var curr=null, chats=[], currentManual=false, viewArchived=false;
let currentTrainType = 'text', isWhatsApp24hExpired = false, lastMessageCount = 0;

function escapeHTML(str) {
  if (!str) return '';
  return str.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#039;");
}

function playNotificationSound(type) {
    try {
        const audioCtx = new (window.AudioContext || window.webkitAudioContext)();
        const oscillator = audioCtx.createOscillator();
        const gainNode = audioCtx.createGain();
        oscillator.connect(gainNode); gainNode.connect(audioCtx.destination);
        if (type === 'urgent') {
            oscillator.type = 'sawtooth'; oscillator.frequency.setValueAtTime(880, audioCtx.currentTime);
            gainNode.gain.setValueAtTime(0.15, audioCtx.currentTime); oscillator.start(); oscillator.stop(audioCtx.currentTime + 0.15);
        } else {
            oscillator.type = 'sine'; oscillator.frequency.setValueAtTime(587.33, audioCtx.currentTime);
            gainNode.gain.setValueAtTime(0.1, audioCtx.currentTime); oscillator.start(); oscillator.stop(audioCtx.currentTime + 0.1);
        }
    } catch(e) {}
}

function handleTabNotification(incomingCount) {
    if (lastMessageCount > 0 && incomingCount > lastMessageCount) {
        playNotificationSound('normal');
        if (document.hidden) { document.title = "★ (1) NUOVO MESSAGGIO | SMR OS"; }
    }
    lastMessageCount = incomingCount;
}

window.addEventListener('focus', () => { document.title = "SMR OS - Enterprise Edition"; });

async function load(){ 
  try { 
    var r = await fetch('/api/chats'); if(!r.ok) return;
    var d = await r.json(); chats = Array.isArray(d) ? d : []; 
    let totalMsgs = chats.reduce((acc, c) => acc + (c.manual ? 1 : 0), 0);
    handleTabNotification(totalMsgs);
    renderL(); if(curr) fetchChatDetailAndRender(curr, true);
  } catch(e) {} 
}

async function forceSync() { try { await fetch('/api/chats?force=true'); location.reload(); } catch(e) {} }

async function fetchChatDetailAndRender(phone, silent = false) {
    try {
        var r = await fetch('/api/chat_detail?phone=' + phone); if(!r.ok) return;
        var msgs = await r.json(); var c = chats.find(x => x.phone === phone);
        if (c) { c.messages = msgs; renderM(phone); }
    } catch(e) {}
}

function renderL() { 
  try {
    var q = document.getElementById('search').value.toLowerCase();
    var filtered = chats.filter(c => {
        var nameMatch = (c.name || '').toLowerCase().includes(q);
        var phoneMatch = (c.phone || '').includes(q);
        var archiveMatch = !!c.resolved === viewArchived;
        return (nameMatch || phoneMatch) && archiveMatch;
    });
    var htmlContent = "";

    filtered.forEach(c => {
      var msgs = Array.isArray(c.messages) ? c.messages : [];
      var lastMsg = msgs.length ? msgs[msgs.length - 1] : null;
      var lastText = lastMsg ? (lastMsg.text || '📎 Allegato') : ''; 
      if (lastMsg && lastMsg.from === 'system') lastText = '⚙️ ' + lastText.substring(0, 30) + '...';
      else if (lastText.length > 35) lastText = lastText.substring(0, 35) + '...';

      var time = lastMsg && lastMsg.timestamp ? new Date(lastMsg.timestamp).toLocaleTimeString('it-IT', {hour: '2-digit', minute: '2-digit'}) : '';
      var storedReadTime = localStorage.getItem('read_' + c.phone) || 0;
      var isUnread = (lastMsg && lastMsg.from === 'user' && lastMsg.timestamp > storedReadTime && curr !== c.phone);
      
      var isWA = c.channel === 'whatsapp'; 
      var bgClass = isUnread ? (isWA ? 'unread-wa' : 'unread-web') : (curr === c.phone ? 'active' : ''); 
      var tagClass = 'badge-neutro'; var tagText = c.tag || 'NEUTRO';
      if(tagText === 'VENDITA') tagClass = 'badge-vendita'; else if(tagText === 'TECNICO' || tagText === 'URGENTE') tagClass = 'badge-tecnico'; else if(tagText === 'ORDINE') tagClass = 'badge-ordine';

      var avatarBg = isWA ? 'bg-emerald-600' : 'bg-blue-600';

      htmlContent += '<div onclick="openChatMobile(\'' + c.phone + '\')" class="chat-item p-4 border-b border-[#1c1c1f] cursor-pointer ' + bgClass + '">';
      htmlContent += '<div class="flex gap-4 items-center"><div class="relative"><div class="w-11 h-11 rounded-xl flex items-center justify-center text-white text-sm font-bold ' + avatarBg + '">' + (c.name||'?').charAt(0).toUpperCase() + '</div>' + (isUnread ? '<span class="absolute top-0 right-0 w-3 h-3 bg-red-500 rounded-full border-2 border-[#121214]"></span>' : '') + '</div>';
      htmlContent += '<div class="min-w-0 flex-1"><div class="flex justify-between items-center mb-0.5"><div class="font-semibold text-sm text-white truncate">' + (c.name||c.phone) + '</div><div class="text-xs text-zinc-500 shrink-0">' + time + '</div></div>';
      htmlContent += '<div class="text-xs truncate ' + (isUnread ? 'font-bold text-white' : 'text-zinc-400') + '">' + lastText + '</div>';
      htmlContent += '<div class="flex mt-2 items-center"><span class="text-[9px] px-2 py-0.5 rounded font-bold tracking-wide ' + tagClass + '">' + tagText + '</span>' + (c.manual ? '<span class="text-[9px] font-bold ml-2 px-1.5 py-0.5 rounded bg-zinc-800 text-zinc-300">👤 STAFF</span>' : '') + '</div></div></div></div>';
    });
    document.getElementById('chatList').innerHTML = htmlContent;
  } catch(e) {}
}

function renderM(p) { 
  try {
    var c = chats.find(x => x.phone === p); if(!c) return; 
    
    var msgA = document.getElementById('msgA');
    
    // CALCOLO DISTANZA DAL FONDO RESTRITTIVO (25 PIXEL DI TOLLERANZA LIVE)
    var distanceFromBottom = msgA.scrollHeight - msgA.scrollTop - msgA.clientHeight;
    var isAtBottom = distanceFromBottom < 25;
    var isInitialOpen = (window.lastOpenedPhone !== p);
    window.lastOpenedPhone = p;

    document.getElementById('empty').classList.add('hidden');
    document.getElementById('profileCard').style.display = 'flex';
    ['chatH','msgA','compWrapper'].forEach(id => document.getElementById(id).classList.remove('hidden'));
    
    if (c.messages && c.messages.length > 0) { localStorage.setItem('read_' + p, c.messages[c.messages.length-1].timestamp); renderL(); }

    document.getElementById('hAvatar').innerText = (c.name||'?').charAt(0).toUpperCase();
    document.getElementById('hAvatar').className = "w-11 h-11 rounded-xl flex items-center justify-center font-bold text-white shrink-0 " + (c.channel === 'web' ? 'bg-blue-600' : 'bg-emerald-600');
    document.getElementById('hName').innerText = c.name || c.phone;
    
    document.getElementById('pCardName').innerText = c.name || "Visitatore Anonimo";
    document.getElementById('pCardEmail').innerText = c.email || "Non inserita";
    document.getElementById('pCardPhone').innerText = c.cellulare || (c.channel === 'whatsapp' ? '+' + c.phone : "Non fornito");
    document.getElementById('pCardChannel').innerText = c.channel === 'web' ? "🖥️ SITO WEB WIDGET" : "🟢 WHATSAPP LIVE";
    
    var pageLink = document.getElementById('pCardPage');
    if (c.activePage) { pageLink.innerText = c.activePage; pageLink.href = c.activePage; } else { pageLink.innerText = "Nessuna traccia"; pageLink.href = "#"; }

    var hBadge = document.getElementById('hTagBadge'); var tagText = c.tag || 'NEUTRO';
    hBadge.innerText = tagText; hBadge.className = "text-[10px] font-bold px-2 py-0.5 rounded uppercase hidden md:block ";
    if (tagText === 'VENDITA') hBadge.classList.add('badge-vendita');
    else if (tagText === 'TECNICO' || tagText === 'URGENTE') hBadge.classList.add('badge-tecnico'); 
    else if (tagText === 'ORDINE') hBadge.classList.add('badge-ordine'); else hBadge.classList.add('badge-neutro');
    
    isWhatsApp24hExpired = false; var waNotice = document.getElementById('waNotice'); var msgInput = document.getElementById('msgI');
    if (c.channel === 'whatsapp' && c.lastUserInteraction) { if (Date.now() - c.lastUserInteraction > 86400000) isWhatsApp24hExpired = true; }
    if (isWhatsApp24hExpired) { waNotice.classList.remove('hidden'); waNotice.classList.add('flex'); msgInput.disabled = true; } 
    else { waNotice.classList.add('hidden'); waNotice.classList.remove('flex'); msgInput.disabled = false; }

    var tb = document.getElementById('toggleBtn'); var rb = document.getElementById('resolveBtn');
    if(c.manual) { 
      tb.innerHTML = "🤖 Attiva Bot";
      tb.className = "px-3 py-1.5 rounded-lg text-xs font-bold text-zinc-300 bg-zinc-800 hover:bg-zinc-700 border border-[#2d2d34]"; rb.classList.remove('hidden');
    } else { 
      tb.innerHTML = "👤 Prendi Controllo";
      tb.className = "px-3 py-1.5 rounded-lg text-xs font-bold text-white bg-blue-600 hover:bg-blue-700"; rb.classList.add('hidden');
    }

    var html = ''; var msgs = Array.isArray(c.messages) ? c.messages : []; var lastDate = '';
    msgs.forEach(m => { 
      var dObj = m.timestamp ? new Date(m.timestamp) : new Date();
      var dateStr = dObj.toLocaleDateString('it-IT', {weekday:'long', day:'numeric', month:'long'});
      if (dateStr !== lastDate) { html += '<div class="flex justify-center my-4"><span class="bg-[#1c1c1f] text-zinc-500 text-[10px] px-3 py-1 rounded-full font-bold uppercase tracking-wide border border-[#2d2d34]">'+dateStr+'</span></div>'; lastDate = dateStr; }
      if (m.from === 'system') { html += '<div class="flex justify-center mb-3 w-full"><div class="msg-system break-words">'+escapeHTML(m.text)+'</div></div>'; return; }
      var isRight = m.from === 'admin'; var bubbleClass = isRight ? 'msg-admin' : (m.from === 'bot' ? 'msg-bot' : 'msg-user');
      var sender = isRight ? 'Tu' : (m.from === 'bot' ? 'IA AUTOMATION' : (c.name || 'Cliente'));
      var mediaHtml = '';
      if (m.mediaId) {
        if (m.mediaType === 'image') { mediaHtml = '<a href="/api/media/' + m.mediaId + '" target="_blank"><img src="/api/media/' + m.mediaId + '" class="max-w-xs rounded-xl mb-2 border border-[#2d2d34]"></a>'; } 
        else { mediaHtml = '<a href="/api/media/' + m.mediaId + '" target="_blank" class="flex items-center gap-2 bg-[#1c1c1f] p-3 rounded-lg text-xs mb-2 font-bold text-blue-400 border border-[#2d2d34]">📎 '+escapeHTML(m.fileName||'Documento')+'</a>'; }
      }
      html += '<div class="flex flex-col '+(isRight ? 'items-end' : 'items-start')+' mb-2 w-full"><span class="text-[10px] text-zinc-500 mb-1 px-1">'+sender+' · '+dObj.toLocaleTimeString('it-IT', {hour:'2-digit', minute:'2-digit'})+'</span><div class="msg-bubble '+bubbleClass+'">'+mediaHtml+'<div class="whitespace-pre-wrap">'+escapeHTML(m.text||'')+'</div></div></div>';
    }); 
    
    msgA.innerHTML = html; 
    
    if (isAtBottom || isInitialOpen) {
      msgA.scrollTop = msgA.scrollHeight;
    }
  } catch(e) {}
}

function openChatMobile(phone) { curr = phone; document.body.classList.add('mobile-view-chat'); document.getElementById('chatAreaContainer').classList.remove('mobile-hide'); fetchChatDetailAndRender(phone); }
function closeChatMobile() { curr = null; document.getElementById('chatAreaContainer').classList.add('mobile-hide'); document.getElementById('empty').classList.remove('hidden'); document.getElementById('profileCard').style.display = 'none'; ['chatH','msgA','compWrapper'].forEach(id => document.getElementById(id).classList.add('hidden')); }
function showT() { document.getElementById('tZone').classList.remove('hidden'); }
function hideT() { document.getElementById('tZone').classList.add('hidden'); }
function switchTrainTab(type) { currentTrainType = type; document.querySelectorAll('.t-tab').forEach(el => el.classList.remove('border-blue-500', 'text-blue-500', 'font-bold')); document.querySelectorAll('.t-content').forEach(el => el.classList.add('hidden')); document.getElementById('t-tab-'+type).classList.add('border-blue-500', 'text-blue-500', 'font-bold'); document.getElementById('t-content-'+type).classList.remove('hidden'); }
function previewTrainImage() { const file = document.getElementById('tImgFile').files[0]; if (file) { const reader = new FileReader(); reader.onload = function(e) { document.getElementById('tImgPreview').src = e.target.result; document.getElementById('tImgPreview').classList.remove('hidden'); document.getElementById('tImgBase64').value = e.target.result; }; reader.readAsDataURL(file); } }

async function saveOmni() {
    const btn = document.getElementById('tBtn'); let payload = { source: "SMR Vault Admin" };
    if (currentTrainType === 'text') { payload.type = 'text'; payload.content = document.getElementById('tText').value.trim(); if(!payload.content) return; } 
    else if (currentTrainType === 'link') { payload.type = 'url'; payload.content = document.getElementById('tLink').value.trim(); if(!payload.content) return; } 
    else if (currentTrainType === 'img') { payload.type = 'image'; payload.content = document.getElementById('tImgBase64').value; if(!payload.content) return; }
    btn.innerText = "Sincronizzazione..."; btn.disabled = true;
    try { const res = await fetch('/api/ingest', { method: 'POST', body: JSON.stringify(payload) }); if (res.ok) { document.getElementById('tText').value = ''; document.getElementById('tLink').value = ''; document.getElementById('tImgFile').value = ''; document.getElementById('tImgPreview').classList.add('hidden'); hideT(); } } catch(e) {} finally { btn.innerText = "Salva nel Vault"; btn.disabled = false; }
}

async function delChat(){ if (confirm("Eliminare definitivamente la chat?")) { await fetch('/api/delete', {method: 'POST', body: JSON.stringify({phone: curr})}); curr = null; location.reload(); } }
async function toggleM(){ await fetch('/api/toggle', {method: 'POST', body: JSON.stringify({phone: curr, manual: !currentManual})}); load(); }
async function resolveChat(){ await fetch('/api/resolve', {method: 'POST', body: JSON.stringify({phone: curr})}); if (window.innerWidth < 768) closeChatMobile(); else { curr = null; location.reload(); } }
function insertQuick(txt) { document.getElementById('msgI').value = txt; document.getElementById('msgI').focus(); }
function setTab(archived) { viewArchived = archived; document.getElementById('tabOpen').className = archived ? 'flex-1 py-1.5 text-center text-sm font-semibold text-zinc-400' : 'flex-1 py-1.5 text-center text-sm font-semibold bg-blue-600 text-white rounded-md shadow-sm'; document.getElementById('tabArchived').className = archived ? 'flex-1 py-1.5 text-center text-sm font-semibold bg-blue-600 text-white rounded-md shadow-sm' : 'flex-1 py-1.5 text-center text-sm font-semibold text-zinc-400'; renderL(); }
function previewFile() { const file = document.getElementById('adminFile').files[0]; const pv = document.getElementById('filePreview'); if (file) { pv.innerText = file.name; pv.classList.remove('hidden'); } else { pv.classList.add('hidden'); } }
async function sendNote() { var t = prompt("Inserisci nota interna nascosta:"); if (!t || !curr) return; await fetch('/api/reply', {method: 'POST', body: JSON.stringify({phone: curr, text: t, isNote: true})}); load(); }

document.getElementById('msgI').addEventListener('input', function() { this.style.height = '44px'; this.style.height = (this.scrollHeight) + 'px'; });

document.getElementById('comp').onsubmit = async(e) => { 
  e.preventDefault(); var i = document.getElementById('msgI'); var btn = document.getElementById('sendBtn'); var f = document.getElementById('adminFile').files[0]; var t = i.value.trim();
  let payload = { phone: curr, text: t };
  if (isWhatsApp24hExpired) { let tpl = document.getElementById('waTemplateSelect').value; if (!tpl) return alert("Scegli un template."); payload.template = tpl; } else { if (!t && !f) return; }
  if (!curr) return; i.disabled = true; btn.disabled = true;
  try {
    if (f && !isWhatsApp24hExpired) {
      const fd = new FormData(); fd.append("file", f);
      const res = await fetch('/api/upload', { method: 'POST', body: fd }); const data = await res.json();
      payload.mediaUrl = data.url; payload.mediaType = data.type; payload.fileName = data.name;
      document.getElementById('adminFile').value = ""; document.getElementById('filePreview').classList.add('hidden');
    }
    await fetch('/api/reply', { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify(payload) }); 
  } catch(err) {}
  i.value = ''; i.style.height = '44px'; i.disabled = false; btn.disabled = false; i.focus(); load(); 
};

document.getElementById('msgI').addEventListener('keydown', function(e) { if (e.key === 'Enter' && !e.shiftKey) { if (window.innerWidth > 768) { e.preventDefault(); document.getElementById('comp').dispatchEvent(new Event('submit')); } } });
setInterval(load, 3500); load();
<\/script></body></html>`;
  }
};
export {
  src_default as default
};
INNER_EOF

npx wrangler deploy
echo "=== Backend Cleaned ed Eseguito ==="

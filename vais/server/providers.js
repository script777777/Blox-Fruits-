import { resolveChatModel } from './models.js';

function flattenContent(content) {
  if (typeof content === 'string') return content;
  if (!Array.isArray(content)) return String(content ?? '');
  const texts = [];
  for (const part of content) {
    if (typeof part === 'string') texts.push(part);
    else if (part?.type === 'text') texts.push(part.text || '');
    else if (part?.type === 'image_url') texts.push('[image]');
  }
  return texts.join('\n');
}

function toOpenAIMessages(messages, system) {
  const out = [];
  if (system) out.push({ role: 'system', content: system });
  for (const m of messages || []) {
    out.push({
      role: m.role === 'assistant' ? 'assistant' : 'user',
      content: m.content,
    });
  }
  return out;
}

async function* parseOpenAIStream(res) {
  if (!res.ok) {
    const text = await res.text().catch(() => '');
    throw new Error(text.slice(0, 200) || `Provider error ${res.status}`);
  }
  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    let idx;
    while ((idx = buffer.indexOf('\n')) !== -1) {
      let line = buffer.slice(0, idx);
      buffer = buffer.slice(idx + 1);
      line = line.trim();
      if (!line || line.startsWith(':')) continue;
      if (line === 'data: [DONE]') return;
      if (!line.startsWith('data:')) continue;
      let payload;
      try {
        payload = JSON.parse(line.slice(5).trim());
      } catch {
        continue;
      }
      const choice = payload.choices?.[0];
      const delta = choice?.delta || {};
      if (delta.reasoning_content) yield { r: delta.reasoning_content };
      if (delta.reasoning) yield { r: delta.reasoning };
      if (delta.content) yield { t: delta.content };
    }
  }
}

export async function* streamGroq({ model, messages, system, signal }) {
  const key = process.env.GROQ_API_KEY;
  if (!key) throw new Error('GROQ_API_KEY fehlt.');
  const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${key}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model,
      messages: toOpenAIMessages(messages, system),
      stream: true,
      temperature: 0.7,
    }),
    signal,
  });
  yield* parseOpenAIStream(res);
}

export async function* streamOpenRouter({ model, messages, system, signal }) {
  const key = process.env.OPENROUTER_API_KEY;
  if (!key) throw new Error('OPENROUTER_API_KEY fehlt.');
  const res = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${key}`,
      'Content-Type': 'application/json',
      'HTTP-Referer': process.env.PUBLIC_URL || 'http://localhost:3000',
      'X-Title': 'VAIs',
    },
    body: JSON.stringify({
      model,
      messages: toOpenAIMessages(messages, system),
      stream: true,
    }),
    signal,
  });
  yield* parseOpenAIStream(res);
}

export async function generatePollinationsImage(prompt) {
  const model = 'flux';
  const seed = Math.floor(Math.random() * 1e9);
  const referrer = encodeURIComponent(process.env.POLLINATIONS_REFERRER || 'vais');
  const url = `https://image.pollinations.ai/prompt/${encodeURIComponent(prompt)}?model=${model}&seed=${seed}&nologo=true&referrer=${referrer}`;
  // Return URL directly – frontend displays remote images (CSP allows https: img)
  return { url, alt: prompt.slice(0, 120) };
}

export function buildSystemPrompt({ mode, modality, profile, memories }) {
  const parts = [
    'You are a helpful AI assistant inside VAIs, a free multi-model chat app.',
    'Answer clearly in the user\'s language. Use Markdown when useful.',
  ];
  if (mode === 'agent' || mode === 'life') {
    parts.push('You are Agent X: proactive, tool-minded, and thorough. Prefer concrete steps.');
  }
  if (modality === 'code') parts.push('Focus on correct, runnable code with brief explanations.');
  if (modality === 'web') parts.push('If you lack live web access, say so and give the best answer from training knowledge.');
  if (profile?.instructions) parts.push(`User instructions:\n${profile.instructions}`);
  if (memories?.length) {
    parts.push('Things to remember about the user:\n' + memories.map((m) => `- ${m.text}`).join('\n'));
  }
  return parts.join('\n\n');
}

export async function* streamModel({ modelId, modality, messages, system, signal }) {
  const m = resolveChatModel(modelId, modality);
  if (!m) throw new Error('Kein Modell verfügbar. Trage GROQ_API_KEY oder OPENROUTER_API_KEY ein.');

  if (modality === 'image' || m._provider === 'pollinations') {
    const prompt = flattenContent(messages?.at(-1)?.content || '');
    yield { step: { label: 'Bild wird erzeugt …' } };
    const image = await generatePollinationsImage(prompt);
    yield { image };
    yield { done: true };
    return;
  }

  if (m._provider === 'openrouter' || (!process.env.GROQ_API_KEY && process.env.OPENROUTER_API_KEY)) {
    const model = m._openrouterModel || m.id.replace(/^openrouter\//, '') || 'openrouter/auto';
    yield* streamOpenRouter({ model, messages, system, signal });
    yield { done: true };
    return;
  }

  if (!process.env.GROQ_API_KEY && !process.env.OPENROUTER_API_KEY) {
    // Demo fallback so the UI can be tested without keys
    const last = flattenContent(messages?.at(-1)?.content || '');
    const reply = `**(Demo-Modus)** Kein API-Schlüssel gesetzt.\n\nDeine Nachricht war:\n\n> ${last.slice(0, 500)}\n\nTrage \`GROQ_API_KEY\` oder \`OPENROUTER_API_KEY\` in \`.env\` ein, dann antworten echte Modelle.`;
    for (const chunk of reply.match(/.{1,24}/gs) || []) {
      yield { t: chunk };
      await new Promise((r) => setTimeout(r, 12));
    }
    yield { done: true };
    return;
  }

  const groqModel = m._groqModel || 'openai/gpt-oss-20b';
  yield* streamGroq({ model: groqModel, messages, system, signal });
  yield { done: true };
}

export async function improveText(text) {
  const messages = [
    { role: 'user', content: `Improve this user prompt. Return only the improved prompt, same language:\n\n${text}` },
  ];
  let out = '';
  for await (const msg of streamModel({
    modelId: 'vais/auto',
    modality: 'text',
    messages,
    system: 'You rewrite prompts to be clearer and more specific. Output only the rewritten prompt.',
  })) {
    if (msg.t) out += msg.t;
  }
  return out.trim() || text;
}

export async function translateText(text, from, to) {
  const messages = [
    { role: 'user', content: `Translate from ${from || 'auto'} to ${to}. Return only the translation:\n\n${text}` },
  ];
  let out = '';
  for await (const msg of streamModel({
    modelId: 'vais/auto',
    modality: 'text',
    messages,
    system: 'You are a precise translator. Output only the translation.',
  })) {
    if (msg.t) out += msg.t;
  }
  return out.trim() || text;
}

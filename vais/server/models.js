/** Model catalog matching the live VAIs status page + Agent X / Auto. */

const BASE = [
  {
    id: 'openai/gpt-oss-120b',
    name: 'gpt-oss-120b',
    maker: 'OpenAI',
    icon: 'openai',
    provider: 'groq',
    groqModel: 'openai/gpt-oss-120b',
    caps: ['text', 'code', 'vision'],
  },
  {
    id: 'openai/gpt-oss-120b-search',
    name: 'gpt-oss-120b-search',
    maker: 'OpenAI',
    icon: 'openai',
    provider: 'groq',
    groqModel: 'openai/gpt-oss-120b',
    caps: ['text', 'code', 'web', 'vision'],
    search: true,
  },
  {
    id: 'openai/gpt-oss-20b',
    name: 'gpt-oss-20b',
    maker: 'OpenAI',
    icon: 'openai',
    provider: 'groq',
    groqModel: 'openai/gpt-oss-20b',
    caps: ['text', 'code'],
  },
  {
    id: 'openai/gpt-oss-20b-search',
    name: 'gpt-oss-20b-search',
    maker: 'OpenAI',
    icon: 'openai',
    provider: 'groq',
    groqModel: 'openai/gpt-oss-20b',
    caps: ['text', 'code', 'web'],
    search: true,
  },
  {
    id: 'qwen/qwen3-32b',
    name: 'qwen3.8-27b',
    maker: 'Qwen',
    icon: 'qwen-color',
    provider: 'groq',
    groqModel: 'qwen/qwen3-32b',
    caps: ['text', 'code'],
  },
  {
    id: 'pollinations/sana',
    name: 'Sana',
    maker: 'NVIDIA',
    icon: 'nvidia-color',
    provider: 'pollinations',
    pollinationsModel: 'flux',
    caps: ['image'],
  },
  {
    id: 'vais/auto',
    name: 'Auto',
    maker: 'VAIs',
    icon: 'vais',
    provider: 'auto',
    caps: ['text', 'code', 'web', 'vision'],
    auto: true,
  },
  {
    id: 'vais/agent-x',
    name: 'Agent X',
    maker: 'VAIs',
    icon: 'vais',
    provider: 'agent',
    caps: ['text', 'code', 'web', 'vision', 'image'],
    agent: true,
  },
];

/** OpenRouter extras when OPENROUTER_API_KEY is set */
const OPENROUTER_EXTRAS = [
  {
    id: 'openrouter/auto',
    name: 'OpenRouter Auto',
    maker: 'OpenRouter',
    icon: 'openai',
    provider: 'openrouter',
    openrouterModel: 'openrouter/auto',
    caps: ['text', 'code', 'vision'],
    paid: true,
  },
];

export function listModels() {
  const groq = !!process.env.GROQ_API_KEY;
  const openrouter = !!process.env.OPENROUTER_API_KEY;
  const models = BASE.map((m) => {
    let busy = false;
    if (m.provider === 'groq' && !groq) busy = true;
    if (m.provider === 'openrouter' && !openrouter) busy = true;
    if ((m.provider === 'auto' || m.provider === 'agent') && !groq && !openrouter) busy = true;
    return { ...m, busy };
  });
  if (openrouter) {
    for (const m of OPENROUTER_EXTRAS) models.push({ ...m, busy: false });
  }
  return models.map(({ groqModel, openrouterModel, pollinationsModel, search, provider, ...pub }) => ({
    ...pub,
    // keep provider privately via byId
  })).map((m) => {
    const full = BASE.find((b) => b.id === m.id) || OPENROUTER_EXTRAS.find((b) => b.id === m.id);
    return {
      id: m.id,
      name: m.name,
      maker: m.maker,
      icon: m.icon,
      caps: m.caps,
      busy: m.busy,
      paid: !!m.paid,
      auto: !!m.auto,
      agent: !!m.agent,
      _provider: full?.provider,
      _groqModel: full?.groqModel,
      _openrouterModel: full?.openrouterModel,
      _pollinationsModel: full?.pollinationsModel,
      _search: !!full?.search,
    };
  });
}

export function publicModels() {
  return listModels().map(({ _provider, _groqModel, _openrouterModel, _pollinationsModel, _search, ...m }) => m);
}

export function modelById(id) {
  return listModels().find((m) => m.id === id) || null;
}

export function pickForMode(mode, modality, requested = []) {
  const all = listModels().filter((m) => !m.busy);
  const textish = all.filter((m) => m.caps.includes('text') && !m.agent && !m.auto);
  const images = all.filter((m) => m.caps.includes('image') && !m.agent);
  const agent = all.find((m) => m.agent);
  const auto = all.find((m) => m.auto);

  if (mode === 'agent' || mode === 'life') {
    return {
      ids: [agent?.id || textish[0]?.id].filter(Boolean),
      labels: ['Agent X'],
    };
  }

  if (modality === 'image') {
    const id = requested[0] && modelById(requested[0])?.caps.includes('image')
      ? requested[0]
      : images[0]?.id;
    const m = modelById(id);
    return { ids: [id].filter(Boolean), labels: [m?.name || 'Image'] };
  }

  if (mode === 'direct') {
    let id = requested[0];
    if (!id || !modelById(id)) id = (modality === 'auto' ? auto?.id : null) || textish[0]?.id;
    const m = modelById(id);
    return { ids: [id].filter(Boolean), labels: [m?.auto ? 'Auto' : (m?.name || 'Model')] };
  }

  if (mode === 'sxs') {
    const ids = [
      requested[0] && modelById(requested[0]) ? requested[0] : textish[0]?.id,
      requested[1] && modelById(requested[1]) ? requested[1] : textish[1]?.id || textish[0]?.id,
    ].filter(Boolean);
    while (ids.length < 2 && textish.length) ids.push(textish[ids.length % textish.length].id);
    return {
      ids,
      labels: ids.map((id) => modelById(id)?.name || 'Model'),
    };
  }

  // battle – two random anonymous models
  const pool = [...textish].sort(() => Math.random() - 0.5);
  const ids = pool.slice(0, 2).map((m) => m.id);
  while (ids.length < 2 && textish[0]) ids.push(textish[0].id);
  return {
    ids,
    labels: ['Assistent A', 'Assistent B'],
    reveal: ids.map((id) => modelById(id)?.name || 'Model'),
  };
}

export function statusPayload() {
  const models = listModels().filter((m) => !m.agent && !m.auto);
  const byProv = new Map();
  for (const m of models) {
    const key = m._provider || 'other';
    if (!byProv.has(key)) byProv.set(key, []);
    byProv.get(key).push(m);
  }
  const labels = {
    groq: 'Groq',
    pollinations: 'Pollinations (Bilder)',
    openrouter: 'OpenRouter',
    other: 'Other',
  };
  const providers = [...byProv.entries()].map(([provider, list]) => ({
    provider,
    label: labels[provider] || provider,
    free: list.filter((m) => !m.busy).length,
    total: list.length,
    models: list.map((m) => ({ name: m.name, maker: m.maker, busy: !!m.busy })),
  }));
  const free = models.filter((m) => !m.busy).length;
  return {
    state: free ? 'ok' : 'degraded',
    maintenance: null,
    free,
    total: models.length,
    demo: !process.env.GROQ_API_KEY && !process.env.OPENROUTER_API_KEY,
    providers,
    last24h: { answers: 0, errors: 0, successRate: 100 },
    telegram: { on: false, webhook: false },
    checkedAt: new Date().toISOString(),
  };
}

export function resolveChatModel(modelId, modality) {
  let m = modelById(modelId);
  if (!m || m.auto || m.agent) {
    const all = listModels().filter((x) => !x.busy && !x.agent && !x.auto);
    if (modality === 'image') m = all.find((x) => x.caps.includes('image')) || m;
    else if (modality === 'web') m = all.find((x) => x.caps.includes('web')) || all.find((x) => x.caps.includes('text'));
    else m = all.find((x) => x.caps.includes('text')) || m;
  }
  return m;
}

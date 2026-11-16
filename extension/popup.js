const apiKeyInput = document.getElementById("apiKey");
const urlInput = document.getElementById("url");
const pasteBtn = document.getElementById("pasteBtn");
const bypassBtn = document.getElementById("bypassBtn");
const statusEl = document.getElementById("status");
const openResult = document.getElementById("openResult");

function setStatus(text, kind) {
  statusEl.hidden = !text;
  statusEl.textContent = text || "";
  statusEl.className = `status${kind ? ` ${kind}` : ""}`;
}

chrome.storage.local.get(["apiKey", "lastResult"], (data) => {
  if (data.apiKey) apiKeyInput.value = data.apiKey;
  if (data.lastResult) {
    openResult.hidden = false;
    openResult.href = data.lastResult;
    openResult.textContent = data.lastResult;
  }
});

apiKeyInput.addEventListener("change", () => {
  chrome.storage.local.set({ apiKey: apiKeyInput.value.trim() });
});

apiKeyInput.addEventListener("blur", () => {
  chrome.storage.local.set({ apiKey: apiKeyInput.value.trim() });
});

pasteBtn.addEventListener("click", async () => {
  try {
    const text = await navigator.clipboard.readText();
    const match = text.trim().match(/https?:\/\/[^\s<>"'`]+/i);
    urlInput.value = match ? match[0] : text.trim();
  } catch {
    setStatus("Clipboard access denied.", "error");
  }
});

bypassBtn.addEventListener("click", async () => {
  const apiKey = apiKeyInput.value.trim();
  const url = urlInput.value.trim();
  chrome.storage.local.set({ apiKey });

  if (!apiKey) {
    setStatus("Add your Void Syndicate API key first.", "error");
    return;
  }
  if (!url) {
    setStatus("Paste a link to bypass.", "error");
    return;
  }

  setStatus("Bypassing…", "busy");
  openResult.hidden = true;
  bypassBtn.disabled = true;

  chrome.runtime.sendMessage({ type: "BYPASS_URL", url }, async (result) => {
    bypassBtn.disabled = false;
    if (chrome.runtime.lastError) {
      setStatus(chrome.runtime.lastError.message, "error");
      return;
    }
    if (!result?.ok) {
      setStatus(result?.error || "Bypass failed", "error");
      return;
    }

    setStatus("Copied · opening result", "ok");
    openResult.hidden = false;
    openResult.href = result.destination;
    openResult.textContent = result.destination;
    try {
      await navigator.clipboard.writeText(result.destination);
    } catch {
      // ignore
    }
    chrome.storage.local.set({ lastResult: result.destination, lastSource: url });
  });
});

const API_BASE = "https://void-syndicate-954.netlify.app";
const MENU_LINK = "void-bypass-link";
const MENU_PAGE = "void-bypass-page";
const MENU_SELECTION = "void-bypass-selection";

chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.removeAll(() => {
    chrome.contextMenus.create({
      id: MENU_LINK,
      title: "Bypass with Void Syndicate",
      contexts: ["link"],
    });
    chrome.contextMenus.create({
      id: MENU_PAGE,
      title: "Bypass this page (Void Syndicate)",
      contexts: ["page"],
    });
    chrome.contextMenus.create({
      id: MENU_SELECTION,
      title: "Bypass selected URL (Void Syndicate)",
      contexts: ["selection"],
    });
  });
});

chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  let target = "";
  if (info.menuItemId === MENU_LINK) target = info.linkUrl || "";
  else if (info.menuItemId === MENU_PAGE) target = info.pageUrl || tab?.url || "";
  else if (info.menuItemId === MENU_SELECTION) {
    const raw = (info.selectionText || "").trim();
    const match = raw.match(/https?:\/\/[^\s<>"'`]+/i);
    target = match ? match[0] : raw;
  }

  if (!target) {
    await notify(tab?.id, "No URL found.");
    return;
  }

  const result = await runBypass(target);
  if (!result.ok) {
    await notify(tab?.id, result.error);
    return;
  }

  await chrome.storage.local.set({ lastResult: result.destination, lastSource: target });
  if (tab?.id != null) {
    try {
      await chrome.tabs.update(tab.id, { url: result.destination });
    } catch {
      await notify(tab.id, result.destination);
    }
  }
});

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message?.type === "BYPASS_URL") {
    runBypass(message.url)
      .then((result) => sendResponse(result))
      .catch((err) =>
        sendResponse({
          ok: false,
          error: err instanceof Error ? err.message : "Bypass failed",
        }),
      );
    return true;
  }
  return false;
});

async function getApiKey() {
  const data = await chrome.storage.local.get(["apiKey"]);
  return (data.apiKey || "").trim();
}

async function runBypass(url) {
  const apiKey = await getApiKey();
  if (!apiKey) {
    return {
      ok: false,
      error: "Set your Void Syndicate API key in the extension popup first.",
    };
  }

  try {
    const endpoint = new URL("/api/v1/bypass", API_BASE);
    endpoint.searchParams.set("url", url);
    const response = await fetch(endpoint.toString(), {
      method: "GET",
      headers: {
        Accept: "application/json",
        "x-api-key": apiKey,
      },
    });
    const payload = await response.json().catch(() => null);
    if (!response.ok || !payload || payload.status !== "success") {
      const msg =
        (payload && (payload.result || payload.error)) ||
        `API error (${response.status})`;
      return { ok: false, error: String(msg) };
    }
    return { ok: true, destination: String(payload.result) };
  } catch (err) {
    return {
      ok: false,
      error: err instanceof Error ? err.message : "Network error",
    };
  }
}

async function notify(tabId, text) {
  if (tabId == null) return;
  try {
    await chrome.tabs.sendMessage(tabId, { type: "VOID_TOAST", text: String(text) });
  } catch {
    // content script may be missing on this page
  }
}

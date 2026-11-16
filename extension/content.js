(function () {
  if (window.__voidSyndicateLoaded) return;
  window.__voidSyndicateLoaded = true;

  const bar = document.createElement("div");
  bar.className = "void-syndicate-bar";
  bar.innerHTML = `
    <span class="void-syndicate-mark" aria-hidden="true">⚡</span>
    <span class="void-syndicate-label">Void Syndicate</span>
    <button type="button" class="void-syndicate-btn" id="voidSyndicateBypass">Bypass →</button>
  `;
  document.documentElement.appendChild(bar);

  const toast = document.createElement("div");
  toast.className = "void-syndicate-toast";
  toast.hidden = true;
  document.documentElement.appendChild(toast);

  function showToast(text, isError) {
    toast.hidden = false;
    toast.textContent = text;
    toast.classList.toggle("error", Boolean(isError));
    window.clearTimeout(showToast._t);
    showToast._t = window.setTimeout(() => {
      toast.hidden = true;
    }, 3200);
  }

  document.getElementById("voidSyndicateBypass")?.addEventListener("click", () => {
    const btn = document.getElementById("voidSyndicateBypass");
    if (btn) {
      btn.disabled = true;
      btn.textContent = "…";
    }
    chrome.runtime.sendMessage({ type: "BYPASS_URL", url: location.href }, (result) => {
      if (btn) {
        btn.disabled = false;
        btn.textContent = "Bypass →";
      }
      if (chrome.runtime.lastError) {
        showToast(chrome.runtime.lastError.message, true);
        return;
      }
      if (!result?.ok) {
        showToast(result?.error || "Bypass failed", true);
        return;
      }
      showToast("Redirecting…");
      location.href = result.destination;
    });
  });

  chrome.runtime.onMessage.addListener((message) => {
    if (message?.type === "VOID_TOAST") {
      showToast(message.text, true);
    }
  });
})();

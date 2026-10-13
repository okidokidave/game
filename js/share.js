/*
 * 공유하기
 *
 * SHARE_CONFIG.siteUrl: 배포한 사이트 주소 (예: "https://okidokidave.github.io/game/")
 *   비어 있으면 지금 열려 있는 페이지 주소를 공유합니다.
 * SHARE_CONFIG.kakaoKey: 카카오 디벨로퍼스(developers.kakao.com)에서 발급받은 JavaScript 키
 *   비어 있으면 카카오톡 버튼은 휴대폰 기본 공유창(→ 카카오톡 선택) 또는 링크 복사로 동작합니다.
 */
const SHARE_CONFIG = {
  siteUrl: "",
  kakaoKey: "",
};

const Share = (() => {
  // 공식 공유 주소가 있는 곳은 새 창으로 열고,
  // 인스타그램·틱톡·다음 카페처럼 웹 공유 주소가 없는 곳은 기본 공유창 또는 링크 복사로 대신합니다.
  const PLATFORMS = [
    { id: "kakao", label: "카카오톡", color: "#FEE500", text: "#191919", mark: "K" },
    {
      id: "x",
      label: "X",
      color: "#000000",
      text: "#ffffff",
      mark: "𝕏",
      url: ({ text, url }) =>
        `https://twitter.com/intent/tweet?text=${encodeURIComponent(text)}&url=${encodeURIComponent(url)}`,
    },
    {
      id: "naver",
      label: "네이버 블로그·카페",
      color: "#03C75A",
      text: "#ffffff",
      mark: "N",
      url: ({ title, url }) =>
        `https://share.naver.com/web/shareView?url=${encodeURIComponent(url)}&title=${encodeURIComponent(title)}`,
    },
    {
      id: "band",
      label: "네이버 밴드",
      color: "#00C73C",
      text: "#ffffff",
      mark: "B",
      url: ({ text, url }) =>
        `https://band.us/plugin/share?body=${encodeURIComponent(`${text}\n${url}`)}&route=${encodeURIComponent(url)}`,
    },
    { id: "daum", label: "다음 카페", color: "#3B7BF6", text: "#ffffff", mark: "D", copyHint: "다음 카페 글쓰기에 붙여넣어 주세요" },
    { id: "instagram", label: "인스타그램", color: "linear-gradient(45deg,#F58529,#DD2A7B,#8134AF)", text: "#ffffff", mark: "◎", copyHint: "인스타그램 스토리나 프로필에 붙여넣어 주세요" },
    { id: "tiktok", label: "틱톡", color: "#111111", text: "#ffffff", mark: "♪", copyHint: "틱톡 프로필이나 댓글에 붙여넣어 주세요" },
    { id: "copy", label: "링크 복사", color: "var(--bg)", text: "var(--text)", mark: "🔗" },
  ];

  let payload = null;
  let notify = () => {};
  let kakaoReady = null;

  const isMobile = () => /Android|iPhone|iPad|iPod/i.test(navigator.userAgent);

  async function copy(text) {
    try {
      await navigator.clipboard.writeText(text);
      return true;
    } catch {
      // https가 아닌 곳에서는 clipboard API가 막혀 있으므로 예전 방식으로 복사
      const ta = Object.assign(document.createElement("textarea"), { value: text });
      ta.style.cssText = "position:fixed;opacity:0";
      document.body.append(ta);
      ta.select();
      let ok = false;
      try {
        ok = document.execCommand("copy");
      } catch {}
      ta.remove();
      return ok;
    }
  }

  async function copyWithMessage(hint) {
    const ok = await copy(`${payload.text}\n${payload.url}`);
    notify(ok ? `링크를 복사했어요${hint ? `. ${hint}` : ""}` : "복사하지 못했어요. 주소창의 링크를 직접 복사해 주세요");
  }

  async function nativeShare() {
    if (!navigator.share) return false;
    try {
      await navigator.share({ title: payload.title, text: payload.text, url: payload.url });
    } catch (e) {
      if (e.name !== "AbortError") return false;
    }
    return true;
  }

  function loadKakao() {
    if (!SHARE_CONFIG.kakaoKey) return Promise.resolve(false);
    if (kakaoReady) return kakaoReady;
    kakaoReady = new Promise((resolve) => {
      const s = document.createElement("script");
      s.src = "https://t1.kakaocdn.net/kakao_js_sdk/2.7.2/kakao.min.js";
      s.crossOrigin = "anonymous";
      s.onload = () => {
        try {
          if (!window.Kakao.isInitialized()) window.Kakao.init(SHARE_CONFIG.kakaoKey);
          resolve(true);
        } catch {
          resolve(false);
        }
      };
      s.onerror = () => resolve(false);
      document.head.append(s);
    });
    return kakaoReady;
  }

  async function shareTo(platform) {
    if (platform.url) {
      window.open(platform.url(payload), "_blank", "noopener,width=600,height=640");
      return;
    }
    if (platform.id === "kakao") {
      if (await loadKakao()) {
        window.Kakao.Share.sendDefault({
          objectType: "text",
          text: payload.text,
          link: { webUrl: payload.url, mobileWebUrl: payload.url },
          buttonTitle: "게임하러 가기",
        });
        return;
      }
      if (isMobile() && (await nativeShare())) return;
      return copyWithMessage("카카오톡 대화창에 붙여넣어 주세요");
    }
    if (platform.copyHint) {
      // 휴대폰에서는 기본 공유창에 인스타그램·틱톡 앱이 나오므로 먼저 시도
      if (isMobile() && (await nativeShare())) return;
      return copyWithMessage(platform.copyHint);
    }
    return copyWithMessage();
  }

  function render(dialog) {
    const grid = dialog.querySelector(".share-grid");
    grid.replaceChildren(
      ...PLATFORMS.map((p) => {
        const btn = document.createElement("button");
        btn.className = "share-btn";
        btn.innerHTML = `<span class="share-icon"></span><span class="share-label"></span>`;
        const icon = btn.querySelector(".share-icon");
        icon.style.background = p.color;
        icon.style.color = p.text;
        icon.textContent = p.mark;
        btn.querySelector(".share-label").textContent = p.label;
        btn.addEventListener("click", () => {
          dialog.close();
          shareTo(p);
        });
        return btn;
      })
    );
  }

  return {
    init({ onNotify }) {
      notify = onNotify;
      const dialog = document.getElementById("share-dialog");
      render(dialog);
      dialog.querySelector(".share-close").addEventListener("click", () => dialog.close());
      dialog.addEventListener("click", (e) => {
        if (e.target === dialog) dialog.close();
      });
    },
    open({ title, text, path = "" }) {
      const base = SHARE_CONFIG.siteUrl || location.href.split("#")[0];
      payload = { title, text, url: base + path };
      const dialog = document.getElementById("share-dialog");
      dialog.querySelector(".share-preview").textContent = text;
      dialog.showModal();
    },
  };
})();

/*
 * Google AdSense 설정
 *
 * 1. AdSense 승인 후 받은 게시자 ID를 client에 적습니다. (예: "ca-pub-1234567890123456")
 * 2. AdSense에서 '디스플레이 광고' 단위를 만들고, 받은 슬롯 번호를 slots에 적습니다.
 * 3. 사이트 루트에 ads.txt 파일을 만들어 AdSense가 안내하는 한 줄을 넣어 주세요.
 *
 * client가 비어 있으면 광고 대신 "광고 영역" 자리 표시만 보입니다.
 */
const ADSENSE = {
  client: "",
  slots: {
    left: "", // 왼쪽 칸 세로형 (넓은 화면에서만 보임)
    sidebar: "",
    footer: "",
  },
};

(() => {
  const slots = document.querySelectorAll(".ad-slot[data-slot]");

  if (!ADSENSE.client) {
    slots.forEach((el) => {
      el.classList.add("placeholder");
      el.textContent = "광고 영역";
    });
    return;
  }

  const script = document.createElement("script");
  script.async = true;
  script.crossOrigin = "anonymous";
  script.src = `https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=${ADSENSE.client}`;
  document.head.appendChild(script);

  slots.forEach((el) => {
    const slotId = ADSENSE.slots[el.dataset.slot];
    // 화면 크기 때문에 숨겨진 칸에는 광고를 넣지 않음 (AdSense 오류 방지)
    if (!slotId || el.offsetParent === null) {
      el.remove();
      return;
    }
    const ins = document.createElement("ins");
    ins.className = "adsbygoogle";
    ins.style.display = "block";
    ins.dataset.adClient = ADSENSE.client;
    ins.dataset.adSlot = slotId;
    ins.dataset.adFormat = "auto";
    ins.dataset.fullWidthResponsive = "true";
    el.appendChild(ins);
    (window.adsbygoogle = window.adsbygoogle || []).push({});
  });
})();

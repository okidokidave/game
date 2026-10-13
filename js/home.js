(() => {
  const { $, el } = Site;

  Site.init({ current: "home" });
  // 본문에 "모든 콘텐츠"가 있으므로 사이드바의 "다른 콘텐츠"는 숨김
  $("more-list").closest("details").hidden = true;

  $("home-fortune").append(Daily.fortuneWidget());
  const spelling = Daily.spellingWidget();
  if (spelling) $("home-spelling").append(spelling);

  const items = Site.continueItems();
  $("home-continue").hidden = items.length === 0;
  $("home-continue-list").replaceChildren(
    ...items.map((it) => el("a", { className: "rail-link", href: it.href }, [el("strong", { textContent: it.title }), el("span", { textContent: it.detail })]))
  );

  $("home-contents").replaceChildren(
    ...SITE_CATALOG.map((c) => {
      const icon = el("span", { className: "content-icon", textContent: c.icon || "🎮" });
      icon.style.setProperty("--tile", c.color || "var(--accent)");
      return el("a", { className: "content-card", href: c.href }, [
        icon,
        el("span", { className: "content-text" }, [
          el("span", { className: "nav-type", textContent: CATALOG_LABELS[c.type] }),
          el("strong", { textContent: c.title }),
          el("span", { className: "more-desc", textContent: c.desc }),
        ]),
      ]);
    })
  );

  $("btn-share").addEventListener("click", () =>
    Share.open({ title: "틈놀", text: "짧은 틈에 즐기는 틈새놀이터, 틈놀! 스도쿠, 십자말풀이, 맞춤법 퀴즈, 게임북까지 가입 없이 무료로 즐겨요." })
  );
})();

// Bekendr website: animaties en kleine interacties. Alles werkt ook zonder JavaScript.
(function () {
  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const $ = (s, el = document) => el.querySelector(s);
  const $$ = (s, el = document) => Array.from(el.querySelectorAll(s));

  // Jaartal en datum
  const year = $('#year');
  if (year) year.textContent = String(new Date().getFullYear());
  const today = $('#today');
  if (today) {
    const t = new Date().toLocaleDateString('nl-NL', { weekday: 'long', day: 'numeric', month: 'long' });
    today.textContent = t.charAt(0).toUpperCase() + t.slice(1);
  }

  // Rand onder de navigatie zodra je scrolt
  const bar = $('.topbar');
  if (bar) {
    const onScroll = () => bar.classList.toggle('scrolled', window.scrollY > 8);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
  }

  // Getallen die optellen
  function countUp(el) {
    const target = Number(el.dataset.count || 0);
    if (reduce) { el.textContent = String(target); return; }
    const start = performance.now();
    const dur = 900 + target * 30;
    const tick = now => {
      const p = Math.min(1, (now - start) / dur);
      el.textContent = String(Math.round(target * (1 - Math.pow(1 - p, 3))));
      if (p < 1) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  }
  setTimeout(() => $$('[data-count]').forEach(countUp), reduce ? 0 : 900);

  // Meldingen die binnenkomen boven de telefoon
  const notices = [
    ['Vergunning · Thuis', 'Omgevingsvergunning aangevraagd: plaatsen dakkapel', 'nu'],
    ['Verkeer · Thuis', 'Twee parkeerplaatsen voor elektrisch laden', '2 min'],
    ['Bomen en kap · Werk', 'Kapvergunning verleend voor drie eiken', '5 min'],
    ['Evenement · Thuis', 'Evenementenvergunning: winterfair in het park', '9 min'],
    ['Ruimtelijk plan · Ouders', 'Ontwerpplan ter inzage: woningbouw op schoolterrein', '12 min'],
  ];
  const toasts = $('#toasts');
  if (toasts) {
    let i = 0;
    const show = () => {
      const [title, text, when] = notices[i % notices.length];
      i++;
      const el = document.createElement('div');
      el.className = 'toast';
      el.innerHTML = '<img src="/assets/icon.png" alt=""><div><b></b><span></span></div><span class="when"></span>';
      el.querySelector('b').textContent = title;
      el.querySelector('div span').textContent = text;
      el.querySelector('.when').textContent = when;
      toasts.appendChild(el);
      requestAnimationFrame(() => requestAnimationFrame(() => el.classList.add('show')));
      setTimeout(() => { el.classList.add('out'); setTimeout(() => el.remove(), 700); }, 3200);
    };
    if (!reduce) { setTimeout(show, 2400); setInterval(show, 4200); }
  }

  // De telefoon kantelt een beetje mee met de muis
  const tilt = $('#tilt');
  if (tilt && !reduce && window.matchMedia('(pointer: fine)').matches) {
    const stage = tilt.parentElement;
    stage.addEventListener('mousemove', e => {
      const r = stage.getBoundingClientRect();
      const x = (e.clientX - r.left) / r.width - 0.5;
      const y = (e.clientY - r.top) / r.height - 0.5;
      tilt.style.transform = `rotateY(${x * 14}deg) rotateX(${-y * 10}deg)`;
    });
    stage.addEventListener('mouseleave', () => { tilt.style.transform = ''; });
  }

  // Lopende band met voorbeelden (twee keer, voor een naadloze lus)
  const ticker = $('#ticker');
  if (ticker) {
    const items = [
      ['permit', '#2747E8', 'Omgevingsvergunning: dakkapel'],
      ['traffic', '#E8743B', 'Verkeersbesluit: laadpalen'],
      ['tree', '#2E8B57', 'Kapvergunning: drie eiken'],
      ['event', '#7B4BD6', 'Evenement: winterfair'],
      ['plan', '#0F8A8A', 'Bestemmingsplan ter inzage'],
      ['permit', '#2747E8', 'Aanvraag: uitbouw achterzijde'],
      ['traffic', '#E8743B', 'Wegafsluiting: rioolwerk'],
      ['other', '#5B6275', 'Verordening: parkeren'],
      ['tree', '#2E8B57', 'Kapmelding: plantsoen'],
      ['event', '#7B4BD6', 'Markt op zaterdag'],
      ['plan', '#0F8A8A', 'Omgevingsplan: nieuwe wijk'],
      ['permit', '#2747E8', 'Sloopvergunning: schuur'],
    ];
    const html = items.map(([icon, color, text]) =>
      `<span class="ticker-item"><i style="background:${color};color:#fff"><svg aria-hidden="true"><use href="#i-${icon}"/></svg></i>${text}</span>`).join('');
    ticker.innerHTML = html + html.replace(/class="ticker-item"/g, 'class="ticker-item" aria-hidden="true"');
  }

  // Hoe het werkt: de kaart volgt de stappen (vanzelf, of door te tikken)
  const steps = $$('#steps li');
  const map = $('#mapbox');
  if (steps.length && map) {
    let current = 0;
    let timer = null;
    let areaMode = false;
    const set = n => {
      current = n;
      steps.forEach((li, i) => li.classList.toggle('on', i + 1 === n));
      map.dataset.step = String(n);
    };
    const run = () => {
      clearInterval(timer);
      timer = setInterval(() => {
        const next = current >= 3 ? 1 : current + 1;
        if (next === 1) { areaMode = !areaMode; map.classList.toggle('area-mode', areaMode); }
        set(next);
      }, 2600);
    };
    steps.forEach((li, i) => {
      li.setAttribute('tabindex', '0');
      const go = () => { set(i + 1); run(); };
      li.addEventListener('click', go);
      li.addEventListener('keydown', e => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); go(); } });
    });
    if (reduce || !('IntersectionObserver' in window)) { set(3); }
    else {
      const io = new IntersectionObserver(entries => entries.forEach(e => {
        if (e.isIntersecting) { set(1); run(); io.disconnect(); }
      }), { threshold: 0.35 });
      io.observe(map);
    }
  }

  // Verschijnen bij scrollen
  const groups = ['.section-head', '.steps li', '.cat', '.feature', '.checks li', '.flow', '.plat', '.faq details', '.cta', '.more-apps', '.page > *'];
  const items = [];
  groups.forEach(sel => $$(sel).forEach((el, i) => {
    el.classList.add('reveal');
    el.style.setProperty('--r', String(i % 6));
    items.push(el);
  }));
  if (reduce || !('IntersectionObserver' in window)) {
    items.forEach(el => el.classList.add('in'));
  } else {
    const io = new IntersectionObserver(entries => entries.forEach(e => {
      if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); }
    }), { threshold: 0, rootMargin: '0px 0px -8% 0px' });
    items.forEach(el => io.observe(el));
  }
})();

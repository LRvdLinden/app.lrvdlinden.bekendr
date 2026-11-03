// Genereert App Store-screenshots (in mockup), promo-afbeeldingen en icoon voor Stookwijzer.
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');
const { logo, defs } = require('./flame.js');

const OUT = process.argv[2];
const F = (w) => `file://${path.join(__dirname, 'node_modules/@fontsource/nunito/files', `nunito-latin-${w}-normal.woff2`)}`;

// ------------------------------------------------------------------ data
const C = {
  y: { name: 'Geel', title: 'Code geel', head: 'Stoken kan', color: '#F5B700', text: '#9A6B00', g: ['#FFD54A', '#F2A900'],
       ex: 'De omstandigheden zijn redelijk. Stook je toch, let dan op droog hout, een goed trekkende kachel en eventuele overlast voor je buren.' },
  o: { name: 'Oranje', title: 'Code oranje', head: 'Liever niet stoken', color: '#F27A1A', text: '#B4500A', g: ['#FFA552', '#EE6A0E'],
       ex: 'Door weinig wind of matige luchtkwaliteit blijft rook langer hangen. De kans op overlast en gezondheidsklachten in de buurt is groter.' },
  r: { name: 'Rood', title: 'Code rood', head: 'Niet stoken', color: '#E23B3B', text: '#B42323', g: ['#FF7A6B', '#D92D2D'],
       ex: 'Rook verspreidt zich slecht en de luchtkwaliteit is onvoldoende. Stoken veroorzaakt nu veel overlast. In sommige gemeenten kun je een boete krijgen.' },
};
const grad = (k, a = 135) => `linear-gradient(${a}deg, ${C[k].g[0]}, ${C[k].g[1]})`;

// ------------------------------------------------------------------ icons
const ico = {
  y: (s, c = '#fff') => `<svg width="${s}" height="${s}" viewBox="0 0 24 24"><path fill="${c}" d="M12 2c.6 2.6 2.4 4.3 4 6 1.7 1.8 3 3.8 3 6.4A7 7 0 0 1 12 21a7 7 0 0 1-7-6.6c0-2.3 1-4 2.4-5.4.2 1.6.9 2.8 2.1 3.4C9 9 10.4 5.2 12 2z"/></svg>`,
  o: (s, c = '#fff') => `<svg width="${s}" height="${s}" viewBox="0 0 24 24"><path fill="${c}" d="M10.3 3.4a2 2 0 0 1 3.4 0l8.1 14.1A2 2 0 0 1 20.1 20.5H3.9a2 2 0 0 1-1.7-3l8.1-14.1z"/><rect x="11" y="8.5" width="2" height="6.5" rx="1" fill="${c === '#fff' ? '#F27A1A' : '#fff'}"/><circle cx="12" cy="17.4" r="1.2" fill="${c === '#fff' ? '#F27A1A' : '#fff'}"/></svg>`,
  r: (s, c = '#fff') => `<svg width="${s}" height="${s}" viewBox="0 0 24 24"><circle cx="12" cy="12" r="8.5" fill="none" stroke="${c}" stroke-width="2.6"/><path d="M6.2 6.2l11.6 11.6" stroke="${c}" stroke-width="2.6" stroke-linecap="round"/></svg>`,
  bell: (s, c) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24"><path fill="${c}" d="M12 22a2.5 2.5 0 0 0 2.4-2h-4.8A2.5 2.5 0 0 0 12 22zm7-6V11a7 7 0 0 0-5.5-6.8V3.5a1.5 1.5 0 0 0-3 0v.7A7 7 0 0 0 5 11v5l-2 2v1h18v-1l-2-2z"/></svg>`,
  info: (s, c) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24"><circle cx="12" cy="12" r="9.5" fill="none" stroke="${c}" stroke-width="1.8"/><rect x="11" y="10.5" width="2" height="7" rx="1" fill="${c}"/><circle cx="12" cy="7.5" r="1.3" fill="${c}"/></svg>`,
  loc: (s, c) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24"><path fill="${c}" d="M21 3L3 10.5l7.5 2.9L13.5 21z"/></svg>`,
  pin: (s, c) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10" fill="${c}"/><circle cx="12" cy="10" r="3.2" fill="#fff"/><path d="M12 13.5v5" stroke="#fff" stroke-width="2" stroke-linecap="round"/></svg>`,
  chev: (s, c) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24"><path d="M6 9l6 6 6-6" fill="none" stroke="${c}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
  check: (s, c) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24"><path d="M5 12.5l4.5 4.5L19 7.5" fill="none" stroke="${c}" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
  plus: (s, c) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24"><path d="M12 5v14M5 12h14" stroke="${c}" stroke-width="2.4" stroke-linecap="round"/></svg>`,
  wind: (s, c) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="${c}" stroke-width="2" stroke-linecap="round"><path d="M3 8h10a3 3 0 1 0-3-3M3 12h15a3 3 0 1 1-3 3M3 16h7"/></svg>`,
  aqi: (s, c) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="${c}" stroke-width="2" stroke-linecap="round"><path d="M4 18a8 8 0 1 1 16 0"/><path d="M12 18l4-6"/></svg>`,
  clock: (s, c) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="${c}" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>`,
  search: (s, c) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="${c}" stroke-width="2.4" stroke-linecap="round"><circle cx="11" cy="11" r="6.5"/><path d="M16 16l4.5 4.5"/></svg>`,
};
const flameSvg = (w) => `<svg width="${w}" height="${w * 1.25}" viewBox="0 0 ${w} ${w * 1.25}"><defs>${defs}</defs>${logo(w / 2, w * 1.25, w)}</svg>`;

// ------------------------------------------------------------------ css
const css = `
@font-face{font-family:Rounded;src:url(${F(600)});font-weight:600}
@font-face{font-family:Rounded;src:url(${F(700)});font-weight:700}
@font-face{font-family:Rounded;src:url(${F(800)});font-weight:800}
@font-face{font-family:Rounded;src:url(${F(900)});font-weight:900}
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:Inter,system-ui,sans-serif;-webkit-font-smoothing:antialiased;overflow:hidden}
.r{font-family:Rounded,Inter,sans-serif}
:root{--bg:#FAF6F1;--card:#fff;--ink:#2A2320;--muted:#7D716A;--line:#EFE7DF;--ember:#F76B15}
.screen{position:relative;overflow:hidden;background:var(--bg);color:var(--ink)}
.sb{height:54px;display:flex;align-items:center;justify-content:space-between;padding:0 34px 0 46px;font-weight:600;font-size:17px}
.sbi{display:flex;gap:6px;align-items:center}
.card{background:#fff;border:1px solid var(--line);border-radius:26px;box-shadow:0 6px 12px rgba(0,0,0,.04)}
.pill{display:inline-flex;align-items:center;gap:6px;background:#fff;border:1px solid var(--line);border-radius:22px;padding:7px 14px;font-weight:700;font-size:17px}
.hero{padding:26px 22px;text-align:center;position:relative;overflow:hidden}
.ring{border-radius:50%;display:flex;align-items:center;justify-content:center;margin:0 auto}
.kicker{font-weight:900;letter-spacing:1.6px;font-size:13px;margin-top:16px}
.headline{font-weight:800;font-size:33px;margin-top:4px;letter-spacing:-.3px}
.ex{color:var(--muted);font-size:15px;line-height:1.38;margin-top:10px}
.next{display:inline-flex;gap:8px;align-items:center;background:var(--bg);border-radius:20px;padding:9px 14px;margin-top:16px;font-weight:600;font-size:15px}
.dot{width:10px;height:10px;border-radius:50%;display:inline-block}
.stats{display:grid;gap:12px}
.st{padding:14px;border-radius:20px}
.st small{display:flex;gap:5px;align-items:center;color:var(--muted);font-weight:600;font-size:12px;white-space:nowrap}
.st b{display:block;font-size:21px;margin:5px 0 2px;font-family:Rounded}
.st span{color:var(--muted);font-size:12px}
.fc{padding:20px}
.fh{display:flex;justify-content:space-between;align-items:baseline}
.fh h3{font-size:21px;font-family:Rounded;font-weight:800}
.fh small{font-size:12px;color:var(--muted);font-weight:500}
.row{display:flex;gap:10px;margin-top:14px}
.fp{width:74px;flex:none;border-radius:18px;background:var(--bg);padding:12px 0;display:flex;flex-direction:column;align-items:center;gap:6px;font-size:12px}
.fp b{font-weight:700}.fp small{color:var(--muted);font-size:11px}
.fp .c{width:36px;height:36px;border-radius:50%;display:flex;align-items:center;justify-content:center}
.fp em{font-style:normal;font-weight:700;font-size:12px}.fp i{font-style:normal;font-size:9px;color:var(--muted);font-weight:500}
.fp.now{color:#fff}.fp.now small,.fp.now i{color:rgba(255,255,255,.85)}
.bar{display:flex;gap:3px;margin-top:16px}.bar span{flex:1;height:8px;border-radius:4px}
.leg{display:flex;gap:14px;margin-top:12px;font-size:12px;color:var(--muted)}
.lg{padding:20px}.lg h3{font-size:21px;font-family:Rounded;font-weight:800;margin-bottom:14px}
.li{display:flex;gap:14px;margin-bottom:14px}.li:last-child{margin-bottom:0}
.lic{width:40px;height:40px;border-radius:12px;flex:none;display:flex;align-items:center;justify-content:center}
.li b{font-size:15px;font-weight:600}.li p{font-size:12.5px;color:var(--muted);line-height:1.35;margin-top:3px}
.now-tag{font-size:10px;font-weight:900;padding:2px 6px;border-radius:8px;margin-left:6px}
.foot{text-align:center;color:var(--muted);font-size:13px;margin-top:16px}
.home-ind{position:absolute;bottom:9px;left:50%;transform:translateX(-50%);width:150px;height:5px;border-radius:3px;background:#1d1b1e}
`;

const statusBar = (dark = false) => {
  const c = dark ? '#fff' : '#1b1b1d';
  return `<div class="sb" style="color:${c}"><span>9:41</span><span class="sbi">
  <svg width="19" height="12" viewBox="0 0 19 12"><rect x="0" y="8" width="3" height="4" rx="1" fill="${c}"/><rect x="5" y="5.5" width="3" height="6.5" rx="1" fill="${c}"/><rect x="10" y="3" width="3" height="9" rx="1" fill="${c}"/><rect x="15" y="0" width="3" height="12" rx="1" fill="${c}"/></svg>
  <svg width="17" height="12" viewBox="0 0 17 12"><path d="M8.5 2.2c2.4 0 4.6.9 6.3 2.5l1.2-1.3A10.5 10.5 0 0 0 8.5.4 10.5 10.5 0 0 0 1 3.4l1.2 1.3A8.8 8.8 0 0 1 8.5 2.2zm0 3.6c1.4 0 2.7.5 3.7 1.4l1.2-1.3a7.2 7.2 0 0 0-9.8 0l1.2 1.3c1-.9 2.3-1.4 3.7-1.4zm0 3.5c-.6 0-1.1.2-1.5.6l1.5 1.6 1.5-1.6c-.4-.4-.9-.6-1.5-.6z" fill="${c}"/></svg>
  <svg width="27" height="13" viewBox="0 0 27 13"><rect x=".5" y=".5" width="23" height="12" rx="3.8" fill="none" stroke="${c}" opacity=".4"/><rect x="2" y="2" width="20" height="9" rx="2.5" fill="${c}"/><path d="M25 4.5v4c.8-.3 1.3-1.1 1.3-2s-.5-1.7-1.3-2z" fill="${c}" opacity=".4"/></svg></span></div>`;
};

// ------------------------------------------------------------------ app parts
function hero(k, next, big = true) {
  const s = big ? 1 : 0.92;
  return `<div class="card hero" style="background:linear-gradient(${C[k].color}1A, #fff 52%)">
    <div class="ring" style="width:${210 * s}px;height:${210 * s}px;background:${C[k].color}1F">
      <div class="ring" style="width:${176 * s}px;height:${176 * s}px;background:${C[k].color}2E">
        <div class="ring" style="width:${140 * s}px;height:${140 * s}px;background:${grad(k)};box-shadow:0 12px 22px ${C[k].color}73">${ico[k](62 * s)}</div></div></div>
    <div class="kicker r" style="color:${C[k].text}">${C[k].title.toUpperCase()}</div>
    <div class="headline r">${C[k].head}</div>
    <div class="ex">${C[k].ex}</div>
    ${next ? `<div class="next"><span class="dot" style="background:${C[next.k].color}"></span>${next.t} wordt het ${C[next.k].title.toLowerCase()}</div>` : ''}
  </div>`;
}
function stats(cols, d) {
  const t = (i, l, v, s) => `<div class="card st"><small>${ico[i](14, '#7D716A')}${l}</small><b>${v}</b><span>${s}</span></div>`;
  return `<div class="stats" style="grid-template-columns:repeat(${cols},1fr)">${t('wind', 'Wind', d.bft, d.ms)}${t('aqi', 'Luchtkwaliteit', d.lki, d.lkiL)}${t('clock', 'Model', d.model, 'Vandaag')}</div>`;
}
function forecast(slots) {
  const pill = (s, i) => {
    const now = i === 0;
    return `<div class="fp ${now ? 'now' : ''}" style="${now ? `background:${grad(s.k)}` : ''}">
      <b>${now ? 'Nu' : s.d}</b><small>${s.t}</small>
      <span class="c" style="background:${now ? '#fff' : grad(s.k)}">${ico[s.k](16, now ? C[s.k].color : '#fff')}</span>
      <em style="color:${now ? '#fff' : C[s.k].text}">${C[s.k].name}</em>${s.p ? '<i>voorlopig</i>' : '<i>&nbsp;</i>'}</div>`;
  };
  return `<div class="card fc"><div class="fh"><h3>Verwachting</h3><small>per 6 uur</small></div>
    <div class="row">${slots.map(pill).join('')}</div>
    <div class="bar">${slots.map((s) => `<span style="background:${C[s.k].color};opacity:${s.p ? 0.55 : 1}"></span>`).join('')}</div>
    <div class="leg"><span><span class="dot" style="background:#F76B15;width:8px;height:8px"></span> Definitief</span><span><span class="dot" style="background:#F76B15;opacity:.55;width:8px;height:8px"></span> Voorlopig</span></div></div>`;
}
function legend(cur) {
  return `<div class="card lg"><h3>Wat betekenen de codes?</h3>${['y', 'o', 'r'].map((k) => `<div class="li"><span class="lic" style="background:${grad(k)}">${ico[k](18)}</span>
    <div><b>${C[k].title} · ${C[k].head}</b>${k === cur ? `<span class="now-tag" style="background:${C[k].color}2E;color:${C[k].text}">NU</span>` : ''}<p>${C[k].ex}</p></div></div>`).join('')}</div>`;
}
function navPhone(place, bell = false) {
  return `<div style="display:flex;align-items:center;justify-content:space-between;padding:4px 20px 14px">
    <span>${ico.bell(23, '#F76B15')}</span>
    <span class="pill r">${place === 'loc' ? ico.loc(13, '#2A2320') + ' Apeldoorn' : place} ${ico.chev(13, '#7D716A')}</span>
    <span>${ico.info(24, '#F76B15')}</span></div>`;
}

const SLOTS = {
  o: [{ k: 'o', d: 'Vandaag', t: '12:00' }, { k: 'y', d: 'Vandaag', t: '18:00', p: 1 }, { k: 'y', d: 'Morgen', t: '00:00', p: 1 }, { k: 'r', d: 'Morgen', t: '06:00', p: 1 }, { k: 'o', d: 'Morgen', t: '12:00', p: 1 }, { k: 'y', d: 'Morgen', t: '18:00', p: 1 }, { k: 'y', d: 'Do', t: '00:00', p: 1 }, { k: 'y', d: 'Do', t: '06:00', p: 1 }],
  y: [{ k: 'y', d: 'Vandaag', t: '12:00' }, { k: 'y', d: 'Vandaag', t: '18:00', p: 1 }, { k: 'o', d: 'Morgen', t: '00:00', p: 1 }, { k: 'r', d: 'Morgen', t: '06:00', p: 1 }, { k: 'o', d: 'Morgen', t: '12:00', p: 1 }, { k: 'y', d: 'Morgen', t: '18:00', p: 1 }, { k: 'y', d: 'Do', t: '00:00', p: 1 }, { k: 'y', d: 'Do', t: '06:00', p: 1 }],
  r: [{ k: 'r', d: 'Vandaag', t: '18:00' }, { k: 'r', d: 'Morgen', t: '00:00', p: 1 }, { k: 'o', d: 'Morgen', t: '06:00', p: 1 }, { k: 'y', d: 'Morgen', t: '12:00', p: 1 }, { k: 'y', d: 'Morgen', t: '18:00', p: 1 }, { k: 'o', d: 'Do', t: '00:00', p: 1 }, { k: 'y', d: 'Do', t: '06:00', p: 1 }, { k: 'y', d: 'Do', t: '12:00', p: 1 }],
};
const STATS = {
  o: { bft: '2 Bft', ms: '2,4 m/s', lki: 'LKI 5', lkiL: 'Matig', model: '12:00' },
  y: { bft: '4 Bft', ms: '6,8 m/s', lki: 'LKI 3', lkiL: 'Goed', model: '12:00' },
  r: { bft: '1 Bft', ms: '0,9 m/s', lki: 'LKI 8', lkiL: 'Onvoldoende', model: '18:00' },
};

// ------------------------------------------------------------------ iPhone screens (440 x 956)
const PW = 440, PH = 956;
const phone = {
  home: () => `<div class="screen" style="width:${PW}px;height:${PH}px">${statusBar()}${navPhone('loc')}
    <div style="padding:0 20px;display:flex;flex-direction:column;gap:16px">${hero('o', { k: 'y', t: 'Vandaag 18:00' })}${stats(3, STATS.o)}${forecast(SLOTS.o)}</div><div class="home-ind"></div></div>`,

  forecast: () => `<div class="screen" style="width:${PW}px;height:${PH}px">${statusBar()}${navPhone('Epe')}
    <div style="padding:0 20px;display:flex;flex-direction:column;gap:16px">${stats(3, STATS.y)}${forecast(SLOTS.y)}${legend('y')}
    <div class="foot">Bron: RIVM Stookwijzer via Atlas Leefomgeving · Bijgewerkt 12:04</div></div><div class="home-ind"></div></div>`,

  lock: () => {
    const notif = (title, sub, body, when) => `<div style="background:rgba(255,255,255,.72);backdrop-filter:blur(20px);border-radius:24px;padding:14px 16px;display:flex;gap:12px;box-shadow:0 8px 30px rgba(80,30,10,.12)">
      <img src="ICON" style="width:40px;height:40px;border-radius:10px;flex:none"/>
      <div style="flex:1;min-width:0"><div style="display:flex;justify-content:space-between;font-size:15px"><b>${title}</b><span style="color:#6b625d;font-size:13px">${when}</span></div>
      <div style="font-size:15px;font-weight:600">${sub}</div><div style="font-size:15px;color:#3d3531;line-height:1.3">${body}</div></div></div>`;
    return `<div class="screen" style="width:${PW}px;height:${PH}px;background:linear-gradient(170deg,#FFE9D6 0%,#FFC9A3 45%,#F59A6B 100%);color:#2a1d17">
      ${statusBar()}<div style="text-align:center;margin-top:30px">
      <div style="font-weight:600;font-size:21px;opacity:.75">dinsdag 3 november</div>
      <div class="r" style="font-size:104px;font-weight:800;line-height:1;margin-top:2px;letter-spacing:-2px">17:58</div>
      <div style="display:inline-flex;gap:10px;align-items:center;margin-top:14px;background:rgba(255,255,255,.35);border-radius:18px;padding:9px 14px;text-align:left">
        ${ico.r(26, '#2a1d17')}<div><div style="font-weight:700;font-size:15px">Code rood</div><div style="font-size:13px;opacity:.8">Niet stoken · Apeldoorn</div></div></div></div>
      <div style="position:absolute;left:16px;right:16px;top:430px;display:flex;flex-direction:column;gap:10px">
      ${notif('Code rood in Apeldoorn', 'Niet stoken', 'Rook verspreidt zich slecht. In sommige gemeenten kun je nu een boete krijgen. Vanaf 06:00 code oranje.', 'nu')}
      ${notif('Code oranje in Epe', 'Liever niet stoken', 'Weinig wind of matige luchtkwaliteit: rook blijft langer hangen.', '2 u. geleden')}
      </div>
      <div style="position:absolute;bottom:52px;left:0;right:0;display:flex;justify-content:space-between;padding:0 48px">
      ${['M8 3h8l-1 5h-6z M9 8h6v13H9z', 'M5 8h3l2-3h4l2 3h3a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V9a1 1 0 0 1 1-1z'].map((d) => `<span style="width:52px;height:52px;border-radius:50%;background:rgba(255,255,255,.35);display:flex;align-items:center;justify-content:center"><svg width="24" height="24" viewBox="0 0 24 24"><path d="${d}" fill="#2a1d17"/></svg></span>`).join('')}</div>
      <div class="home-ind" style="background:#2a1d17"></div></div>`;
  },

  widgets: () => {
    const app = (bg) => `<div style="width:64px;height:64px;border-radius:15px;background:${bg};box-shadow:0 2px 6px rgba(0,0,0,.08)"></div>`;
    const neutral = ['#ffffffb3', '#ffffff99', '#ffffffa6', '#ffffff8c'];
    return `<div class="screen" style="width:${PW}px;height:${PH}px;background:linear-gradient(165deg,#FFF3E6 0%,#FFD9BD 50%,#FBB08A 100%)">
    ${statusBar()}<div style="padding:16px 28px;display:grid;grid-template-columns:repeat(2,1fr);gap:22px">
      <div style="border-radius:24px;aspect-ratio:1;background:${grad('o', 160)};color:#fff;padding:16px;display:flex;flex-direction:column;box-shadow:0 10px 24px rgba(238,106,14,.35)">
        <div style="display:flex;justify-content:space-between;align-items:center">${ico.o(26)}<span style="font-size:12px;font-weight:600;opacity:.9">Apeldoorn</span></div>
        <div style="flex:1"></div><div class="r" style="font-size:11px;font-weight:900;letter-spacing:1px;opacity:.9">CODE ORANJE</div>
        <div class="r" style="font-size:21px;font-weight:800;line-height:1.1">Liever niet stoken</div><div style="font-size:11px;opacity:.85;margin-top:4px">Vandaag 18:00: geel</div></div>
      <div style="display:grid;grid-template-columns:repeat(2,64px);gap:22px 20px;justify-content:space-between">${neutral.map(app).join('')}</div>
    </div>
    <div style="margin:4px 28px 0;border-radius:24px;height:174px;background:${grad('r', 160)};color:#fff;padding:16px;display:flex;gap:14px;box-shadow:0 10px 24px rgba(217,45,45,.35)">
      <div style="flex:1;display:flex;flex-direction:column"><div style="display:flex;justify-content:space-between">${ico.r(26)}<span style="font-size:12px;font-weight:600;opacity:.9">Deventer</span></div><div style="flex:1"></div>
        <div class="r" style="font-size:11px;font-weight:900;letter-spacing:1px;opacity:.9">CODE ROOD</div><div class="r" style="font-size:21px;font-weight:800">Niet stoken</div><div style="font-size:11px;opacity:.85;margin-top:3px">Morgen 06:00: oranje</div></div>
      <div style="flex:1;background:rgba(255,255,255,.18);border-radius:14px;padding:10px;display:flex;flex-direction:column;gap:7px">
        ${[['o', 'Morgen 06:00'], ['y', 'Morgen 12:00'], ['y', 'Morgen 18:00'], ['o', 'Do 00:00']].map(([k, t]) => `<div style="display:flex;gap:8px;align-items:center"><span style="width:22px;height:22px;border-radius:50%;background:#fff;display:flex;align-items:center;justify-content:center">${ico[k](11, C[k].color)}</span><div style="font-size:11px;line-height:1.15"><b>${t}</b><br><span style="opacity:.85">${C[k].name}</span></div></div>`).join('')}</div></div>
    <div style="padding:26px 28px;display:grid;grid-template-columns:repeat(4,64px);justify-content:space-between;gap:26px 0">${Array.from({ length: 8 }, (_, i) => app(neutral[i % 4])).join('')}</div>
    <div style="position:absolute;bottom:22px;left:16px;right:16px;height:92px;border-radius:32px;background:rgba(255,255,255,.4);display:flex;align-items:center;justify-content:space-around;padding:0 18px">
      <img src="ICON" style="width:64px;height:64px;border-radius:15px;box-shadow:0 2px 8px rgba(0,0,0,.12)"/>${app('#ffffffb3')}${app('#ffffff99')}${app('#ffffffa6')}</div>
    <div class="home-ind"></div></div>`;
  },

  places: () => {
    const row = (icon, name, sub, sel) => `<div style="display:flex;align-items:center;gap:12px;padding:12px 16px;border-bottom:1px solid #00000010">
      <span style="width:20px">${sel ? ico.check(18, '#2A2320') : ''}</span><div style="flex:1"><div style="font-size:17px">${name}</div>${sub ? `<div style="font-size:13px;color:#7D716A">${sub}</div>` : ''}</div>${icon}</div>`;
    return `<div class="screen" style="width:${PW}px;height:${PH}px">${statusBar()}${navPhone('loc')}
    <div style="padding:0 20px;filter:blur(1.5px);opacity:.55">${hero('o', { k: 'y', t: 'Vandaag 18:00' })}</div>
    <div style="position:absolute;left:70px;right:70px;top:104px;background:rgba(250,248,246,.96);backdrop-filter:blur(30px);border-radius:16px;box-shadow:0 20px 60px rgba(60,30,10,.25);overflow:hidden">
      ${row(ico.loc(18, '#2A2320'), 'Apeldoorn', 'Huidige locatie', true)}
      ${row(ico.pin(20, '#F76B15'), 'Epe', 'Gelderland')}
      ${row(ico.pin(20, '#F76B15'), 'Deventer', 'Overijssel')}
      ${row(ico.pin(20, '#F76B15'), 'Den Burg', 'Texel')}
      <div style="height:8px;background:#00000008"></div>
      ${row(ico.plus(20, '#2A2320'), 'Plaats toevoegen')}
      <div style="display:flex;align-items:center;gap:12px;padding:12px 16px"><span style="width:20px"></span><div style="flex:1;font-size:17px">Plaatsen beheren</div><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#2A2320" stroke-width="2.2" stroke-linecap="round"><path d="M9 6h11M9 12h11M9 18h11"/><circle cx="4.5" cy="6" r="1" fill="#2A2320"/><circle cx="4.5" cy="12" r="1" fill="#2A2320"/><circle cx="4.5" cy="18" r="1" fill="#2A2320"/></svg></div>
    </div><div class="home-ind"></div></div>`;
  },

  notifications: () => settingsSheet(PW, PH, true),
};

function settingsSheet(w, h, full) {
  const grp = (inner, header, footer) => `${header ? `<div style="font-size:13px;color:#8a817b;text-transform:uppercase;padding:0 32px 7px;letter-spacing:.2px">${header}</div>` : ''}
    <div style="margin:0 16px;background:#fff;border-radius:12px;overflow:hidden">${inner}</div>
    ${footer ? `<div style="font-size:13px;color:#8a817b;padding:7px 32px 0;line-height:1.35">${footer}</div>` : ''}<div style="height:26px"></div>`;
  const item = (content, last) => `<div style="display:flex;align-items:center;gap:12px;padding:0 16px;min-height:48px;${last ? '' : 'border-bottom:1px solid #0000000f'};font-size:17px">${content}</div>`;
  const toggle = `<span style="margin-left:auto;width:51px;height:31px;border-radius:16px;background:#F76B15;position:relative;flex:none"><span style="position:absolute;right:2px;top:2px;width:27px;height:27px;border-radius:50%;background:#fff;box-shadow:0 2px 4px rgba(0,0,0,.2)"></span></span>`;
  const place = (icon, n, s, last) => item(`${icon}<div><div>${n}</div><div style="font-size:12px;color:#8a817b">${s}</div></div>`, last);
  return `<div class="screen" style="width:${w}px;height:${h}px;background:#F2EFEC">
    ${full ? statusBar() : '<div style="height:14px"></div>'}
    <div style="display:flex;justify-content:center;align-items:center;position:relative;padding:12px 0 22px"><b style="font-size:17px">Meldingen</b><span style="position:absolute;right:20px;color:#F76B15;font-weight:600;font-size:17px">Klaar</span></div>
    ${grp(item(`<span style="width:30px;height:30px;border-radius:8px;background:#F76B15;display:flex;align-items:center;justify-content:center">${ico.bell(18, '#fff')}</span>Pushmeldingen${toggle}`, true), null, 'Je krijgt een melding zodra de stookcode voor een van je plaatsen verandert. We controleren elk uur.')}
    ${grp(item(`<span class="dot" style="background:#F27A1A"></span><span class="dot" style="background:#E23B3B;margin-left:-6px"></span>Code oranje en rood<span style="margin-left:auto">${ico.check(20, '#F76B15')}</span>`) +
      item(`<span class="dot" style="background:#E23B3B"></span>Alleen code rood`) +
      item(`Melding als het weer code geel wordt${toggle}`, true), 'Wanneer')}
    ${grp(place(ico.loc(18, '#F76B15'), 'Apeldoorn', 'Huidige locatie') + place(ico.pin(20, '#F76B15'), 'Epe', 'Gelderland') + place(ico.pin(20, '#F76B15'), 'Deventer', 'Overijssel', true), 'Plaatsen', 'Locaties worden afgerond op ongeveer 1 km naar de meldingsserver gestuurd en alleen gebruikt voor het stookadvies.')}
    ${grp(item(`Status<span style="margin-left:auto;color:#8a817b;font-size:15px">Aangemeld 11:42</span>`, true))}
    ${full ? '<div class="home-ind"></div>' : ''}</div>`;
}

// ------------------------------------------------------------------ iPad screens (1376 x 1032, landscape)
const IW = 1376, IH = 1032;
function ipad(k, selected, sheet) {
  const sideRow = (icon, n, s, sel) => `<div style="display:flex;gap:12px;align-items:center;padding:10px 14px;border-radius:12px;margin:0 10px;${sel ? 'background:#F76B15;color:#fff' : ''}">${sel ? icon.replace(/#F76B15/g, '#fff') : icon}<div><div style="font-size:17px">${n}</div><div style="font-size:12px;opacity:.7">${s}</div></div></div>`;
  const places = [['loc', 'Apeldoorn', 'Huidige locatie'], ['pin', 'Epe', 'Gelderland'], ['pin', 'Deventer', 'Overijssel'], ['pin', 'Den Burg', 'Texel']];
  const title = places.find((p) => p[1] === selected)[1];
  const next = { o: { k: 'y', t: 'Vandaag 18:00' }, r: { k: 'o', t: 'Morgen 06:00' }, y: { k: 'o', t: 'Morgen 00:00' } }[k];
  return `<div class="screen" style="width:${IW}px;height:${IH}px;display:flex">
    <div style="width:340px;background:#F4F0EC;border-right:1px solid #E7DFD7;position:relative">
      <div class="sb" style="padding:0 24px;height:32px;font-size:14px"><span>9:41</span><span>di 3 nov.</span></div>
      <div style="display:flex;justify-content:flex-end;padding:8px 22px">${ico.plus(24, '#F76B15')}</div>
      <div class="r" style="font-size:34px;font-weight:800;padding:2px 24px 18px">Stookwijzer</div>
      <div style="font-size:13px;color:#8a817b;font-weight:600;padding:0 24px 6px">Huidige locatie</div>
      ${sideRow(ico.loc(18, '#F76B15'), ...places[0].slice(1), selected === places[0][1])}
      <div style="font-size:13px;color:#8a817b;font-weight:600;padding:20px 24px 6px">Opgeslagen</div>
      ${places.slice(1).map((p) => sideRow(ico.pin(22, '#F76B15'), p[1], p[2], selected === p[1])).join('')}
      <div style="display:flex;gap:12px;align-items:center;padding:12px 24px;color:#F76B15;font-size:17px">${ico.plus(22, '#F76B15')}Plaats toevoegen</div>
    </div>
    <div style="flex:1;position:relative;overflow:hidden">
      <div class="sb" style="height:32px;padding:0 24px;justify-content:flex-end;font-size:14px">${statusBar().match(/<span class="sbi">[\s\S]*<\/span>/)[0]}</div>
      <div style="display:flex;justify-content:flex-end;gap:22px;padding:8px 28px">${ico.bell(24, '#F76B15')}${ico.info(25, '#F76B15')}</div>
      <div class="r" style="font-size:34px;font-weight:800;padding:2px 40px 18px">${title}</div>
      <div style="padding:0 40px;display:flex;flex-direction:column;gap:18px">
        <div style="display:flex;gap:18px;align-items:flex-start"><div style="flex:1">${hero(k, next, false)}</div>
          <div style="width:260px">${stats(1, STATS[k])}</div></div>
        ${forecast(SLOTS[k].concat(SLOTS[k].slice(0, 2).map((s) => ({ ...s, d: 'Vr', p: 1 })).slice(0, 1)))}
      </div>
      ${sheet ? '' : ''}
    </div>
    ${sheet ? `<div style="position:absolute;inset:0;background:rgba(20,10,5,.28)"></div>
      <div style="position:absolute;left:${(IW - 560) / 2}px;top:70px;width:560px;height:${IH - 140}px;border-radius:20px;overflow:hidden;box-shadow:0 30px 80px rgba(0,0,0,.3)">${settingsSheet(560, IH - 140, false)}</div>` : ''}
  </div>`;
}

// ------------------------------------------------------------------ device frames + slides
function iphoneFrame(inner, scale) {
  const bez = 14;
  return `<div style="width:${(PW + bez * 2) * scale}px;height:${(PH + bez * 2) * scale}px;position:relative;filter:drop-shadow(0 ${30 * scale}px ${50 * scale}px rgba(80,35,10,.30))">
    <div style="transform:scale(${scale});transform-origin:0 0;width:${PW + bez * 2}px;height:${PH + bez * 2}px;background:#1b1a1c;border-radius:76px;padding:${bez}px;box-shadow:inset 0 0 0 2px #3a383c, 0 0 0 1.5px #8d8890">
      <div style="width:${PW}px;height:${PH}px;border-radius:62px;overflow:hidden;position:relative">${inner}
        <div style="position:absolute;top:11px;left:50%;transform:translateX(-50%);width:124px;height:36px;border-radius:20px;background:#000"></div></div></div></div>`;
}
function ipadFrame(inner, scale) {
  const bez = 22;
  return `<div style="width:${(IW + bez * 2) * scale}px;height:${(IH + bez * 2) * scale}px;filter:drop-shadow(0 ${30 * scale}px ${60 * scale}px rgba(80,35,10,.28))">
    <div style="transform:scale(${scale});transform-origin:0 0;width:${IW + bez * 2}px;height:${IH + bez * 2}px;background:#1b1a1c;border-radius:56px;padding:${bez}px;box-shadow:inset 0 0 0 2px #3a383c, 0 0 0 2px #8d8890">
      <div style="width:${IW}px;height:${IH}px;border-radius:36px;overflow:hidden;position:relative">${inner}</div></div></div>`;
}

const BG = {
  warm: 'linear-gradient(170deg,#FFF8F1 0%,#FDE3CF 100%)',
  amber: 'linear-gradient(170deg,#FFF6E0 0%,#FFE2A8 100%)',
  red: 'linear-gradient(170deg,#FFF1EE 0%,#FFC9BF 100%)',
  peach: 'linear-gradient(170deg,#FFF4EA 0%,#FFD4B8 100%)',
};
function slide(w, h, bg, head, sub, device, top) {
  return `<div style="width:${w}px;height:${h}px;background:${bg};position:relative;overflow:hidden">
    <div style="position:absolute;width:${w * 1.3}px;height:${w * 1.3}px;left:${-w * 0.15}px;top:${h * 0.32}px;background:radial-gradient(circle,rgba(247,107,21,.16),transparent 60%)"></div>
    <div style="position:relative;text-align:center;padding:${top}px 30px 0">
      <div class="r" style="font-size:${w > 1000 ? 64 : 37}px;font-weight:900;color:#2A2320;letter-spacing:-.6px;line-height:1.08">${head}</div>
      <div style="font-size:${w > 1000 ? 28 : 17.5}px;color:#7D6A5F;margin-top:${w > 1000 ? 14 : 10}px;font-weight:500;line-height:1.35">${sub}</div></div>
    <div style="position:absolute;left:0;right:0;bottom:0;display:flex;justify-content:center">${device}</div></div>`;
}

// ------------------------------------------------------------------ promo
function promo(w, h) {
  const sq = w === h;
  return `<div style="width:${w}px;height:${h}px;background:linear-gradient(135deg,#FFF8F1 0%,#FDDCC4 100%);position:relative;overflow:hidden;display:flex;align-items:center;${sq ? 'flex-direction:column;justify-content:center;text-align:center' : 'padding-left:120px'}">
    <div style="position:absolute;width:900px;height:900px;${sq ? 'left:90px;top:300px' : 'right:-80px;top:90px'};background:radial-gradient(circle,rgba(247,107,21,.22),transparent 62%)"></div>
    <div style="position:relative;${sq ? '' : 'flex:1'}">
      <div style="display:flex;gap:26px;align-items:center;${sq ? 'justify-content:center' : ''}"><img src="ICON" style="width:${sq ? 120 : 132}px;height:${sq ? 120 : 132}px;border-radius:${sq ? 27 : 30}px;box-shadow:0 14px 30px rgba(247,107,21,.3)"/>
      <div class="r" style="font-size:${sq ? 64 : 72}px;font-weight:900;color:#2A2320;text-align:left">Stookwijzer</div></div>
      <div class="r" style="font-size:${sq ? 50 : 62}px;font-weight:800;color:#2A2320;margin-top:${sq ? 34 : 44}px;line-height:1.1">Kan ik vandaag<br>stoken?</div>
      <div style="font-size:${sq ? 26 : 30}px;color:#7D6A5F;margin-top:20px;line-height:1.4">Stookadvies van het RIVM voor jouw plek,<br>met widgets en pushmeldingen bij code rood.</div>
      <div style="display:flex;gap:14px;margin-top:34px;${sq ? 'justify-content:center' : ''}">${['y', 'o', 'r'].map((k) => `<span style="display:inline-flex;gap:10px;align-items:center;background:#fff;border-radius:30px;padding:12px 22px 12px 12px;font-weight:700;font-size:22px;color:${C[k].text};box-shadow:0 6px 16px rgba(0,0,0,.06)"><span style="width:38px;height:38px;border-radius:50%;background:${grad(k)};display:flex;align-items:center;justify-content:center">${ico[k](20)}</span>${C[k].title}</span>`).join('')}</div>
    </div>
    ${sq ? '' : `<div style="position:relative;margin-right:130px;margin-top:150px">${iphoneFrame(phone.home(), 0.92)}</div>`}
  </div>`;
}

// ------------------------------------------------------------------ render
(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const icon = 'data:image/png;base64,' + fs.readFileSync(process.argv[3]).toString('base64');
  const browser = await chromium.launch();
  const render = async (html, w, h, scale, file) => {
    const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: scale });
    await page.setContent(`<!doctype html><html><head><style>${css}</style></head><body>${html.replace(/ICON/g, icon)}</body></html>`, { waitUntil: 'load' });
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: path.join(OUT, file), type: 'png' });
    await page.close();
    console.log(file);
  };

  // iPhone 6.9" — 1320 x 2868 (440 x 956 @3x)
  const S = 0.86, top = 70;
  const iphoneSlides = [
    ['01', BG.warm, 'Kan ik vandaag<br>stoken?', 'Het stookadvies van het RIVM<br>voor jouw locatie.', phone.home()],
    ['02', BG.amber, 'Weet wat er komt', 'Verwachting per 6 uur, met wind<br>en luchtkwaliteit.', phone.forecast()],
    ['03', BG.red, 'Een seintje<br>bij code rood', 'Pushmelding zodra de code<br>voor jouw plek verandert.', phone.lock()],
    ['04', BG.peach, 'Altijd in beeld', 'Widgets voor je beginscherm<br>en toegangsscherm.', phone.widgets()],
    ['05', BG.warm, 'Al je plaatsen', 'Thuis, het vakantiehuis<br>of bij familie.', phone.places()],
    ['06', BG.amber, 'Jij bepaalt wanneer', 'Meldingen bij oranje en rood,<br>of alleen bij rood.', phone.notifications()],
  ];
  for (const [n, bg, h, s, scr] of iphoneSlides) {
    await render(slide(440, 956, bg, h, s, `<div style="margin-bottom:-135px">${iphoneFrame(scr, S)}</div>`, top), 440, 956, 3, `iPhone-6.9/iPhone_6.9_${n}.png`);
  }
  // Ruwe schermen (zonder mockup) — handig voor reviews of website
  for (const [n, , , , scr] of iphoneSlides) await render(scr, 440, 956, 3, `iPhone-6.9/raw/iPhone_raw_${n}.png`);

  // iPad 13" — 2752 x 2064 (1376 x 1032 @2x), liggend
  const ipadSlides = [
    ['01', BG.warm, 'Gemaakt voor iPad', 'Al je plaatsen in de zijbalk, het advies ernaast.', ipad('o', 'Apeldoorn')],
    ['02', BG.red, 'Code rood? Je ziet het meteen', 'Grote, duidelijke kleuren en een verwachting per 6 uur.', ipad('r', 'Deventer')],
    ['03', BG.amber, 'Meldingen die bij je passen', 'Kies zelf bij welke code je een seintje krijgt.', ipad('y', 'Epe', true)],
  ];
  for (const [n, bg, h, s, scr] of ipadSlides) {
    await render(slide(1376, 1032, bg, h, s, `<div style="margin-bottom:-40px">${ipadFrame(scr, 0.8)}</div>`, 56), 1376, 1032, 2, `iPad-13/iPad_13_${n}.png`);
  }
  for (const [n, , , , scr] of ipadSlides) await render(scr, 1376, 1032, 2, `iPad-13/raw/iPad_raw_${n}.png`);

  // Promo
  await render(promo(1920, 1080), 1920, 1080, 1, 'Promo/Promo_1920x1080.png');
  await render(promo(1080, 1080), 1080, 1080, 1, 'Promo/Promo_1080x1080.png');
  await render(`<div style="width:1200px;height:630px;overflow:hidden"><div style="transform:scale(.625);transform-origin:0 0">${promo(1920, 1008)}</div></div>`, 1200, 630, 1, 'Promo/Social_1200x630.png');

  await browser.close();
})();

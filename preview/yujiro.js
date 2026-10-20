// Yujiro Hanma for the browser preview. Timings match roblox/src/ReplicatedStorage/YujiroConfig.luau; distances are
// Roblox studs times S (the preview body is about 0.6 of a Roblox character). Loaded as a classic script before app.js,
// which calls window.YujiroPreview(api) once its scene, targets and helpers exist.
// No energy blasts: bare fists, muscle, air shockwaves, dust and cracked ground. The Demon Back is built from muscle.
window.YujiroPreview = function (A) {
  'use strict';
  const T = A.T, scene = A.scene, camera = A.camera, targets = A.targets, basePos = A.basePos;
  const $ = id => document.getElementById(id);
  const clamp = T.MathUtils.clamp, mix = T.MathUtils.lerp;
  const ease = x => { x = clamp(x, 0, 1); return x * x * (3 - 2 * x); };
  const outP = (x, p = 3) => 1 - Math.pow(1 - clamp(x, 0, 1), p);
  const seg = (a, from, to) => clamp((a - from) / (to - from), 0, 1);
  const bump = (a, from, to) => Math.sin(seg(a, from, to) * Math.PI);
  const rnd = (a = -1, b = 1) => a + Math.random() * (b - a);
  const V = (x = 0, y = 0, z = 0) => new T.Vector3(x, y, z);
  const S = .6, EYE = 2.1, UP = V(0, 1, 0);
  const CFG = {
    // Q: stance .25, waiting until 2.5; on a read: deflect .15, uppercut to .5, hold to .9. Fail: .4 recovery.
    q: { enter: .25, window: 2.5, arc: Math.cos(80 * Math.PI / 180), guard: .3, deflect: .15, hitAt: .3, upperEnd: .5, holdEnd: .9,
      damage: 30, knock: 12 * S, stagger: .8, basic: 1.15, buffDur: .5, fail: .4, cd: 18, slow: 60 },
    // E: crouch .2, dash to .5 (18 studs), body .5-.7, hook .7-.95, axe kick .95-1.35, recovery to 1.75.
    e: { crouch: .2, dashEnd: .5, dash: 18 * S, reach: 3.0, width: 1.3, stop: 2.0, body: .62, hook: .84, kick: 1.21, kickEnd: 1.35, end: 1.75,
      d1: 10, d2: 15, d3: 20, escape: 3.2, cd: 15 },
    // R: serious face .5, Demon Back to 1.0, capture to 1.5, then the beating; total 5.5 s.
    r: { freeze: .5, demon: 1.0, capture: 1.5, range: 25 * S, cone: Math.cos(15 * Math.PI / 180), stop: 2.0, grab: 1.32,
      blow: 1.66, slap: 2.05, rush: [2.4, 2.56, 2.72, 2.88], lift: 3.0, throw: 3.5, release: 3.62, final: 4.0, punch: 4.12, recover: 4.5, end: 5.5,
      d1: 15, d2: 15, d3: 5, d4: 50, liftH: 3 * S, guard: .7, failCd: 30, down: .8 },
  };
  const WIND = 0xf4f7ff, GOLD = 0xfff2d8, RED = 0xb0141a;

  // ---------- shared assets ----------
  function canvasTex(size, draw) {
    const c = document.createElement('canvas'); c.width = c.height = size; draw(c.getContext('2d'), size);
    const t = new T.CanvasTexture(c); t.colorSpace = T.SRGBColorSpace; return t;
  }
  const dustTex = canvasTex(128, (g, s) => {
    const r = g.createRadialGradient(s / 2, s / 2, 0, s / 2, s / 2, s / 2);
    r.addColorStop(0, 'rgba(255,255,255,.85)'); r.addColorStop(.45, 'rgba(255,255,255,.4)'); r.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = r; g.fillRect(0, 0, s, s);
  });
  const glowTex = canvasTex(128, (g, s) => {
    const r = g.createRadialGradient(s / 2, s / 2, 0, s / 2, s / 2, s / 2);
    r.addColorStop(0, 'rgba(255,255,255,1)'); r.addColorStop(.15, 'rgba(255,255,255,.7)'); r.addColorStop(.4, 'rgba(255,255,255,.18)'); r.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = r; g.fillRect(0, 0, s, s);
  });
  // A soft streak: bright along its length, transparent at both ends and edges (wind lines and air trails).
  const streakTex = canvasTex(128, (g, s) => {
    const r = g.createLinearGradient(0, 0, s, 0); r.addColorStop(0, 'rgba(255,255,255,0)'); r.addColorStop(.25, 'rgba(255,255,255,.9)'); r.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = r; g.fillRect(0, s * .42, s, s * .16);
  });
  function seeded(seed) { return () => { seed |= 0; seed = seed + 0x6D2B79F5 | 0; let t = Math.imul(seed ^ seed >>> 15, 1 | seed); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
  function rockGeo(seed) {
    const g = new T.IcosahedronGeometry(1, 1), p = g.attributes.position, r = seeded(seed), cache = new Map();
    for (let i = 0; i < p.count; i++) {
      const k = Math.round(p.getX(i) * 997) + ',' + Math.round(p.getY(i) * 997) + ',' + Math.round(p.getZ(i) * 997);
      if (!cache.has(k)) cache.set(k, .7 + r() * .5);
      const s = cache.get(k); p.setXYZ(i, p.getX(i) * s, p.getY(i) * s * .8, p.getZ(i) * s);
    }
    g.computeVertexNormals(); return g;
  }
  const ROCKS = Array.from({ length: 6 }, (_, i) => rockGeo(31 + i * 7));
  const rockMats = [0x857b70, 0x9a9083, 0x6e665d].map(c => new T.MeshStandardMaterial({ color: c, roughness: .95, flatShading: true }));
  const STREAK_GEO = new T.PlaneGeometry(1, 1);
  const SHARED = new Set([...ROCKS, ...rockMats, STREAK_GEO]);

  // ---------- effect bookkeeping (everything here is removed on reset) ----------
  const fxs = [], live = new Set();
  function kill(o) {
    if (!o) return; o.parent?.remove(o); live.delete(o);
    o.traverse(x => {
      if (x.geometry && !x.isSprite && !SHARED.has(x.geometry)) x.geometry.dispose();
      for (const m of [].concat(x.material || [])) if (!SHARED.has(m)) m.dispose();
    });
  }
  function fx(obj, life, update, done) { if (obj && !obj.parent) scene.add(obj); const e = { obj, born: A.time, life, update, done }; fxs.push(e); return e; }
  function keep(obj, parent = scene) { parent.add(obj); live.add(obj); return obj; }
  function sprite(tex, color, opacity = 1, additive = false) {
    return new T.Sprite(new T.SpriteMaterial({ map: tex, color, transparent: true, depthWrite: false, opacity, blending: additive ? T.AdditiveBlending : T.NormalBlending }));
  }
  function dust(pos, size, life, vel = null, color = 0xe2dbd0, opacity = .75) {
    const s = sprite(dustTex, color, opacity); s.position.copy(pos); s.scale.setScalar(size * .5);
    const v = vel ? vel.clone() : V(0, .4, 0);
    return fx(s, life, (o, u, dt) => { o.position.addScaledVector(v, dt); v.multiplyScalar(Math.pow(.25, dt)); o.scale.setScalar(size * (.5 + u * 1.1)); o.material.opacity = opacity * (1 - u) * Math.min(1, .25 + u * 8); });
  }
  function glowAt(pos, color, size, life, grow = 2, opacity = 1) {
    const s = sprite(glowTex, color, opacity, true); s.position.copy(pos); s.scale.setScalar(size);
    return fx(s, life, (o, u) => { o.scale.setScalar(size * (1 + u * grow)); o.material.opacity = opacity * (1 - u); });
  }
  function rock(size) { const m = new T.Mesh(ROCKS[Math.floor(Math.random() * ROCKS.length)], rockMats[Math.floor(Math.random() * 3)]); m.scale.setScalar(size); m.rotation.set(rnd(0, 6), rnd(0, 6), rnd(0, 6)); m.castShadow = true; return m; }
  function throwRock(pos, vel, size, life = 1.6) {
    const m = rock(size); scene.add(m); m.position.copy(pos);
    const v = vel.clone(), spin = V(rnd(), rnd(), rnd()).multiplyScalar(9), floor = size * .55;
    let rest = false;
    return fx(m, life, (o, u, dt) => {
      if (!rest) {
        v.y -= 24 * dt; o.position.addScaledVector(v, dt); o.rotation.x += spin.x * dt; o.rotation.y += spin.y * dt;
        if (o.position.y < floor) { o.position.y = floor; if (v.y < -4) { v.y *= -.3; v.x *= .5; v.z *= .5; } else rest = true; }
      }
      if (u > .7) o.scale.setScalar(size * (1 - (u - .7) / .3));
    });
  }
  // An expanding ring of air around `axis` through `center`.
  function ring(center, axis, radius, color, life, thickness = .08, opacity = .9, from = .3) {
    const m = new T.Mesh(new T.TorusGeometry(1, thickness, 6, 72), new T.MeshBasicMaterial({ color, transparent: true, opacity, depthWrite: false }));
    m.position.copy(center); m.quaternion.setFromUnitVectors(V(0, 0, 1), axis.clone().normalize());
    return fx(m, life, (o, u) => { const r = mix(from, radius, outP(u * 1.25, 3)); o.scale.set(r, r, 1); o.material.opacity = opacity * (1 - u) * (1 - u * .3); });
  }
  // The air pressure front: a pale sphere that blows outward and thins.
  function pressure(center, radius, life, color = WIND, opacity = .35) {
    const m = new T.Mesh(new T.SphereGeometry(1, 32, 20), new T.MeshBasicMaterial({ color, transparent: true, opacity, depthWrite: false, side: T.DoubleSide }));
    m.position.copy(center);
    return fx(m, life, (o, u) => { o.scale.setScalar(.3 + radius * outP(u, 3)); o.material.opacity = opacity * (1 - u); });
  }
  // A wind line: a streak plane facing the camera's side, sliding along `dir`.
  function streak(pos, dir, length, speed, life, color = WIND, width = .05, opacity = .85) {
    const m = new T.Mesh(STREAK_GEO, new T.MeshBasicMaterial({ map: streakTex, color, transparent: true, opacity, depthWrite: false, side: T.DoubleSide, blending: T.AdditiveBlending }));
    const d = dir.clone().normalize();
    m.position.copy(pos);
    const side = Math.abs(d.y) < .95 ? V().crossVectors(d, UP).normalize() : V(1, 0, 0);
    const n = V().crossVectors(side, d);
    m.quaternion.setFromRotationMatrix(new T.Matrix4().makeBasis(d, n, side));
    m.scale.set(length, width, 1);
    return fx(m, life, (o, u, dt) => { o.position.addScaledVector(d, speed * dt); o.material.opacity = opacity * (1 - u); o.scale.x = length * (1 - .4 * u); });
  }
  function sparks(center, n, speed, life, color = GOLD) {
    for (let i = 0; i < n; i++) { const d = V(rnd(), rnd(-.3, 1), rnd()).normalize(); streak(center.clone().addScaledVector(d, .1), d, rnd(.25, .6), speed * rnd(.5, 1.2), life * rnd(.6, 1.2), color, .035, 1); }
  }
  // Radial ground cracks with a scorched centre; longer along `dir` when given.
  function cracks(center, radius, n, life, dir = null, bias = 0) {
    const g = new T.Group(); g.position.copy(center).setY(.025);
    const mk = (geo, color, op) => { const m = new T.Mesh(geo, new T.MeshBasicMaterial({ color, transparent: true, opacity: op, depthWrite: false })); m.rotation.x = -Math.PI / 2; g.add(m); return m; };
    const pit = mk(new T.CircleGeometry(radius * .28, 32), 0x2c2622, .8);
    mk(new T.RingGeometry(radius * .25, radius * .42, 32), 0x4b433c, .55).position.y = .004;
    const lines = [];
    for (let i = 0; i < n; i++) {
      const a = i / n * Math.PI * 2 + rnd(0, .35), d = V(Math.cos(a), 0, Math.sin(a));
      let len = radius * rnd(.5, 1); if (dir) len *= 1 + Math.max(0, d.dot(dir)) * bias;
      // Two kinked segments per crack, thinner toward the tip.
      let from = d.clone().multiplyScalar(radius * .18), heading = a;
      for (let k = 0; k < 3; k++) {
        const l = len / 3, to = from.clone().add(V(Math.cos(heading), 0, Math.sin(heading)).multiplyScalar(l));
        const w = (.14 - k * .035) * (radius / 6 + .5);
        const m = new T.Mesh(new T.PlaneGeometry(l, w), new T.MeshBasicMaterial({ color: 0x1d1917, transparent: true, opacity: .9, depthWrite: false }));
        m.rotation.x = -Math.PI / 2; m.rotation.z = -heading; m.position.set((from.x + to.x) / 2, .006 + k * .001, (from.z + to.z) / 2); g.add(m);
        lines.push({ m, k }); from = to; heading += rnd(-.45, .45);
      }
    }
    for (const l of lines) l.m.scale.x = .001;
    return fx(g, life, (o, u) => {
      const age = u * life, fade = 1 - seg(u, .72, 1);
      for (const l of lines) { l.m.scale.x = Math.max(.001, ease(seg(age, l.k * .045, l.k * .045 + .08))); l.m.material.opacity = .9 * fade; }
      pit.material.opacity = .8 * fade; o.children[1].material.opacity = .55 * fade;
    });
  }
  function dustRing(center, radius, n, life, rocks = 0, dir = null) {
    const feet = center.clone().setY(.35);
    for (let i = 0; i < n; i++) {
      const a = i / n * Math.PI * 2 + rnd(0, .3), d = V(Math.cos(a), 0, Math.sin(a)), push = dir ? 1 + Math.max(0, d.dot(dir)) * 1.6 : 1;
      dust(feet.clone().addScaledVector(d, .8), rnd(1.6, 2.8), life * rnd(.8, 1.2), d.clone().multiplyScalar(radius * 2.2 * push).setY(rnd(.4, 1.6)), 0xcfc6ba, .78);
    }
    for (let i = 0; i < rocks; i++) {
      let d = V(rnd(), 0, rnd()).normalize(); if (dir && Math.random() < .65) d = dir.clone().add(d.multiplyScalar(.5)).normalize();
      throwRock(feet.clone().addScaledVector(d, rnd(.5, 1.5)), d.multiplyScalar(rnd(7, 16)).setY(rnd(4, 9)), rnd(.07, .2), rnd(1.2, 1.9));
    }
  }


  // ---------- sound: synthesised with WebAudio, follows the preview's sound toggle ----------
  let master = null, noiseBuffer = null;
  function ac() {
    const c = A.audio; if (A.muted || !c) return null;
    if (!master || master.context !== c) { master = c.createGain(); master.gain.value = .55; master.connect(c.destination); }
    return c;
  }
  function noiseBuf(c) {
    if (noiseBuffer && noiseBuffer.sampleRate === c.sampleRate) return noiseBuffer;
    const b = c.createBuffer(1, c.sampleRate * 2, c.sampleRate), d = b.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
    return noiseBuffer = b;
  }
  function envelope(g, at, attack, dur, vol) { g.gain.setValueAtTime(.0001, at); g.gain.exponentialRampToValueAtTime(vol, at + attack); g.gain.exponentialRampToValueAtTime(.0001, at + dur); }
  function tone(o) {
    const c = ac(); if (!c) return; const at = c.currentTime + (o.at || 0);
    const osc = c.createOscillator(), g = c.createGain(); osc.type = o.type || 'sine';
    osc.frequency.setValueAtTime(o.f0, at); if (o.f1) osc.frequency.exponentialRampToValueAtTime(o.f1, at + o.dur);
    envelope(g, at, o.attack || .01, o.dur, o.vol || .3); osc.connect(g).connect(master); osc.start(at); osc.stop(at + o.dur + .05);
  }
  function noise(o) {
    const c = ac(); if (!c) return; const at = c.currentTime + (o.at || 0);
    const src = c.createBufferSource(), f = c.createBiquadFilter(), g = c.createGain(); src.buffer = noiseBuf(c); src.loop = true;
    f.type = o.filter || 'lowpass'; f.Q.value = o.q || .8; f.frequency.setValueAtTime(o.f0, at); if (o.f1) f.frequency.exponentialRampToValueAtTime(o.f1, at + o.dur);
    envelope(g, at, o.attack || .005, o.dur, o.vol || .3); src.connect(f).connect(g).connect(master); src.start(at, Math.random()); src.stop(at + o.dur + .05);
  }
  // A shouted syllable: a buzzy voice-like formant over a pitch slide (the words themselves are on screen).
  function shoutTone(f0, f1, dur, vol = .3, at = 0) {
    tone({ type: 'sawtooth', f0, f1, dur, vol: vol * .5, attack: .03, at });
    noise({ filter: 'bandpass', f0: 900, f1: 1300, q: 3, dur, vol: vol * .4, attack: .03, at });
    noise({ filter: 'bandpass', f0: 2400, q: 5, dur: dur * .8, vol: vol * .2, attack: .02, at });
  }
  const sfx = {
    heartbeat() { for (const at of [0, .28]) { tone({ f0: 54, f1: 38, dur: .2, vol: .8, at }); noise({ f0: 150, dur: .12, vol: .25, at }); } },
    // A low, closed-mouth laugh: four short voiced pulses falling in pitch.
    laugh(at = 0) { for (let i = 0; i < 4; i++) { const t = at + i * .16; tone({ type: 'sawtooth', f0: 104 - i * 4, f1: 88 - i * 4, dur: .12, vol: .22, attack: .02, at: t }); noise({ filter: 'bandpass', f0: 520, q: 2.5, dur: .1, vol: .12, attack: .02, at: t }); } },
    stance() { noise({ filter: 'bandpass', f0: 300, f1: 160, q: 1, dur: .3, vol: .25, attack: .05 }); tone({ f0: 70, f1: 52, dur: .3, vol: .3 }); },
    parry() { noise({ filter: 'highpass', f0: 2400, dur: .08, vol: .55 }); tone({ type: 'triangle', f0: 620, f1: 260, dur: .12, vol: .35 }); tone({ f0: 140, f1: 70, dur: .15, vol: .5 }); },
    whoosh() { noise({ filter: 'bandpass', f0: 600, f1: 2200, q: .8, dur: .18, vol: .35 }); },
    dash() { noise({ filter: 'bandpass', f0: 500, f1: 2200, q: .7, dur: .3, vol: .5 }); tone({ f0: 80, f1: 46, dur: .22, vol: .5 }); },
    body() { tone({ f0: 95, f1: 42, dur: .2, vol: .75 }); noise({ f0: 600, f1: 140, dur: .18, vol: .5 }); },
    jab() { tone({ f0: 120, f1: 50, dur: .16, vol: .6 }); noise({ f0: 1700, f1: 300, dur: .16, vol: .45 }); },
    slap() { noise({ filter: 'highpass', f0: 1900, dur: .07, vol: .8 }); noise({ filter: 'bandpass', f0: 3200, q: 2, dur: .05, vol: .4 }); tone({ f0: 200, f1: 90, dur: .08, vol: .3 }); },
    thud() { tone({ f0: 120, f1: 44, dur: .25, vol: .6 }); noise({ f0: 700, f1: 200, dur: .2, vol: .4 }); },
    crack() { noise({ filter: 'highpass', f0: rnd(1500, 2600), dur: .18, vol: .25 }); noise({ f0: 500, f1: 120, dur: .3, vol: .25 }); },
    impact() { noise({ f0: 2600, f1: 70, dur: 1.2, vol: 1 }); tone({ f0: 90, f1: 28, dur: 1, vol: 1 }); tone({ type: 'triangle', f0: 240, f1: 60, dur: .3, vol: .3 }); noise({ filter: 'highpass', f0: 3200, dur: .15, vol: .25 }); },
    boom() { tone({ f0: 48, f1: 26, dur: 1.3, vol: .9, attack: .04 }); noise({ f0: 260, f1: 50, dur: 1.1, vol: .5, attack: .04 }); },
    lift() { noise({ filter: 'bandpass', f0: 260, f1: 520, q: 1, dur: .5, vol: .25, attack: .1 }); },
    exhale() { noise({ filter: 'bandpass', f0: 1400, f1: 500, q: .9, dur: .9, vol: .2, attack: .1 }); },
  };
  // Silence before the last punch: the mix drops away for a moment, then comes back with the hit.
  function duck(dur) {
    const c = ac(); if (!c) return; const g = master.gain, now = c.currentTime;
    g.cancelScheduledValues(now); g.setValueAtTime(g.value, now); g.linearRampToValueAtTime(.03, now + .08); g.setValueAtTime(.03, now + dur); g.linearRampToValueAtTime(.55, now + dur + .03);
  }
  function unduck() { const c = A.audio; if (!c || !master) return; const g = master.gain; g.cancelScheduledValues(c.currentTime); g.setValueAtTime(.55, c.currentTime); }

  // ---------- screen overlay: vignette, red pressure, flash, label, called names ----------
  const overlay = document.createElement('div'); overlay.id = 'yjOverlay';
  overlay.innerHTML = '<i class="yv"></i><i class="yr"></i><i class="yf"></i><b class="yt"></b><b class="ys"></b><b class="yl"></b>'; document.body.append(overlay);
  const [ovV, ovR, ovF, ovT, ovS, ovL] = overlay.children;
  let callText = '', callSub = '', callAt = -9, callLife = 0;
  function call(text, life, sub = '') { callText = text; callSub = sub; callAt = A.time; callLife = life; }

  // ---------- test panel ----------
  const panel = document.createElement('div'); panel.id = 'yjPanel'; panel.hidden = true;
  panel.innerHTML = '<button data-a="front">정면 주먹 받기 · F</button><button data-a="back">뒤에서 주먹 받기 · B</button><button data-a="proj">정면 투사체 받기 · G</button>'
    + '<button data-a="view">시점: 시전자 · V</button><button data-a="killT">대상 처치 테스트 · K</button><button data-a="gone">대상 이탈·삭제 테스트 · L</button><button data-a="killMe">시전 중 사망 테스트</button>';
  document.body.append(panel);
  let viewMode = 'auto';
  const VIEW_LABEL = { auto: '시전자', victim: '피격자', spectator: '관전자' };
  function refreshPanel() { panel.querySelector('[data-a=view]').textContent = '시점: ' + VIEW_LABEL[viewMode] + ' · V'; }
  panel.addEventListener('click', e => {
    const a = e.target.closest('button')?.dataset.a; if (!a) return;
    if (a === 'front' || a === 'back' || a === 'proj') enemyAttack(a);
    if (a === 'view') cycleView();
    if (a === 'killT') killTarget();
    if (a === 'gone') targetGone();
    if (a === 'killMe') casterDies();
    e.target.blur();
  });
  function cycleView() { viewMode = viewMode === 'auto' ? 'victim' : viewMode === 'victim' ? 'spectator' : 'auto'; refreshPanel(); A.toast('시점 · ' + VIEW_LABEL[viewMode] + (viewMode === 'auto' ? ' (배면귀는 짧은 3인칭 컷)' : viewMode === 'victim' ? ' (맞는 쪽 눈으로 봅니다)' : ' (실제 3D 전투를 옆에서)')); }
  window.addEventListener('keydown', e => {
    if (!active || e.repeat) return;
    const k = { KeyF: 'front', KeyB: 'back', KeyG: 'proj' }[e.code];
    if (k) enemyAttack(k); else if (e.code === 'KeyV') cycleView(); else if (e.code === 'KeyK') killTarget(); else if (e.code === 'KeyL') targetGone();
  });

  // ---------- first-person arms: huge bare arms, veins, a wrist joint, jointed fingers ----------
  const mat = (color, roughness = .55, extra = {}) => new T.MeshStandardMaterial({ color, roughness, metalness: 0, ...extra });
  const mSkin = mat(0xc98a62, .5), mMuscle = mat(0xd39572, .42), mShade = mat(0x8e5a3c, .6), mVein = mat(0x7d4a3a, .45);
  const mPants = mat(0x18181d, .75), mShoe = mat(0x2a2420, .6), mHair = mat(0xb3161b, .5, { emissive: 0x3a0002, emissiveIntensity: .3 });
  const mRelief = mat(0xd39572, .42), mDark = mat(0x2a120c, .9), mTeeth = mat(0xeee4d4, .4), mEye = mat(0xffffff, .3);
  function part(geo, material, parent, pos, rot, scale) {
    const m = new T.Mesh(geo, material); parent.add(m); if (pos) m.position.set(...pos); if (rot) m.rotation.set(...rot); if (scale) m.scale.set(...scale);
    m.renderOrder = 102; m.frustumCulled = false; return m;
  }
  const FING = [[.072, .078, .058, .048], [.025, .086, .062, .052], [-.022, .082, .06, .048], [-.068, .066, .05, .042]];
  function makeArm(side) {
    const g = new T.Group(); camera.add(g); g.visible = false;
    const hand = new T.Group(); g.add(hand);
    part(new T.BoxGeometry(.215, .2, .11), mSkin, hand, [0, .1, 0]);
    part(new T.SphereGeometry(.105, 14, 10), mSkin, hand, [0, .1, .02], null, [1.02, .95, .62]);
    part(new T.CapsuleGeometry(.03, .17, 4, 10), mShade, hand, [0, .2, .045], [0, 0, Math.PI / 2]);
    const fingers = [];
    for (let i = 0; i < 4; i++) {
      const [x, a, b, c] = FING[i];
      const j1 = new T.Group(); hand.add(j1); j1.position.set(-side * x, .2, 0);
      part(new T.CapsuleGeometry(.031, a - .02, 4, 10), mSkin, j1, [0, a / 2, 0]);
      const j2 = new T.Group(); j1.add(j2); j2.position.y = a;
      part(new T.CapsuleGeometry(.029, b - .02, 4, 10), mSkin, j2, [0, b / 2, 0]);
      const j3 = new T.Group(); j2.add(j3); j3.position.y = b;
      part(new T.CapsuleGeometry(.026, c - .02, 4, 10), mSkin, j3, [0, c / 2, 0]);
      fingers.push({ j1, j2, j3 });
    }
    const thumb = new T.Group(); hand.add(thumb); thumb.position.set(-side * .105, .04, -.03);
    part(new T.CapsuleGeometry(.035, .06, 4, 10), mSkin, thumb, [0, .045, 0]);
    const t2 = new T.Group(); thumb.add(t2); t2.position.y = .09;
    part(new T.CapsuleGeometry(.031, .05, 4, 10), mSkin, t2, [0, .035, 0]);
    // Forearm: wide at the elbow, cords of muscle and two raised veins.
    part(new T.CylinderGeometry(.105, .16, .9, 22), mSkin, g, [0, -.5, -.005]);
    const muscles = [];
    for (const [x, y, z, sx, sy, sz] of [[.08, -.6, .065, .09, .28, .085], [-.005, -.44, .09, .08, .23, .075], [-.085, -.58, -.06, .09, .26, .08], [.02, -.78, -.035, .11, .19, .11]]) {
      const m = part(new T.SphereGeometry(1, 18, 12), mMuscle, g, [side * x, y, z], null, [sx, sy, sz]);
      muscles.push({ m, base: V(sx, sy, sz) });
    }
    const veins = [part(new T.CapsuleGeometry(.011, .5, 3, 6), mVein, g, [side * .07, -.42, .12], [.08, 0, side * .12]), part(new T.CapsuleGeometry(.009, .34, 3, 6), mVein, g, [-side * .05, -.36, .125], [.05, 0, -side * .2])];
    part(new T.SphereGeometry(.165, 18, 12), mSkin, g, [0, -.98, -.01]);
    const up = new T.Group(); camera.add(up); up.visible = false;
    const upper = part(new T.CylinderGeometry(.22, .18, 1, 22), mSkin, up);
    const bicep = part(new T.SphereGeometry(1, 18, 12), mMuscle, up);
    const tricep = part(new T.SphereGeometry(1, 16, 10), mShade, up);
    const vein = part(new T.CapsuleGeometry(.013, .4, 3, 6), mVein, up);
    const deltoid = part(new T.SphereGeometry(.32, 20, 14), mSkin, up);
    g.traverse(o => { o.castShadow = false; o.receiveShadow = false; }); up.traverse(o => { o.castShadow = false; });
    return { g, up, hand, upper, bicep, tricep, vein, deltoid, side, fingers, thumb, t2, muscles, veins };
  }
  const arms = { r: makeArm(1), l: makeArm(-1) };
  // Poses in camera space: wrist, forearm direction, palm normal, curls (index..little, thumb), flex 0..1, shoulder, wrist bend.
  const pose = (pos, fin, palm, curl, flex = 0, sh = [1.05, -1.18, .1], wr = 0) => ({ pos: V(...pos), fin: V(...fin), palm: V(...palm), curl: typeof curl === 'number' ? [curl, curl, curl, curl, curl] : curl.slice(), flex, sh: V(...sh), wr });
  const mirror = p => ({ pos: V(-p.pos.x, p.pos.y, p.pos.z), fin: V(-p.fin.x, p.fin.y, p.fin.z), palm: V(-p.palm.x, p.palm.y, p.palm.z), curl: p.curl.slice(), flex: p.flex, sh: V(-p.sh.x, p.sh.y, p.sh.z), wr: p.wr });
  function lerpPose(a, b, k) {
    if (k <= 0) return a; if (k >= 1) return b;
    return { pos: a.pos.clone().lerp(b.pos, k), fin: a.fin.clone().lerp(b.fin, k), palm: a.palm.clone().lerp(b.palm, k), curl: a.curl.map((c, i) => mix(c, b.curl[i], k)), flex: mix(a.flex, b.flex, k), sh: a.sh.clone().lerp(b.sh, k), wr: mix(a.wr, b.wr, k) };
  }
  const OPEN = [.06, .05, .07, .09, .1], CLAW = [.5, .52, .55, .58, .35];
  const REST = pose([.5, -.56, -.95], [-.14, .42, -1], [-1, -.25, 0], [.74, .74, .77, .8, .55], .2, [1.05, -1.22, .1]);
  const L_REST = mirror(REST);
  // Q stance: right hand loose by the waist, left hand open in front, palm out.
  const Q_WAIST = pose([.66, -.98, -.6], [-.08, .75, -.65], [-.95, -.1, -.3], CLAW, .35, [1.08, -1.26, .16]);
  const L_FRONT = pose([-.24, -.42, -1.02], [.06, .92, -.38], [.05, -.25, -1], OPEN, .45, [-1.02, -1.16, .08], -.25);
  const L_DEFLECT = pose([-.82, -.22, -.88], [-.55, .8, -.25], [-.95, .05, -.35], OPEN, .9, [-1.12, -1.08, .22], -.3);
  const R_UP_COCK = pose([.56, -1.08, -.62], [-.18, .95, -.25], [-.95, 0, -.3], 1, 1, [1.1, -1.3, .22]);
  const R_UPPER = pose([.12, .02, -1.08], [-.05, 1, -.28], [-.9, .1, -.45], 1, 1, [.76, -.86, -.16]);
  // E: crouch, left body blow, right hook across the face.
  const E_CROUCH_R = pose([.6, -.72, -.7], [-.2, .5, -.85], [-.8, -.5, 0], 1, .85, [1.1, -1.22, .25]);
  const E_CROUCH_L = pose([-.46, -.6, -.86], [.2, .5, -.85], [.8, -.4, 0], 1, .7, [-1.05, -1.15, .15]);
  const L_BODY = pose([-.1, -.66, -1.38], [.06, .12, -1], [.4, -.9, 0], 1, 1, [-.74, -1.08, -.36]);
  const R_HOOK_COCK = pose([1.02, -.32, -.6], [-.5, .32, -.8], [-.3, -1, 0], 1, 1, [1.16, -1.06, .36]);
  const R_HOOK = pose([-.18, -.2, -1.12], [-.95, .12, -.3], [0, -1, 0], 1, 1, [.84, -.98, -.26]);
  // R: grab, body blow, slap, rush, lift, throw, the last punch.
  const L_REACH = pose([-.16, -.26, -1.36], [.05, .3, -1], [.3, -.2, -.95], CLAW, .8, [-.8, -1.0, -.22], -.35);
  const L_GRAB = pose([-.12, -.3, -1.22], [.05, .34, -1], [.3, -.3, -.9], [.96, .96, .96, .96, .82], 1, [-.82, -1.02, -.18], .2);
  const L_TUG = pose([-.22, -.36, -.98], [.08, .4, -.95], [.3, -.3, -.9], [.98, .98, .98, .98, .85], 1, [-.92, -1.08, 0], .25);
  const R_LOW_COCK = pose([.86, -.78, -.55], [-.3, .45, -.85], [-.5, -.8, 0], 1, 1, [1.18, -1.2, .4]);
  const R_BLOW = pose([.08, -.62, -1.36], [0, .14, -1], [-.3, -1, 0], 1, 1, [.74, -1.06, -.36]);
  const R_SLAP_WIND = pose([1.0, -.12, -.52], [-.25, .62, -.75], [-.98, .05, -.2], OPEN, .7, [1.16, -1.0, .36], -.55);
  const R_SLAP = pose([-.08, -.2, -1.15], [-.86, .36, -.36], [-.9, 0, -.4], OPEN, 1, [.8, -.96, -.26], .35);
  const R_JAB = pose([.05, -.2, -1.42], [0, .08, -1], [0, -1, 0], 1, 1, [.62, -.9, -.42]);
  const R_LIFT = pose([.4, .26, -1.25], [-.08, .95, -.3], [0, .35, -1], [.35, .38, .42, .45, .25], 1, [.95, -.86, 0], -.6);
  const R_THROW = pose([.28, .12, -1.42], [0, .65, -.78], [0, -.1, -1], OPEN, 1, [.7, -.86, -.4], -.7);
  const R_WIND = pose([1.02, -.42, -.32], [-.5, .42, -.75], [-.2, -1, 0], 1, 1, [1.22, -1.06, .5]);
  const R_FINAL = pose([.08, -.52, -1.48], [0, -.28, -1], [0, -1, .2], 1, 1, [.6, -.96, -.42]);
  const R_LOWER = pose([.45, -.78, -.9], [-.1, .2, -1], [-.9, -.3, 0], .9, .4, [1.05, -1.26, .12]);
  const _m = new T.Matrix4(), _x = V(), _y = V(), _z = V(), _q = new T.Quaternion();
  let meleeFov = 0;
  function poseArm(arm, P, show = true) {
    const vis = show && active && fp; arm.g.visible = arm.up.visible = vis; if (!vis) return;
    const ratio = clamp(camera.aspect, .55, 1), sc = mix(.82, 1, ratio);
    arm.g.position.copy(P.pos); arm.g.position.x *= ratio;
    _y.copy(P.fin).normalize(); _z.copy(P.palm).normalize().negate(); _z.addScaledVector(_y, -_z.dot(_y)).normalize(); _x.crossVectors(_y, _z);
    _m.makeBasis(_x, _y, _z); arm.g.quaternion.setFromRotationMatrix(_m); arm.g.scale.setScalar(sc);
    arm.hand.rotation.set(-(P.wr || 0), 0, 0);
    for (let i = 0; i < 4; i++) {
      const f = arm.fingers[i], c = P.curl[i];
      f.j1.rotation.set(-c * 1.5, 0, 0); f.j2.rotation.x = -c * 1.7; f.j3.rotation.x = -c * 1.15;
    }
    arm.thumb.rotation.set(-.3 - P.curl[4] * .75, 0, arm.side * (.85 - P.curl[4] * .7)); arm.t2.rotation.set(-P.curl[4] * .9, 0, -arm.side * P.curl[4] * .5);
    for (const mu of arm.muscles) mu.m.scale.copy(mu.base).multiplyScalar(1 + .24 * P.flex);
    for (const v of arm.veins) v.scale.set(1 + .6 * P.flex, 1, 1 + .6 * P.flex);
    // Shoulder -> elbow -> wrist as one chain: the elbow sits behind the wrist along the forearm, the upper arm reaches the shoulder.
    const elbow = arm.g.position.clone().addScaledVector(_y, -.98 * sc);
    const sh = P.sh.clone(); sh.x *= mix(.85, 1, ratio); sh.y += .05 * P.flex;
    const d = sh.clone().sub(elbow), len = d.length(); d.normalize();
    _q.setFromUnitVectors(UP, d);
    arm.upper.position.copy(elbow).addScaledVector(d, len / 2); arm.upper.quaternion.copy(_q); arm.upper.scale.set(1, len, 1);
    arm.bicep.position.copy(elbow).addScaledVector(d, len * .42).add(V(0, .08, 0)); arm.bicep.quaternion.copy(_q); arm.bicep.scale.set(.25 * (1 + .28 * P.flex), .32, .27 * (1 + .28 * P.flex));
    arm.tricep.position.copy(elbow).addScaledVector(d, len * .5).add(V(arm.side * .06, -.06, .04)); arm.tricep.quaternion.copy(_q); arm.tricep.scale.set(.2, .3, .2);
    arm.vein.position.copy(elbow).addScaledVector(d, len * .4).add(V(-arm.side * .04, .2 + .04 * P.flex, -.06)); arm.vein.quaternion.copy(_q);
    arm.deltoid.position.copy(sh).add(V(arm.side * .04, .08, 0)); arm.deltoid.scale.setScalar(1 + .1 * P.flex);
  }
  // Right leg for the axe kick: hip, knee and ankle joints in camera space, black trousers and a dark shoe.
  const leg = new T.Group(); camera.add(leg); leg.visible = false;
  part(new T.CylinderGeometry(.22, .17, .95, 18), mPants, leg, [0, -.47, 0]);
  const knee = new T.Group(); leg.add(knee); knee.position.y = -.95;
  part(new T.SphereGeometry(.17, 14, 10), mPants, knee);
  part(new T.CylinderGeometry(.16, .12, .9, 16), mPants, knee, [0, -.45, 0]);
  const ankle = new T.Group(); knee.add(ankle); ankle.position.y = -.9;
  part(new T.BoxGeometry(.2, .14, .38), mShoe, ankle, [0, -.06, -.1]);
  part(new T.BoxGeometry(.19, .1, .12), mShoe, ankle, [0, -.05, .1]);
  leg.traverse(o => { o.castShadow = false; });
  function poseLeg(hip, kneeBend, foot, show) {
    leg.visible = show && active && fp; if (!leg.visible) return;
    leg.position.set(.32 * clamp(camera.aspect, .55, 1), -1.5, -.25); leg.rotation.set(hip, 0, -.08);
    knee.rotation.x = -kneeBend; ankle.rotation.x = foot;
  }

  // ---------- third-person Yujiro: shown in cinematic cuts, the victim view and the spectator view ----------
  const body = new T.Group(); scene.add(body); body.visible = false;
  const bpart = (geo, m, parent, pos, rot, scale) => { const x = new T.Mesh(geo, m); parent.add(x); if (pos) x.position.set(...pos); if (rot) x.rotation.set(...rot); if (scale) x.scale.set(...scale); x.castShadow = true; return x; };
  const hips = new T.Group(); body.add(hips); hips.position.y = 1.0;
  bpart(new T.SphereGeometry(.3, 16, 12), mPants, hips, [0, 0, 0], null, [1.05, .55, .75]);
  const legs = [];
  for (const s of [-1, 1]) {
    const hip = new T.Group(); hips.add(hip); hip.position.set(s * .19, -.04, 0);
    bpart(new T.CylinderGeometry(.17, .14, .52, 12), mPants, hip, [0, -.26, 0]);
    const kn = new T.Group(); hip.add(kn); kn.position.y = -.52;
    bpart(new T.CylinderGeometry(.14, .11, .46, 12), mPants, kn, [0, -.23, 0]);
    const ft = new T.Group(); kn.add(ft); ft.position.y = -.46;
    bpart(new T.BoxGeometry(.17, .1, .3), mShoe, ft, [0, -.03, -.07]);
    legs.push({ hip, kn, ft, s });
  }
  const torso = new T.Group(); hips.add(torso); torso.position.y = .06;
  bpart(new T.SphereGeometry(1, 18, 14), mSkin, torso, [0, .2, 0], null, [.31, .26, .2]);
  for (let i = 0; i < 6; i++) bpart(new T.SphereGeometry(1, 10, 8), mMuscle, torso, [(i % 2 ? 1 : -1) * .07, .08 + Math.floor(i / 2) * .1, -.175], null, [.06, .045, .03]);
  bpart(new T.SphereGeometry(1, 20, 14), mSkin, torso, [0, .58, 0], null, [.5, .3, .27]);
  for (const s of [-1, 1]) {
    bpart(new T.SphereGeometry(1, 14, 10), mMuscle, torso, [s * .17, .6, -.17], null, [.2, .13, .1]);
    bpart(new T.SphereGeometry(1, 14, 10), mSkin, torso, [s * .33, .48, .05], null, [.16, .3, .18]);
    bpart(new T.SphereGeometry(1, 14, 10), mSkin, torso, [s * .15, .86, .05], null, [.2, .1, .15]);
  }
  bpart(new T.SphereGeometry(1, 20, 14), mSkin, torso, [0, .54, .1], null, [.44, .36, .18]);
  bpart(new T.CylinderGeometry(.13, .16, .2, 12), mSkin, torso, [0, .96, 0]);
  // The Demon Back: brows, eye pits, cheeks, a nose ridge and a grinning mouth, all as muscle relief on the back.
  const demon = [];
  const relief = (geo, m, pos, rot, scale, dark = false) => { const x = bpart(geo, m, torso, pos, rot, scale); demon.push({ x, base: V(...scale), dark }); return x; };
  const sph = new T.SphereGeometry(1, 14, 10);
  for (const s of [-1, 1]) {
    relief(sph, mRelief, [s * .16, .76, .265], [0, 0, s * .38], [.15, .05, .07]);           // brows, inner ends low
    relief(sph, mDark, [s * .14, .66, .262], [0, 0, s * .2], [.075, .04, .035], true);       // eye pits
    relief(sph, mRelief, [s * .14, .7, .275], null, [.09, .03, .05]);                        // upper lid ridge
    relief(sph, mRelief, [s * .22, .55, .27], null, [.11, .085, .075]);                      // cheeks
    relief(sph, mRelief, [s * .055, .47, .282], null, [.04, .03, .04]);                      // nostrils
    relief(sph, mRelief, [s * .1, .405, .28], [0, 0, -s * .25], [.12, .033, .05]);           // upper lip
    relief(sph, mRelief, [s * .13, .28, .265], null, [.08, .1, .07]);                        // jaw
    relief(sph, mRelief, [s * .13, .87, .23], [0, 0, s * .3], [.16, .07, .08]);              // horns of the brow
  }
  relief(sph, mRelief, [0, .56, .285], null, [.045, .12, .06]);                              // nose ridge (spine)
  relief(sph, mDark, [0, .35, .262], null, [.19, .045, .03], true);                          // mouth
  for (let i = -2; i <= 2; i++) relief(sph, mTeeth, [i * .055, .36, .27], null, [.022, .03, .02]);
  const head = new T.Group(); torso.add(head); head.position.y = 1.1;
  bpart(new T.SphereGeometry(.17, 18, 14), mSkin, head, [0, 0, 0], null, [1, 1.12, 1.05]);
  bpart(new T.BoxGeometry(.22, .1, .18), mSkin, head, [0, -.12, -.03]);
  bpart(new T.BoxGeometry(.27, .04, .05), mShade, head, [0, .045, -.155], [-.15, 0, 0]);
  for (const s of [-1, 1]) {
    bpart(new T.SphereGeometry(.022, 8, 6), mEye, head, [s * .065, .0, -.158]);
    bpart(new T.BoxGeometry(.08, .02, .02), mShade, head, [s * .065, .035, -.168], [0, 0, s * .3]);
  }
  bpart(new T.BoxGeometry(.13, .03, .02), mTeeth, head, [0, -.11, -.168]);
  bpart(new T.SphereGeometry(.19, 16, 12), mHair, head, [0, .09, .03], null, [1.06, .8, 1.1]);
  for (let i = 0; i < 11; i++) {
    const a = (i / 10 - .5) * 2.4, back = i % 2 ? .1 : 0;
    bpart(new T.ConeGeometry(.055, .32, 7), mHair, head, [Math.sin(a) * .13, .2, .04 + back + Math.cos(a) * .02], [-.9 - back * 3, 0, -Math.sin(a) * .7]);
  }
  const shoulders = [];
  for (const s of [-1, 1]) {
    const pivot = new T.Group(); torso.add(pivot); pivot.position.set(s * .5, .8, 0);
    bpart(new T.SphereGeometry(.18, 14, 10), mSkin, pivot);
    bpart(new T.CylinderGeometry(.15, .13, .42, 12), mSkin, pivot, [0, -.21, 0]);
    bpart(new T.SphereGeometry(1, 12, 10), mMuscle, pivot, [0, -.2, -.07], null, [.13, .17, .12]);
    const el = new T.Group(); pivot.add(el); el.position.y = -.42;
    bpart(new T.CylinderGeometry(.13, .1, .4, 12), mSkin, el, [0, -.2, 0]);
    const hand = new T.Group(); el.add(hand); hand.position.y = -.43;
    const fist = bpart(new T.BoxGeometry(.15, .14, .15), mSkin, hand);
    const open = bpart(new T.BoxGeometry(.12, .22, .05), mSkin, hand, [0, -.07, 0]);
    shoulders.push({ pivot, el, hand, fist, open, s });
  }
  body.traverse(x => { if (x.geometry) SHARED.add(x.geometry); if (x.material) SHARED.add(x.material); });
  // Body poses: twist, lean, crouch, shoulder Euler [x fwd, y, z out], elbow [bend, side], hand open 0..1, legs [hip, knee], head tilt.
  const BP = o => ({ tw: 0, ln: .04, cr: 0, ls: [.1, 0, -.12], le: [.35, 0], rs: [.1, 0, .12], re: [.35, 0], lo: 0, ro: 0, rl: [0, 0], ll: [0, 0], hx: 0, hz: 0, ...o });
  const B = {
    idle: BP({}),
    stance: BP({ ln: -.08, ls: [1.05, 0, -.08], le: [.55, 0], lo: 1, rs: [-.05, 0, .28], re: [1.25, 0], ro: .4, hz: .16, hx: .08 }),
    deflect: BP({ ln: -.04, tw: .25, ls: [1.25, 0, -.75], le: [.3, 0], lo: 1, rs: [-.15, 0, .3], re: [1.5, 0], hz: .05 }),
    upper: BP({ ln: -.12, tw: -.45, ls: [.9, 0, -.5], le: [.8, 0], lo: .6, rs: [2.5, 0, .1], re: [.45, 0], cr: .05, hx: -.15 }),
    crouch: BP({ ln: .35, cr: .3, ls: [.8, 0, -.2], le: [1.5, 0], rs: [.6, 0, .2], re: [1.7, 0] }),
    dash: BP({ ln: .55, cr: .15, ls: [-.5, 0, -.15], le: [1.2, 0], rs: [-.6, 0, .15], re: [1.2, 0] }),
    body: BP({ ln: .3, cr: .2, tw: .45, ls: [1.25, 0, 0], le: [.25, 0], rs: [.6, 0, .25], re: [1.8, 0] }),
    hookCock: BP({ ln: .2, cr: .1, tw: .5, ls: [.8, 0, -.25], le: [1.6, 0], rs: [.9, 0, .95], re: [1.4, 0] }),
    hook: BP({ ln: .15, cr: .05, tw: -.65, ls: [.7, 0, -.3], le: [1.6, 0], rs: [1.45, 0, -.2], re: [.55, 0] }),
    kickUp: BP({ ln: -.25, ls: [.3, 0, -.5], le: [.8, 0], rs: [.2, 0, .55], re: [.8, 0], rl: [2.7, .05] }),
    kickDown: BP({ ln: .35, cr: .2, ls: [.6, 0, -.4], le: [1, 0], rs: [.5, 0, .4], re: [1, 0], rl: [.9, .1] }),
    freeze: BP({ ln: .12, ls: [0, 0, -.12], le: [.15, 0], rs: [0, 0, .12], re: [.15, 0], hx: .45 }),
    spread: BP({ ln: -.05, ls: [-.15, 0, -1.45], le: [0, -1.45], rs: [-.15, 0, 1.45], re: [0, 1.45], hx: -.1, cr: .08 }),
    reach: BP({ ln: .35, cr: .1, ls: [1.55, 0, -.05], le: [.1, 0], lo: .7, rs: [-.4, 0, .2], re: [1.2, 0] }),
    grab: BP({ ln: .12, ls: [1.45, 0, -.05], le: [.35, 0], lo: 0, rs: [.3, 0, .3], re: [1.5, 0] }),
    blowCock: BP({ ln: .15, tw: .45, ls: [1.4, 0, -.05], le: [.4, 0], rs: [.3, 0, .5], re: [1.8, 0] }),
    blow: BP({ ln: .3, cr: .15, tw: -.4, ls: [1.35, 0, -.05], le: [.5, 0], rs: [1.2, 0, 0], re: [.25, 0] }),
    slapWind: BP({ ln: .08, tw: .55, ls: [1.4, 0, -.05], le: [.45, 0], rs: [1.1, 0, 1.0], re: [.9, 0], ro: 1 }),
    slap: BP({ ln: .12, tw: -.6, ls: [1.4, 0, -.05], le: [.45, 0], rs: [1.5, 0, -.45], re: [.3, 0], ro: 1 }),
    jabR: BP({ ln: .18, tw: -.35, ls: [.9, 0, -.25], le: [1.4, 0], rs: [1.57, 0, -.05], re: [.05, 0] }),
    jabL: BP({ ln: .18, tw: .35, ls: [1.57, 0, .05], le: [.05, 0], rs: [.9, 0, .25], re: [1.4, 0] }),
    lift: BP({ ln: -.18, ls: [2.75, 0, -.22], le: [.25, 0], lo: 1, rs: [2.75, 0, .22], re: [.25, 0], ro: 1, hx: -.35 }),
    throw: BP({ ln: .1, ls: [1.9, 0, -.1], le: [.1, 0], lo: 1, rs: [1.9, 0, .1], re: [.1, 0], ro: 1 }),
    wind: BP({ ln: .05, cr: .12, tw: .85, ls: [1.25, 0, -.3], le: [.7, 0], rs: [.4, 0, .65], re: [1.7, 0] }),
    final: BP({ ln: .45, cr: .28, tw: -.65, ls: [.4, 0, -.5], le: [1.1, 0], rs: [1.35, 0, -.1], re: [.08, 0], hx: .2 }),
    recover: BP({ ln: .25, cr: .1, ls: [.2, 0, -.2], le: [.5, 0], rs: [.3, 0, .2], re: [.4, 0], hx: .5 }),
  };
  function lerpBP(a, b, k) {
    if (k <= 0) return a; if (k >= 1) return b; const o = {};
    for (const key in a) o[key] = Array.isArray(a[key]) ? a[key].map((v, i) => mix(v, b[key][i], k)) : mix(a[key], b[key], k);
    return o;
  }
  let bodyPose = B.idle, demonK = 0;
  function poseBody(P, dir) {
    body.position.copy(basePos).setY(basePos.y - EYE); body.rotation.set(0, Math.atan2(-dir.x, -dir.z), 0);
    hips.position.y = 1.0 - .32 * P.cr; torso.rotation.set(-P.ln, P.tw, 0); head.rotation.set(P.hx, -P.tw * .4, P.hz);
    const [L, R] = shoulders;
    L.pivot.rotation.set(...P.ls); L.el.rotation.set(P.le[0], 0, P.le[1]); R.pivot.rotation.set(...P.rs); R.el.rotation.set(P.re[0], 0, P.re[1]);
    L.fist.visible = P.lo < .5; L.open.visible = !L.fist.visible; R.fist.visible = P.ro < .5; R.open.visible = !R.fist.visible;
    for (const g of legs) {
      const own = g.s > 0 ? P.rl : P.ll;
      g.hip.rotation.x = own[0] + .7 * P.cr; g.kn.rotation.x = -(own[1] + 1.4 * P.cr); g.ft.rotation.x = .7 * P.cr;
    }
    // Back muscles: flat when relaxed, pulled into the demon's face as demonK rises.
    for (const d of demon) {
      const k = d.dark ? demonK : .25 + .75 * demonK;
      d.x.scale.set(d.base.x * (d.dark ? Math.max(.01, k) : 1), d.base.y * (d.dark ? Math.max(.01, k) : 1), d.base.z * k);
      d.x.visible = !d.dark || demonK > .05;
    }
    mRelief.emissive.setHex(0x4a0400); mRelief.emissiveIntensity = .5 * demonK * (.7 + .3 * Math.sin(A.time * 9));
  }

  // ---------- training dummies: extra ones for Yujiro, plus one that attacks you (for the counter) ----------
  const extras = [[-2.6, -9.6], [3, -10.2], [8.5, -8], [-8.5, -6.5]].map(([x, z], i) => { const t = A.makeTarget(x, z, 4 + i); t.yjOnly = true; return t; });
  const attacker = A.makeTarget(-11, -3, 8); attacker.yjOnly = true;
  for (const t of [...extras, attacker]) { targets.splice(targets.indexOf(t), 1); t.g.visible = false; }

  // ---------- movers and reactions (same model as All Might) ----------
  const movers = new Map();
  const limbs = t => [t.g.children[3], t.g.children[4]];
  function setTilt(t, dir, phi) { t.g.rotation.x = phi * dir.z; t.g.rotation.z = -phi * dir.x; }
  function flail(t, k) {
    const [l, r] = limbs(t), w = Math.sin(A.time * 22 + t.index) * .55;
    l.rotation.z = -(1.3 + w) * k; r.rotation.z = (1.3 - w) * k; l.rotation.x = Math.cos(A.time * 17) * .5 * k; r.rotation.x = -Math.cos(A.time * 19) * .5 * k;
  }
  // Impact squash: the body caves in around the fist for a moment, then springs back.
  function squash(t, k) { t.g.scale.set(1 + .18 * k, 1 - .14 * k, 1 + .18 * k); }
  function calm(t) { for (const l of limbs(t)) l.rotation.set(0, 0, 0); t.g.rotation.x = 0; t.g.rotation.z = 0; t.g.scale.setScalar(1); }
  function take(t) { const old = movers.get(t); if (old?.drop) old.drop(); t.vel = null; t.locked = true; t.g.userData.cannonUntil = Infinity; }
  function release(t) { movers.delete(t); calm(t); t.locked = false; t.landed = A.time; t.g.userData.cannonUntil = 0; }
  function move(t, m) { take(t); m.born = A.time; movers.set(t, m); return m; }
  function handoff(t, m) { movers.delete(t); return move(t, m); }
  const edge = () => A.arenaR - 1.2;
  function clampArena(p) { const r = Math.hypot(p.x, p.z), lim = edge(); if (r > lim) { p.x *= lim / r; p.z *= lim / r; } }
  const inObstacle = (p, m = .45) => A.obstacles.find(o => p.x > o.x0 - m && p.x < o.x1 + m && p.z > o.z0 - m && p.z < o.z1 + m && p.y < o.h);
  function wallAlong(from, dir, dist, m = .45) {
    const p = V();
    for (let s = .12; s <= dist; s += .12) {
      p.copy(from).addScaledVector(dir, s); p.y = 1.2;
      const o = inObstacle(p, m);
      if (o) {
        const prev = from.clone().addScaledVector(dir, s - .12), n = V(), hit = prev.clone();
        if (prev.x <= o.x0 - m) { n.set(-1, 0, 0); hit.x = o.x0 - .02; } else if (prev.x >= o.x1 + m) { n.set(1, 0, 0); hit.x = o.x1 + .02; }
        else if (prev.z <= o.z0 - m) { n.set(0, 0, -1); hit.z = o.z0 - .02; } else { n.set(0, 0, 1); hit.z = o.z1 + .02; }
        return { d: Math.max(0, s - .12), normal: n, point: hit.setY(1.3) };
      }
    }
    return null;
  }
  // A point clear of every pillar: walks back along `dir` until the body fits.
  function safeGround(p, dir) { const q = p.clone().setY(0); clampArena(q); for (let i = 0; i < 60 && inObstacle(q.clone().setY(.5), .6); i++) q.addScaledVector(dir, -.25); return q; }
  function knockDown(t, dir, hold) {
    const from = Math.hypot(t.g.rotation.x, t.g.rotation.z);
    move(t, { kind: 'down', update(age) {
      const lie = age < .16 ? mix(from, Math.PI / 2, ease(age / .16)) : age < .16 + hold ? Math.PI / 2 : mix(Math.PI / 2, 0, ease((age - .16 - hold) / .4));
      setTilt(t, dir, lie); flail(t, Math.max(0, .4 - age));
      if (age > .56 + hold) release(t);
    } });
    dust(t.g.position.clone().setY(.2), 1.6, .8, V(0, .5, 0));
  }
  // Falls from where the body is now onto safe ground (never inside a pillar, never off the arena), then lies down.
  function fall(t, dir, vel = V(), hold = .45, g = 26) {
    const v = vel.clone();
    move(t, { kind: 'fall', update(age, dt) {
      v.y -= g * dt; t.g.position.addScaledVector(v, dt); clampArena(t.g.position);
      const flat = v.clone().setY(0);
      if (flat.lengthSq() > 1e-4 && wallAlong(t.g.position, flat.clone().normalize(), flat.length() * dt + .05)) { v.x = 0; v.z = 0; }
      setTilt(t, dir, Math.min(Math.PI / 2, age * 2.4)); flail(t, 1);
      if (t.g.position.y <= 0) {
        t.g.position.copy(safeGround(t.g.position, dir)); dustRing(t.g.position, 1.2, 10, .8, 3); cracks(t.g.position, 1.6, 7, 2.5); sfx.thud(); knockDown(t, dir, hold);
      }
    } });
  }
  function alive(t) { return t.hp > 0 && t.g.visible !== false; }
  // Damage numbers: the app's hit(), with One For All's multipliers applied where they belong.
  function hit(t, amount, color) { A.hit(t, Math.round(amount), color); }
  // Knock arc along a flat direction; a pillar stops it dead (+wall damage once), the arena edge shortens it.
  function knock(t, dir, dist, lift, dur, wallDamage = 0, heavy = true) {
    const from = t.g.position.clone().setY(0);
    let travel = dist; for (let s = dist; s > 0; s -= .2) { const p = from.clone().addScaledVector(dir, s); if (Math.hypot(p.x, p.z) <= edge()) { travel = s; break; } }
    const wall = wallAlong(from, dir, travel);
    if (wall) travel = wall.d;
    const uEnd = 1 - Math.cbrt(1 - clamp(travel / dist, 0, .999));
    handoff(t, { kind: 'knock', update(age, dt) {
      const u = Math.min(age / dur, uEnd), prev = t.g.position.clone();
      t.g.position.copy(from).addScaledVector(dir, dist * outP(u, 3)); t.g.position.y = 4 * lift * u * (1 - u);
      setTilt(t, dir, (heavy ? 1.35 : .7) * Math.min(1, u * 3)); flail(t, 1); squash(t, Math.max(0, 1 - age * 8));
      const step = t.g.position.clone().sub(prev);
      if (heavy && step.lengthSq() > 1e-4) { streak(t.g.position.clone().setY(t.g.position.y + 1.4).addScaledVector(dir, -.5), dir.clone().negate(), step.length() * 6 + 1, 2, .3, WIND, .45, .55); if (Math.random() < .5) dust(t.g.position.clone().setY(.4), 1.3, .5, dir.clone().multiplyScalar(-2)); }
      if (u >= uEnd) {
        if (wall) {
          if (wallDamage) hit(t, wallDamage, '#ffd0a0'); wallImpact(wall); t.g.position.addScaledVector(dir, -.15);
          fall(t, dir.clone().negate(), dir.clone().multiplyScalar(-1.5));
        } else { t.g.position.y = 0; dust(t.g.position.clone().setY(.2), 2.2, .9, dir.clone().multiplyScalar(4)); cracks(t.g.position, 1.4, 6, 2); sfx.thud(); knockDown(t, dir, .45); }
      }
    } });
  }
  function wallImpact(w) {
    sfx.thud(); sfx.crack(); if (w.point.distanceTo(basePos) < 16) shake(.08, 14);
    const g = new T.Group(); g.position.copy(w.point); g.lookAt(w.point.clone().add(w.normal));
    const dent = new T.Mesh(new T.CircleGeometry(.5, 18), new T.MeshBasicMaterial({ color: 0x1c1a1c, transparent: true, opacity: .75, depthWrite: false })); g.add(dent);
    for (let i = 0; i < 11; i++) {
      const a = i / 11 * Math.PI * 2 + rnd(0, .4), len = rnd(.6, 1.6);
      const c = new T.Mesh(new T.PlaneGeometry(len, .05), new T.MeshBasicMaterial({ color: 0x141214, transparent: true, opacity: .85, depthWrite: false }));
      c.position.set(Math.cos(a) * len / 2, Math.sin(a) * len / 2, .005); c.rotation.z = a; g.add(c);
    }
    fx(g, 3.5, (o, u) => o.traverse(x => { if (x.material) x.material.opacity = (x === dent ? .75 : .85) * (1 - seg(u, .6, 1)); }));
    ring(w.point.clone().addScaledVector(w.normal, .1), w.normal, 2.6, WIND, .35, .05, .8);
    for (let i = 0; i < 14; i++) throwRock(w.point.clone().addScaledVector(w.normal, .2), w.normal.clone().multiplyScalar(rnd(3, 9)).add(V(rnd(-3, 3), rnd(1, 5), rnd(-3, 3))), rnd(.06, .16), rnd(1, 1.6));
    for (let i = 0; i < 6; i++) dust(w.point.clone().addScaledVector(w.normal, .3), rnd(1.4, 2.2), rnd(.8, 1.2), w.normal.clone().multiplyScalar(rnd(2, 4)).add(V(rnd(-1, 1), rnd(0, 1), rnd(-1, 1))), 0xcfc7bb, .7);
  }
  // First living body in the corridor ahead of `from`.
  function firstAhead(from, dir, reach, width, skip) {
    let best = null, bestAlong = Infinity;
    for (const t of targets) {
      if (!alive(t) || (skip && skip.has(t))) continue;
      const rel = t.g.position.clone().sub(from).setY(0), along = rel.dot(dir), side = rel.clone().addScaledVector(dir, -along).length();
      if (along > -.4 && along <= reach && side <= width && Math.abs(t.g.position.y - (from.y - EYE)) < 4 && along < bestAlong) { best = t; bestAlong = along; }
    }
    return best;
  }
  const visor = t => t.g.children[6];
  function tilt2(t, dir, fwd, side, sideAmt) { t.g.rotation.x = fwd * dir.z + sideAmt * side.z; t.g.rotation.z = -(fwd * dir.x + sideAmt * side.x); }
  function gone(t) { return !t || t.hp <= 0 || t.g.visible === false; }
  function losClear(from, to) { const d = to.clone().sub(from), len = d.length(); return len < .01 || !A.wallOnRay(from, d.normalize(), len); }
  // Pushed back along `dir` (stopped by pillars and the arena edge), then a stagger in place.
  function shove(t, dir, dist, dur, stagger) {
    const from = t.g.position.clone().setY(0); let travel = dist;
    const wall = wallAlong(from, dir, dist); if (wall) travel = Math.max(0, wall.d - .2);
    const to = safeGround(from.clone().addScaledVector(dir, travel), dir);
    handoff(t, { kind: 'shove', update(age) {
      const u = outP(age / dur, 3); t.g.position.lerpVectors(from, to, u); t.g.position.y = .6 * Math.sin(Math.min(1, age / dur) * Math.PI);
      const k = age < dur ? 1 : 1 - seg(age, dur, dur + stagger);
      setTilt(t, dir, (.75 + .12 * Math.sin(age * 16)) * k); flail(t, .7 * k);
      if (age >= dur && !this.landed) { this.landed = true; dust(t.g.position.clone().setY(.2), 1.6, .6, dir.clone().multiplyScalar(2)); if (wall) wallImpact(wall); }
      if (age >= dur + stagger) release(t);
    } });
  }

  // ---------- camera feel ----------
  let shakeAmp = 0, vign = 0, redK = 0, flashV = 0, gray = 0, filterOn = false, fp = true, label = '';
  function shake(amp) { shakeAmp = Math.max(shakeAmp, amp * (A.comfort ? .3 : 1)); }
  function screenFlash(power) { flashV = Math.max(flashV, power * (A.comfort ? .5 : 1)); }
  function lookAtBlend(point, k, maxPitch = 1.35) {
    if (k <= 0) return;
    const d = point.clone().sub(camera.position), yaw = Math.atan2(-d.x, -d.z), pitch = clamp(Math.atan2(d.y, Math.hypot(d.x, d.z)), -maxPitch, maxPitch);
    let dy = yaw - camera.rotation.y; dy = Math.atan2(Math.sin(dy), Math.cos(dy));
    camera.rotation.y += dy * k; camera.rotation.x = mix(camera.rotation.x, pitch, k);
  }
  const _q2 = new T.Quaternion(), _m2 = new T.Matrix4();
  // A third-person shot around the caster; swings to the clearest angle when a pillar or the arena edge is in the way.
  function placeCamera(pos, look, w = 1) {
    const me = basePos.clone(), off = pos.clone().sub(me), len = off.length();
    const clear = d => { for (let s = .3; s <= len; s += .2) { const p = me.clone().addScaledVector(d, s); if (inObstacle(p, .3) || Math.hypot(p.x, p.z) > A.arenaR - .4 || p.y < .3) return Math.max(.6, s - .4); } return len; };
    let best = null, ok = -1;
    for (const ang of [0, .45, -.45, .9, -.9, 1.4, -1.4]) { const d = off.clone().applyAxisAngle(UP, ang).normalize(), r = clear(d); if (r > ok + .01) { ok = r; best = d; } if (r >= len * .85) break; }
    const at = me.clone().addScaledVector(best, ok);
    _m2.lookAt(at, look, UP); _q2.setFromRotationMatrix(_m2);
    camera.position.lerp(at, w); camera.quaternion.slerp(_q2, w);
  }

  // ---------- state ----------
  let active = false, buffUntil = 0, recoverUntil = 0;
  const COUNTERABLE = new Set(['melee', 'dash', 'weapon', 'kick', 'basic']);

  // ---------- incoming hits (preview stand-in for Combat's damage hook) ----------
  // Q waiting: a counterable direct hit inside the 160 degree front arc is read and countered (no damage); any other
  // frontal hit is cut by 70%; hits from behind are full. R: 30% less damage taken.
  function incomingHit(amount, from, kind, src) {
    const c = A.cast, fwd = A.flatForward(), toFrom = from.clone().sub(basePos).setY(0); toFrom.y = 0; toFrom.normalize();
    const front = fwd.dot(toFrom) >= CFG.q.arc;
    let dealt = amount, note = '';
    if (c?.yujiro && c.type === 'counter' && !c.read) {
      const a = A.time - c.start;
      if (a >= CFG.q.enter && a < CFG.q.window && front) {
        if (COUNTERABLE.has(kind) && src) { startCounter(c, a, src); return 0; }
        dealt = Math.round(amount * CFG.q.guard); note = ' (정면 피해 -70%' + (kind === 'projectile' ? ' · 투사체는 반격 불가' : '') + ')';
      } else if (a >= CFG.q.enter && a < CFG.q.window && !front) note = ' (등 뒤 공격 · 감소 없음)';
    }
    if (c?.yujiro && c.type === 'judgment' && !c.fail) { dealt = Math.round(dealt * CFG.r.guard); note = ' (오거의 심판 · 받는 피해 -30%, 경직 저항)'; }
    A.hp = Math.max(1, A.hp - dealt); A.flash('#ff2a2a', .18); shake(.05);
    A.toast('피격 · ' + dealt + ' 피해' + note);
    return dealt;
  }
  function enemyAttack(kind, fromDemo = false) {
    if (!active || attacker.lunge) return;
    if (!fromDemo) A.stopDemo?.();
    const f = A.flatForward(), back = kind === 'back', at = basePos.clone().setY(0).addScaledVector(f, kind === 'proj' ? 9 : back ? -2.4 : 2.4);
    if (inObstacle(at.clone().setY(.5), .5)) at.copy(basePos).setY(0).addScaledVector(f, back ? -1.8 : 1.8);
    attacker.hp = attacker.max; attacker.g.visible = true; attacker.g.position.copy(at); attacker.locked = true; attacker.g.userData.cannonUntil = Infinity;
    attacker.bar.scale.x = 1; attacker.bar.position.x = 0; calm(attacker);
    attacker.lunge = { start: A.time, kind, hit: false };
    dust(at.clone().setY(.4), 1.2, .5, V(0, .6, 0));
    A.toast(kind === 'proj' ? '훈련 상대가 정면에서 투사체를 던집니다' : back ? '훈련 상대가 등 뒤에서 주먹을 날립니다' : '훈련 상대가 정면에서 주먹을 날립니다');
  }
  function updateAttacker(dt) {
    const L = attacker.lunge; if (!L) return;
    const a = A.time - L.start, [la, ra] = limbs(attacker);
    if (L.countered) { if (a > 3.4 || (!movers.has(attacker) && a > L.countered + 1.6)) endAttacker(); return; }
    const toMe = basePos.clone().setY(0).sub(attacker.g.position).setY(0), dist = toMe.length(); toMe.normalize();
    attacker.g.lookAt(attacker.g.position.clone().sub(toMe));
    const wind = ease(seg(a, 0, .35)), strike = outP(seg(a, .35, .45), 3), back = ease(seg(a, .7, 1.1));
    ra.rotation.x = mix(mix(0, .9, wind), -1.6, strike) * (1 - back); la.rotation.x = .4 * wind * (1 - back);
    if (L.kind === 'proj') {
      if (a >= .42 && !L.ball) {
        L.ball = keep(new T.Mesh(new T.SphereGeometry(.16, 12, 8), new T.MeshStandardMaterial({ color: 0x8fa6b8, emissive: 0x2a3a48 })));
        L.ball.position.copy(attacker.g.position).setY(1.6); L.from = L.ball.position.clone(); sfx.whoosh();
      }
      if (L.ball && !L.hit) {
        const u = seg(a, .42, .82); L.ball.position.lerpVectors(L.from, basePos.clone().setY(1.5), u);
        if (u >= 1) { L.hit = true; kill(L.ball); L.ball = null; incomingHit(12, attacker.g.position.clone(), 'projectile', null); sfx.thud(); }
      }
    } else {
      attacker.g.rotation.x = mix(-.12 * wind, .18, strike) * (1 - back);
      if (a >= .3 && a < .45) attacker.g.position.addScaledVector(toMe, Math.max(0, dist - 1.75) * dt * 6);
      if (a >= .42 && !L.hit) {
        L.hit = true; sfx.whoosh();
        if (basePos.distanceTo(attacker.g.position.clone().setY(EYE)) < 3.2) { const dealt = incomingHit(12, attacker.g.position.clone(), 'melee', attacker); if (dealt) sfx.body(); }
      }
    }
    if (a > 1.6 && !L.countered) endAttacker();
  }
  function endAttacker() {
    const L = attacker.lunge; if (L?.ball) kill(L.ball);
    attacker.lunge = null; movers.delete(attacker); attacker.g.visible = false; attacker.locked = false; calm(attacker); attacker.g.position.copy(attacker.home); attacker.hp = attacker.max;
  }

  // ---------- Q: Strongest Creature on Earth (counter stance) ----------
  function beginCounter(c) {
    c.duration = CFG.q.window + CFG.q.fail; c.dir = A.flatForward();
    A.title('地上最強の生物', '지상 최강의 생물', '0.25초 자세 → 2.5초까지 정면 160° 직접 공격을 읽고 반격 · 정면 피해 -70%', '#ff5a4a');
    sfx.stance(); sfx.laugh(.05);
  }
  function startCounter(c, a, src) {
    c.read = a; c.src = src; c.duration = a + CFG.q.holdEnd; c.from = src.g.position.clone();
    src.lunge.countered = A.time - src.lunge.start; take(src); movers.set(src, { kind: 'read', born: A.time });
    A.hitstop(CFG.q.slow); sfx.parry(); shake(.06);
    call('읽었다', .8, '반격 · 공격을 흘리고 턱에 어퍼컷');
  }
  function updateCounter(c, a, dt) {
    const Q = CFG.q;
    const enter = outP(a / Q.enter, 2);
    if (!c.read) {
      // Stance: stop, stand a little upright, right hand by the waist, left hand in front, head tilted.
      const breathe = Math.sin(A.time * 2.2) * .008;
      const failK = a >= Q.window ? ease((a - Q.window) / Q.fail) : 0;
      let R = lerpPose(REST, Q_WAIST, enter), L = lerpPose(L_REST, L_FRONT, enter);
      R = lerpPose(R, REST, failK); L = lerpPose(L, L_REST, failK);
      R.pos = R.pos.clone().add(V(0, breathe, 0)); L.pos = L.pos.clone().add(V(0, -breathe, 0));
      poseArm(arms.r, R); poseArm(arms.l, L);
      const k = enter * (1 - failK);
      camera.position.y += -.12 * bump(a, 0, .35) + .06 * k; camera.rotation.z += .07 * k; camera.rotation.x -= .03 * bump(a, 0, .35);
      camera.fov = 66 - 6 * k; vign = Math.max(vign, .45 * k);
      bodyPose = lerpBP(lerpBP(B.idle, B.stance, enter), B.idle, failK);
      if (a >= Q.window && !c.flags.fail) { c.flags.fail = true; recoverUntil = A.time + Q.fail; A.toast('반격 실패 · 0.4초 경직 · 재사용 18초'); sfx.exhale(); }
      return;
    }
    const k = a - c.read, src = c.src, dir = src.g.position.clone().sub(basePos).setY(0).normalize();
    c.dir = dir;
    // 0-0.15: head snaps to the attacker, left arm deflects; 0.15-0.5: right uppercut to the jaw; 0.5-0.9: hold, then lower.
    const snap = outP(k / .08, 3), deflect = outP(k / Q.deflect, 3), cock = ease(seg(k, .08, Q.deflect + .04)), upper = outP(seg(k, Q.deflect + .04, Q.hitAt), 3);
    const lower = ease(seg(k, Q.upperEnd + .15, Q.holdEnd));
    lookAtBlend(src.g.position.clone().setY(1.9), .85 * snap * (1 - lower * .7));
    camera.rotation.z += .1 * bump(k, 0, .25) - .05 * bump(k, Q.hitAt - .05, Q.holdEnd);
    let L = lerpPose(lerpPose(L_FRONT, L_DEFLECT, deflect), L_REST, ease(seg(k, .25, Q.holdEnd)));
    let R = lerpPose(lerpPose(lerpPose(Q_WAIST, R_UP_COCK, cock), R_UPPER, upper), REST, lower);
    poseArm(arms.r, R); poseArm(arms.l, L);
    camera.position.addScaledVector(A.flatForward(), .35 * bump(k, Q.hitAt - .06, Q.upperEnd + .1));
    camera.fov = 60 + 12 * bump(k, Q.hitAt - .03, Q.upperEnd + .1);
    bodyPose = lerpBP(lerpBP(lerpBP(B.stance, B.deflect, deflect), B.upper, upper), B.idle, lower);
    // The attacker: arm knocked aside on the deflect, then lifted by the jaw.
    if (k < Q.hitAt && movers.get(src)?.kind === 'read') { const [la, ra] = limbs(src); ra.rotation.set(-1.2, 0, -.8 * deflect); tilt2(src, dir, .1 * deflect, V().crossVectors(dir, UP), .25 * deflect); }
    if (k >= Q.hitAt && !c.flags.upper) {
      c.flags.upper = true; c.hit = !gone(src);
      if (c.hit) {
        const jaw = src.g.position.clone().setY(2.25);
        A.hit(src, Q.damage, '#ffffff'); sfx.jab(); sfx.impact(); shake(.2); screenFlash(.3); A.hitstop(50);
        ring(jaw, dir.clone().add(V(0, 1.3, 0)).normalize(), 3.2, WIND, .4, .08, .95); pressure(jaw, 1.6, .3, WIND, .3); glowAt(jaw, 0xffffff, 1.2, .25, 2);
        for (let i = 0; i < 12; i++) { const d = dir.clone().add(V(rnd(-.4, .4), rnd(.4, 1.2), rnd(-.4, .4))).normalize(); streak(jaw, d, rnd(1.2, 2.4), 22, .28, WIND, .05, .9); }
        if (src.hp > 0) shove(src, dir, Q.knock, .35, Q.stagger);
        call('', 0);
      }
    }
  }

  // ---------- E: Ogre Rush ----------
  function beginOgre(c) {
    c.dir = A.flatForward(); c.duration = CFG.e.end;
    A.title('OGRE RUSH', '오거 러시', '돌진 18 → 왼손 바디 10 → 오른손 훅 15 → 내려찍기 20 · 최대 45', '#ff5a4a');
    sfx.stance();
  }
  function ghost() {
    const g = body.clone(true), m = new T.MeshBasicMaterial({ color: 0xffd9c2, transparent: true, opacity: .32, depthWrite: false });
    g.traverse(x => { if (x.isMesh) { x.material = m; x.castShadow = false; } }); g.visible = true;
    fx(g, .28, (o, u) => { m.opacity = .32 * (1 - u); }, () => m.dispose());
  }
  function updateOgre(c, a, dt) {
    const E = CFG.e, dir = c.dir;
    const crouch = outP(a / E.crouch, 2), dash = seg(a, E.crouch, E.dashEnd);
    if (a >= E.crouch && !c.flags.dash) {
      c.flags.dash = true; c.from = basePos.clone(); c.wall = wallAlong(c.from.clone().setY(0), dir, E.dash, .55);
      sfx.dash(); dustRing(basePos.clone().setY(0), 2.2, 10, .6, 3, dir.clone().negate());
    }
    if (c.flags.dash && !c.target && !c.whiff && a < E.dashEnd) {
      let along = E.dash * outP(dash, 1.6); if (c.wall) along = Math.min(along, c.wall.d);
      basePos.copy(c.from).addScaledVector(dir, along);
      const t = firstAhead(basePos, dir, E.reach, E.width);
      if (t && losClear(basePos.clone().setY(1.4), t.g.position.clone().setY(1.4))) {
        c.target = t; c.contact = a;
        const stop = t.g.position.clone().setY(basePos.y).addScaledVector(dir, -E.stop);
        if (stop.clone().sub(c.from).dot(dir) > along) basePos.copy(stop);
        c.hold = t.g.position.clone();
        handoff(t, { kind: 'ogre', drop: () => { c.lost = true; } });
      }
      if (A.time >= (c.nextGhost || 0)) { c.nextGhost = A.time + .045; ghost(); }
      for (let i = 0; i < 3; i++) { const o = camera.localToWorld(V(rnd(-1.6, 1.6), rnd(-1, 1), rnd(-2.5, -1))); streak(o, dir.clone().negate(), rnd(1.2, 2.4), 24, .18, WIND, .03, .7); }
      if (Math.random() < .7) dust(basePos.clone().setY(.3).addScaledVector(dir, -.6), 1.1, .5, dir.clone().multiplyScalar(-3).setY(.8));
    }
    if (!c.target && !c.whiff && a >= E.dashEnd) { c.whiff = a; c.duration = a + .45; A.toast('오거 러시 · 대상 없음' + (c.wall ? ' (벽에 막힘)' : '') + ' · 재사용 15초'); }
    const t = c.target;
    // Stop the chain the moment the target dies, vanishes or is torn out of reach.
    if (t && !c.stopped && (gone(t) || c.lost || t.g.position.distanceTo(c.hold) > E.escape)) { c.stopped = a; c.duration = Math.min(c.duration, a + .4); if (t.hp > 0 && !gone(t)) A.toast('대상 이탈 · 연계 중단'); }
    const live = t && !c.stopped;
    // Arms: crouch, left body blow, right hook, then both lowered while the leg does the axe kick.
    const lBody = outP(seg(a, E.body - .1, E.body), 3), lBack = ease(seg(a, E.body + .05, E.hook - .05));
    const hookCock = ease(seg(a, E.body - .05, E.hook - .12)), hook = outP(seg(a, E.hook - .12, E.hook), 3), hookBack = ease(seg(a, E.hook + .08, E.kick - .15));
    const settle = ease(seg(a, E.kickEnd, E.end));
    let L = lerpPose(lerpPose(lerpPose(L_REST, E_CROUCH_L, crouch), L_BODY, lBody), E_CROUCH_L, lBack);
    let R = lerpPose(lerpPose(lerpPose(lerpPose(REST, E_CROUCH_R, crouch), R_HOOK_COCK, hookCock), R_HOOK, hook), E_CROUCH_R, hookBack);
    if (c.whiff || c.stopped) { const s = ease(seg(a, c.whiff || c.stopped, (c.whiff || c.stopped) + .35)); L = lerpPose(L, L_REST, s); R = lerpPose(R, REST, s); }
    L = lerpPose(L, L_REST, settle); R = lerpPose(R, REST, settle);
    poseArm(arms.r, R); poseArm(arms.l, L);
    // Leg: chamber, raise above the head, drive the heel down; hip, knee and ankle each move.
    const kickOn = live || (c.flags.kick && a < E.end);
    const chamber = ease(seg(a, E.hook + .1, E.kick - .13)), raise = outP(seg(a, E.kick - .13, E.kick - .06), 2), drop = outP(seg(a, E.kick - .06, E.kick), 4), retract = ease(seg(a, E.kickEnd, E.end - .1));
    const hip = (1.3 * chamber + 1.4 * raise - 1.75 * drop) * (1 - retract), kn = (1.3 * chamber * (1 - raise) + .08) * (1 - retract), foot = -.5 * raise + .3 * drop;
    poseLeg(hip, kn, foot, kickOn && chamber > .01 && retract < .98);
    // Camera: low in the crouch, wide on the dash, small turns into each blow, look up at the raised leg, down on the slam.
    const low = crouch * (1 - dash);
    camera.position.y -= .45 * low + .15 * bump(a, E.body - .1, E.body + .1) - .1 * raise * (1 - drop);
    camera.rotation.y += .06 * bump(a, E.body - .1, E.body + .1) - .1 * bump(a, E.hook - .1, E.hook + .12);
    camera.rotation.z += -.05 * bump(a, E.hook - .1, E.hook + .15);
    camera.rotation.x += .14 * raise * (1 - drop) - .3 * drop * (1 - retract) - .2 * ease(seg(a, E.kickEnd, E.end)) * (1 - ease(seg(a, E.end - .1, E.end)));
    camera.fov = 66 - 6 * low + 22 * dash * (1 - ease(seg(a, E.dashEnd, E.dashEnd + .1))) + 6 * bump(a, E.kick - .02, E.kick + .2);
    vign = Math.max(vign, .5 * low + .3 * raise);
    // Body (third person): crouch, dash, blows, the axe kick.
    let P = lerpBP(B.idle, B.crouch, crouch); P = lerpBP(P, B.dash, dash * (1 - seg(a, E.dashEnd - .02, E.dashEnd + .05)));
    if (live || c.flags.kick) {
      P = lerpBP(P, B.body, lBody * (1 - lBack)); P = lerpBP(P, B.hookCock, hookCock * (1 - hook)); P = lerpBP(P, B.hook, hook * (1 - hookBack));
      P = lerpBP(P, B.kickUp, raise * (1 - drop)); P = lerpBP(P, B.kickDown, drop * (1 - retract));
    }
    bodyPose = lerpBP(P, B.idle, settle);
    if (!t) return;
    // Target reactions while held: folded forward after the body blow, head turned after the hook.
    const side = V().crossVectors(dir, UP).normalize(), m = movers.get(t);
    if (m?.kind === 'ogre') {
      t.g.position.copy(c.hold);
      const fold = c.flags.body ? -.32 * (1 - seg(a, E.body + .1, E.hook)) - .12 : 0, turn = c.flags.hook ? .32 * (1 - seg(a, E.hook + .2, E.kick)) : 0;
      tilt2(t, dir, fold, side, -turn); if (c.flags.hook) visor(t).rotation.y = .9 * (1 - seg(a, E.hook + .25, E.kick + .1));
      if (c.flags.body) squash(t, Math.max(0, 1 - (a - E.body) * 8));
    }
    if (!live) return;
    const chest = t.g.position.clone().setY(1.5), face = t.g.position.clone().setY(2.4);
    if (a >= E.body && !c.flags.body) {
      c.flags.body = true; A.hit(t, E.d1, '#ffffff'); sfx.body(); shake(.08); A.hitstop(40);
      ring(chest, dir, 1.6, WIND, .25, .05, .9); pressure(chest, .9, .2, WIND, .3);
    }
    if (a >= E.hook && !c.flags.hook && !gone(t)) {
      c.flags.hook = true; A.hit(t, E.d2, '#ffffff'); sfx.jab(); sfx.impact(); shake(.14); A.hitstop(55); screenFlash(.22);
      ring(face, side.clone().negate(), 2.6, WIND, .35, .07, .95); pressure(face, 1.2, .25, WIND, .3);
      for (let i = 0; i < 10; i++) { const d = side.clone().negate().add(V(rnd(-.3, .3), rnd(-.3, .4), rnd(-.3, .3))).normalize(); streak(face, d, rnd(1, 2), 20, .25, WIND, .05, .9); }
    }
    if (a >= E.kick && !c.flags.kick && !gone(t)) {
      c.flags.kick = true; A.hit(t, E.d3, '#ffe8d8'); sfx.impact(); sfx.thud(); sfx.crack(); shake(.24); A.hitstop(70); screenFlash(.25);
      const feet = t.g.position.clone().setY(0);
      ring(feet.clone().setY(.08), UP, 4.2, WIND, .5, .09, .95, .6); cracks(feet, 3.2, 12, 4); dustRing(feet, 4, 20, 1, 8);
      glowAt(face, 0xffffff, 1.3, .2, 2);
      if (t.hp > 0) { visor(t).rotation.y = 0; movers.delete(t); knockDown(t, dir, .6); }
    }
  }

  // ---------- R: Ogre's Judgment ----------
  function beginJudgment(c) {
    c.dir = A.flatForward(); c.aim = A.aimDir(); c.eye = basePos.clone(); c.duration = CFG.r.end;
    A.title('鬼の裁き', '오거의 심판', '배면귀 → 붙잡기 → 바디 15 · 따귀 15 · 연타 5×4 · 들어 올려 던지고 마지막 일격 50 · 최대 100', '#ff3a2a');
    sfx.heartbeat();
  }
  function pickJudgment(c) {
    const R = CFG.r, from = c.eye.clone(); let best = null, bestD = Infinity;
    for (const t of targets) {
      if (gone(t)) continue;
      const chest = t.g.position.clone().setY(1.4), d = chest.clone().sub(from), dist = d.length();
      if (dist > R.range || dist < .3) continue;
      if (d.normalize().dot(c.aim) < R.cone) continue;
      if (!losClear(from, chest)) continue;
      if (dist < bestD) { best = t; bestD = dist; }
    }
    return best;
  }
  function updateJudgment(c, a, dt) {
    const R = CFG.r;
    // 0-0.5: the serious face. Freeze, head down, colour drains, heartbeat, a low laugh.
    if (a < R.demon || !c.flags.cap) {
      const down = ease(seg(a, .05, .35)) * (1 - ease(seg(a, R.freeze - .05, R.freeze + .1)));
      gray = Math.max(gray, .85 * ease(seg(a, 0, .2)) * (1 - .55 * ease(seg(a, R.freeze, R.freeze + .2))) * (1 - .5 * ease(seg(a, R.demon, R.demon + .4))));
      if (a >= .22 && !c.flags.laugh) { c.flags.laugh = true; sfx.laugh(); }
      camera.rotation.x -= .45 * down; camera.fov = 66 - 6 * down; vign = Math.max(vign, .6 * down);
      const hang = pose([.52, -.74, -.82], [-.1, .3, -1], [-.95, -.3, 0], .85, .5, [1.05, -1.26, .1]);
      poseArm(arms.r, lerpPose(REST, hang, down)); poseArm(arms.l, lerpPose(L_REST, mirror(hang), down));
      bodyPose = lerpBP(B.idle, B.freeze, ease(seg(a, 0, .3)));
    }
    // 0.5-1.0: the Demon Back opens. Short rear third-person shot, arms spread, the back pulls into a face.
    if (a >= R.freeze && a < R.demon + .1) {
      const k = ease(seg(a, R.freeze, R.freeze + .25));
      bodyPose = lerpBP(B.freeze, B.spread, k); demonK = Math.max(demonK, ease(seg(a, R.freeze + .05, R.demon - .1)));
      if (!c.flags.boom && a >= R.freeze + .12) {
        c.flags.boom = true; sfx.boom(); shake(.1); redK = 1;
        const feet = basePos.clone().setY(0); dustRing(feet, 5, 26, 1.1, 8); ring(feet.clone().setY(.1), UP, 6, WIND, .6, .08, .7, .8); pressure(basePos.clone().setY(1.4), 3.5, .5, 0xffd8d0, .16);
      }
    }
    const cine = c.flags.cap ? 0 : ease(seg(a, R.freeze - .02, R.freeze + .1)) * (1 - ease(seg(a, R.demon - .08, R.demon + .04)));
    if (cine > 0) {
      const d = c.dir, me = basePos.clone();
      c.shot = { pos: me.clone().addScaledVector(d, -3.6).add(V(0, -.05, 0)).addScaledVector(V().crossVectors(d, UP), .5), look: me.clone().add(V(0, -.75, 0)), w: cine };
    } else c.shot = null;
    // 1.0: capture check (25 studs, 15 degrees of the view centre, line of sight, nearest first).
    if (a >= R.demon && !c.flags.pick) {
      c.flags.pick = true; const t = pickJudgment(c);
      if (!t) { c.fail = a; c.duration = a + .55; A.cooldowns.judgment = c.start + R.failCd; A.toast('오거의 심판 · 포착 실패 (25스터드 · 화면 중앙 15° · 시야) · 재사용 30초'); sfx.exhale(); }
      else {
        c.target = t; c.flags.cap = true; c.from = basePos.clone(); c.dir = t.g.position.clone().sub(basePos).setY(0).normalize();
        const want = t.g.position.clone().setY(EYE).addScaledVector(c.dir, -R.stop), dist = Math.max(0, want.clone().sub(c.from).dot(c.dir));
        const wall = wallAlong(c.from.clone().setY(0), c.dir, dist, .5); c.dashD = wall ? wall.d : dist;
        c.hold = c.from.clone().setY(0).addScaledVector(c.dir, c.dashD + R.stop);
        move(t, { kind: 'judg', drop: () => { c.lost = true; } });
        sfx.dash(); dustRing(basePos.clone().setY(0), 2.5, 12, .6, 4, c.dir.clone().negate());
      }
    }
    if (c.fail) {
      const k = a - c.fail, reach = outP(k / .15, 2), close = ease(seg(k, .15, .3)), back = ease(seg(k, .3, .55));
      let L = lerpPose(lerpPose(lerpPose(L_REST, L_REACH, reach), { ...L_REACH, curl: [1, 1, 1, 1, .9] }, close), L_REST, back);
      poseArm(arms.l, L); poseArm(arms.r, lerpPose(REST, R_LOWER, reach * (1 - back)));
      camera.position.addScaledVector(c.dir, .3 * bump(k, 0, .5)); camera.rotation.x -= .05 * bump(k, 0, .5);
      bodyPose = lerpBP(lerpBP(B.spread, B.reach, reach), B.idle, back); demonK = Math.max(0, 1 - k * 3);
      return;
    }
    if (!c.flags.cap) return;
    const t = c.target, dir = c.dir, side = V().crossVectors(dir, UP).normalize();
    if (!c.lost && gone(t)) { c.lost = true; A.toast(t.hp <= 0 ? '대상 쓰러짐 · 심판 종료' : '대상 이탈·삭제 · 심판 종료'); }
    if (c.lost && !c.flags.lostEnd) { c.flags.lostEnd = true; c.duration = Math.min(c.duration, a + .6); c.lostAt = a; }
    demonK = Math.max(demonK, c.lost ? 1 - seg(a, c.lostAt, c.lostAt + .5) : 1);
    // 1.0-1.5: dash in and grab with the left hand.
    const dashK = outP(seg(a, R.demon, R.grab - .02), 1.8);
    if (a < R.grab + .05) basePos.copy(c.from).addScaledVector(dir, c.dashD * dashK);
    if (a < R.grab && Math.random() < .7) { dust(basePos.clone().setY(.3).addScaledVector(dir, -.6), 1.1, .5, dir.clone().multiplyScalar(-3).setY(.8)); const o = camera.localToWorld(V(rnd(-1.6, 1.6), rnd(-1, 1), rnd(-2.5, -1))); streak(o, dir.clone().negate(), rnd(1.2, 2.4), 24, .18, WIND, .03, .7); }
    const reach = outP(seg(a, R.demon, R.grab), 2), grab = ease(seg(a, R.grab, R.grab + .08)), tug = bump(a, R.grab + .05, R.blow);
    // Stage timing helpers.
    const blowCock = ease(seg(a, R.capture, R.blow - .06)), blow = outP(seg(a, R.blow - .06, R.blow), 3), blowBack = ease(seg(a, R.blow + .08, R.slap - .2));
    const slapWind = ease(seg(a, R.blow + .12, R.slap - .07)), slap = outP(seg(a, R.slap - .07, R.slap), 3), slapBack = ease(seg(a, R.slap + .08, R.rush[0] - .12));
    const lift = ease(seg(a, R.lift, R.throw - .05)), throwK = outP(seg(a, R.throw, R.release), 2.5), wind = ease(seg(a, R.release, R.final - .02));
    const punch = outP(seg(a, R.final, R.punch), 3.5), lower = ease(seg(a, R.recover + .2, R.end - .1));
    // Rush: alternate R, L, R, L.
    let rushR = 0, rushL = 0;
    R.rush.forEach((h, i) => { const k = bump(a, h - .08, h + .08); if (i % 2) rushL = Math.max(rushL, k); else rushR = Math.max(rushR, k); });
    const inRush = a >= R.rush[0] - .12 && a < R.lift;
    // Left hand: reach, grab and hold the collar until the rush; then rush jabs; then both hands lift and throw.
    let Lp = lerpPose(lerpPose(L_REST, L_REACH, reach), L_GRAB, grab);
    Lp = lerpPose(Lp, L_TUG, tug * .7);
    if (inRush) Lp = lerpPose(lerpPose(Lp, mirror(R_LOW_COCK), ease(seg(a, R.rush[0] - .12, R.rush[0]))), mirror(R_JAB), rushL);
    Lp = lerpPose(Lp, mirror(R_LIFT), lift); Lp = lerpPose(Lp, mirror(R_THROW), throwK); Lp = lerpPose(Lp, mirror(R_LOWER), wind * .9);
    Lp = lerpPose(Lp, L_REST, lower);
    let Rp = lerpPose(lerpPose(lerpPose(REST, R_LOW_COCK, blowCock * (1 - blow)), R_BLOW, blow), R_LOW_COCK, blowBack);
    Rp = lerpPose(lerpPose(Rp, R_SLAP_WIND, slapWind), R_SLAP, slap); Rp = lerpPose(Rp, R_LOW_COCK, slapBack);
    if (inRush) Rp = lerpPose(Rp, R_JAB, rushR);
    Rp = lerpPose(Rp, R_LIFT, lift); Rp = lerpPose(Rp, R_THROW, throwK); Rp = lerpPose(Rp, R_WIND, wind); Rp = lerpPose(Rp, R_FINAL, punch);
    Rp = lerpPose(Rp, R_LOWER, ease(seg(a, R.recover, R.recover + .3))); Rp = lerpPose(Rp, REST, lower);
    // Body (third person) follows the same beats.
    let P = lerpBP(B.spread, B.reach, reach); P = lerpBP(P, B.grab, grab);
    P = lerpBP(P, B.blowCock, blowCock * (1 - blow)); P = lerpBP(P, B.blow, blow * (1 - blowBack)); P = lerpBP(P, B.slapWind, slapWind * (1 - slap)); P = lerpBP(P, B.slap, slap * (1 - slapBack));
    if (inRush) P = lerpBP(P, rushR >= rushL ? B.jabR : B.jabL, Math.max(rushR, rushL));
    P = lerpBP(P, B.lift, lift); P = lerpBP(P, B.throw, throwK); P = lerpBP(P, B.wind, wind); P = lerpBP(P, B.final, punch); P = lerpBP(P, B.recover, ease(seg(a, R.recover, R.recover + .3)));
    bodyPose = c.lost ? lerpBP(P, B.idle, seg(a, c.lostAt, c.lostAt + .4)) : P;
    if (c.lost) { Lp = lerpPose(Lp, L_REST, seg(a, c.lostAt, c.lostAt + .3)); Rp = lerpPose(Rp, REST, seg(a, c.lostAt, c.lostAt + .3)); }
    poseArm(arms.l, Lp); poseArm(arms.r, Rp);
    // Target: held at the collar, buckles, head snaps, shakes, lifted, thrown, then driven into the ground.
    const m = movers.get(t);
    if (!c.lost && m?.kind === 'judg') {
      let pos = c.hold.clone(), fwd = 0, sideT = 0;
      if (a >= R.blow) fwd = -.24 * (1 - seg(a, R.blow + .1, R.slap - .1)) - .06;
      if (a >= R.slap) { sideT = .35 * (1 - seg(a, R.slap + .15, R.rush[0])); visor(t).rotation.y = -1 * (1 - seg(a, R.slap + .2, R.rush[0] + .1)); }
      R.rush.forEach(h => { if (a >= h) fwd += .14 * Math.max(0, 1 - (a - h) * 7); });
      const liftY = R.liftH * lift;
      if (a >= R.release) {
        // Thrown forward and up a little, falling into the last punch.
        const u = seg(a, R.release, R.punch); pos.addScaledVector(dir, 1.2 * outP(u, 2)); pos.y = liftY + .5 * Math.sin(u * Math.PI) - .9 * u * u;
        fwd = .3 + .5 * u; sideT = .2 * Math.sin(u * 5);
        const w = wallAlong(c.hold, dir, 1.4); if (w) pos.copy(c.hold).addScaledVector(dir, Math.min(1.2 * outP(u, 2), Math.max(0, w.d - .5))).setY(pos.y);
      } else pos.y = liftY;
      t.g.position.copy(pos); tilt2(t, dir, fwd, side, sideT);
      const [la, ra] = limbs(t);
      if (lift > .02) { const sw = Math.sin(A.time * 7); la.rotation.set(.25 * sw, 0, -.15); ra.rotation.set(-.25 * sw, 0, .15); }
      if (a >= R.release) flail(t, .8);
      if (a >= R.blow) squash(t, Math.max(0, 1 - (a - R.blow) * 8) + (a >= R.punch ? 0 : 0));
    }
    // Camera: locked on the target's chest; a sideways jolt on the slap; up during the lift; the side shot before the last punch.
    const chest = t.g.position.clone().setY(t.g.position.y + 1.6);
    if (!c.lost) lookAtBlend(chest, .7 * ease(seg(a, R.demon, R.grab)) * (1 - .6 * ease(seg(a, R.recover + .1, R.end))), 1.1);
    camera.rotation.z += .08 * bump(a, R.slap - .05, R.slap + .2);
    camera.position.addScaledVector(dir, .25 * blow * (1 - blowBack) + .5 * punch * (1 - lower));
    camera.fov = (66 + 16 * bump(a, R.demon, R.grab + .1) - 4 * lift + 14 * punch * (1 - ease(seg(a, R.punch + .05, R.recover + .2)))) * (1 - lower) + 66 * lower;
    vign = Math.max(vign, .3 + .4 * wind * (1 - punch));
    if (a >= R.recover) camera.rotation.x -= .32 * ease(seg(a, R.recover, R.recover + .4)) * (1 - ease(seg(a, R.end - .3, R.end)));
    const sideShot = !c.lost && a >= R.release - .04 ? ease(seg(a, R.release - .04, R.release + .06)) * (1 - ease(seg(a, R.final - .06, R.final + .01))) : 0;
    if (sideShot > 0) {
      const me = basePos.clone();
      c.shot = { pos: me.clone().addScaledVector(side, 3).addScaledVector(dir, -2.4).add(V(0, -.1, 0)), look: me.clone().lerp(chest, .45).add(V(0, -.4, 0)), w: sideShot };
    }
    // Step in behind the punch.
    if (a >= R.final - .1 && a < R.punch && !c.lost) basePos.addScaledVector(dir, dt * 4);
    // Hits, once each, on the animation beats.
    const hitAt = (key, at, dmg, fxFn) => { if (!c.lost && a >= at && !c.flags[key]) { c.flags[key] = true; if (!gone(t)) { if (dmg) A.hit(t, dmg, '#ffffff'); fxFn(); } } };
    hitAt('grabbed', R.grab, 0, () => { sfx.body(); shake(.05); });
    hitAt('blow', R.blow, R.d1, () => { const p = t.g.position.clone().setY(t.g.position.y + 1.4); sfx.body(); sfx.impact(); shake(.14); A.hitstop(50); ring(p, dir, 1.8, WIND, .28, .06, .9); pressure(p, 1, .22, WIND, .3); });
    hitAt('slap', R.slap, R.d2, () => { const p = t.g.position.clone().setY(t.g.position.y + 2.35); sfx.slap(); shake(.12); A.hitstop(40); screenFlash(.15); ring(p, side.clone().negate(), 1.6, WIND, .25, .05, .9); });
    R.rush.forEach((h, i) => hitAt('rush' + i, h, R.d3, () => { const p = t.g.position.clone().setY(t.g.position.y + 2 - (i % 2) * .5); sfx.jab(); shake(.07); ring(p, dir, 1.2, WIND, .18, .05, .85); }));
    if (!c.lost && a >= R.lift && !c.flags.liftS) { c.flags.liftS = true; sfx.lift(); }
    if (!c.lost && a >= R.release && !c.flags.throwS) { c.flags.throwS = true; sfx.whoosh(); duck(R.punch - R.release - .02); call('', 0); }
    if (!c.lost && a >= R.punch && !c.flags.final) {
      c.flags.final = true;
      if (!gone(t)) {
        A.hit(t, R.d4, '#ffe0d0');
        const p = t.g.position.clone().setY(t.g.position.y + 1.3), ground = c.hold.clone().addScaledVector(dir, 1.2); ground.y = 0;
        sfx.impact(); sfx.boom(); sfx.crack(); A.hitstop(80); shake(.45); screenFlash(.6); A.flash('#ffffff', .25);
        ring(p, dir, 4.5, WIND, .45, .12, .95); ring(p, dir, 2.6, WIND, .3, .07, .9, .2); pressure(p, 2.6, .35, WIND, .3); glowAt(p, 0xffffff, 2.4, .25, 2.5);
        for (let i = 0; i < 20; i++) { const d = dir.clone().add(V(rnd(-.5, .5), rnd(-.8, .2), rnd(-.5, .5))).normalize(); streak(p, d, rnd(2, 4), 34, .3, WIND, .06, .9); }
        const g = safeGround(ground, dir.clone().negate());
        ring(g.clone().setY(.1), UP, 8, WIND, .6, .14, .95, .8); cracks(g, 6, 18, 6); dustRing(g, 8, 32, 1.6, 18);
        if (t.hp > 0) {
          const from = t.g.position.clone();
          handoff(t, { kind: 'slam', update(age) {
            const u = outP(age / .1, 2); t.g.position.lerpVectors(from, g, u); setTilt(t, dir, Math.PI / 2 * u); squash(t, u);
            if (age >= .1) { t.g.position.copy(g); knockDown(t, dir, R.down); }
          } });
        }
      }
    }
    if (a >= R.recover + .3 && !c.flags.exhale && !c.lost) { c.flags.exhale = true; sfx.exhale(); }
  }

  // ---------- app hooks ----------
  function begin(c) {
    c.yujiro = true; c.flags = c.flags || {};
    if (c.type === 'counter') beginCounter(c);
    if (c.type === 'ogre') beginOgre(c);
    if (c.type === 'judgment') beginJudgment(c);
  }
  function update(c, a, dt) {
    if (c.type === 'counter') updateCounter(c, a, dt);
    else if (c.type === 'ogre') updateOgre(c, a, dt);
    else if (c.type === 'judgment') updateJudgment(c, a, dt);
  }
  function end(c) {
    if (c.type === 'counter') {
      if (c.read && c.hit) { buffUntil = A.time + CFG.q.buffDur; A.toast('반격 성공 · 기본공격 +15% 0.5초'); }
      if (c.src && movers.get(c.src)?.kind === 'read') release(c.src);
    }
    if (c.type === 'ogre') { const t = c.target; if (t && movers.get(t)?.kind === 'ogre') { release(t); visor(t).rotation.y = 0; } }
    if (c.type === 'judgment') {
      const t = c.target;
      if (t) { visor(t).rotation.y = 0; const m = movers.get(t); if (m && (m.kind === 'judg' || m.kind === 'slam')) { release(t); if (t.hp > 0 && !gone(t)) fall(t, c.dir, V(), .5, 30); } }
      demonK = 0; unduck(); if (basePos.y !== EYE) basePos.y = EYE;
    }
    c.shot = null; leg.visible = false; gray = 0; bodyPose = B.idle;
  }
  function victimOf(c) {
    if (!c?.yujiro) return null;
    if (c.type === 'counter') return c.read && !gone(c.src) ? c.src : null;
    if (c.type === 'ogre') return c.target && !c.stopped && !gone(c.target) ? c.target : null;
    if (c.type === 'judgment') return c.target && c.flags.cap && !c.lost && !gone(c.target) || (c.target && c.flags.final && !gone(c.target)) ? c.target : null;
    return null;
  }
  const _hp = V();
  function frame(dt, moving) {
    const c = A.cast, now = A.time;
    if (!active) { arms.r.g.visible = arms.l.g.visible = arms.r.up.visible = arms.l.up.visible = false; leg.visible = false; body.visible = false; return; }
    updateAttacker(dt);
    // Idle and running arms: loose heavy fists, a slow breath; basic attacks are heavy straight punches.
    if (!c?.yujiro) {
      bodyPose = B.idle;
      const m = A.melee, run = moving ? 1 : 0, sw = moving ? Math.sin(now * 9) : 0, idle = Math.sin(now * 1.4) * .012;
      const R = { ...REST, pos: REST.pos.clone().add(V(0, idle + .06 * Math.max(0, sw) * run - .04 * run, -.22 * sw * run)) };
      const L = { ...L_REST, pos: L_REST.pos.clone().add(V(0, idle + .06 * Math.max(0, -sw) * run - .04 * run, .22 * sw * run)) };
      const recover = now < recoverUntil ? 1 : 0;
      if (recover) { R.pos = R.pos.clone().add(V(0, -.08, 0)); L.pos = L.pos.clone().add(V(0, -.08, 0)); }
      if (m) {
        const a = now - m.start, wind = ease(a / m.windup), strike = outP((a - m.windup) / m.swing, 3), back = ease((a - m.windup - m.swing) / Math.max(.05, m.duration - m.windup - m.swing));
        const side = m.combo % 2 ? 1 : -1, rest = side > 0 ? R : L;
        const cock = pose([side * .72, -.62, -.62], [-side * .15, .2, -1], [-side * .3, -1, 0], 1, .7, [side * 1.1, -1.12, .32]);
        const hitP = pose([side * .1, -.32, -1.46], [0, .05, -1], [0, -1, 0], 1, 1, [side * .78, -.95, -.25]);
        const P = lerpPose(lerpPose(lerpPose(rest, cock, wind), hitP, strike), rest, back);
        if (side > 0) { poseArm(arms.r, P); poseArm(arms.l, L); } else { poseArm(arms.l, P); poseArm(arms.r, R); }
        meleeFov = 4 * strike * (1 - back);
      } else { poseArm(arms.r, R); poseArm(arms.l, L); }
      if (moving) { camera.position.y -= .08; camera.rotation.z += sw * .005; }
      leg.visible = false;
    }
    camera.fov += meleeFov; meleeFov = 0;
    if (now < buffUntil) { for (const arm of [arms.r, arms.l]) if (arm.g.visible && Math.random() < .3) dust(camera.localToWorld(arm.g.position.clone().add(V(rnd(-.1, .1), rnd(-.3, .1), 0))), .3, .5, V(rnd(-.2, .2), .8, rnd(-.2, .2)), 0xffffff, .4); }
    // Victims.
    for (const [t, m] of [...movers]) { if (t.hp <= 0 || t.g.visible === false) { movers.delete(t); calm(t); visor(t).rotation.y = 0; t.locked = false; continue; } m.update?.call(m, now - m.born, dt); }
    // Camera: cinematic cuts, the victim's eyes or the spectator, otherwise first person.
    fp = true; label = '';
    const dir = c?.yujiro ? c.dir : A.flatForward();
    poseBody(bodyPose, dir);
    const vic = viewMode === 'victim' ? victimOf(c) : null;
    if (vic) {
      const hd = vic.g.children[5].getWorldPosition(_hp), look = head.getWorldPosition(V());
      const eye = hd.clone().addScaledVector(look.clone().sub(hd).normalize(), .4);
      camera.position.copy(eye); camera.lookAt(look); camera.fov = 70; fp = false;
      label = '피격자 시점 · ' + (c.type === 'counter' ? '반격당하는 공격자' : c.type === 'ogre' ? '오거 러시' : '오거의 심판');
    } else if (viewMode === 'spectator' && c?.yujiro) {
      const t = c.target || c.src, mid = basePos.clone().setY(1.2); if (t && !gone(t)) mid.lerp(t.g.position.clone().setY(1.4), .5);
      const side = V().crossVectors(dir, UP).normalize(), ang = (now - c.start) * .15;
      const pos = mid.clone().addScaledVector(side.applyAxisAngle(UP, ang), 6).add(V(0, 1.6, 0));
      placeCamera(pos, mid, 1); camera.fov = 60; fp = false; label = '관전자 시점 · 실제 3D 전투';
    } else if (c?.yujiro && c.shot && c.shot.w > .01) {
      placeCamera(c.shot.pos, c.shot.look, c.shot.w); camera.fov = mix(camera.fov, 58, c.shot.w); if (c.shot.w > .5) fp = false;
    }
    body.visible = !fp;
    if (!fp) { arms.r.g.visible = arms.l.g.visible = arms.r.up.visible = arms.l.up.visible = false; leg.visible = false; }
    // Shake (after any camera override so victims and spectators feel the hits too).
    if (shakeAmp > .001) { camera.position.x += rnd() * shakeAmp; camera.position.y += rnd() * shakeAmp; camera.rotation.z += rnd() * shakeAmp * .25; shakeAmp *= Math.exp(-9 * dt); }
    // Screen layers.
    vign *= Math.exp(-3 * dt); ovV.style.opacity = Math.min(1, vign).toFixed(3);
    ovR.style.opacity = (.55 * redK * (c?.yujiro && c.type === 'judgment' ? 1 : 0)).toFixed(3); redK = Math.max(c?.yujiro && c.type === 'judgment' && c.flags.cap && !c.lost ? .35 : 0, redK - dt * .9);
    ovF.style.opacity = flashV.toFixed(3); flashV *= Math.exp(-8 * dt);
    if (gray > .01) { $('scene').style.filter = `grayscale(${gray.toFixed(2)}) contrast(1.12)`; filterOn = true; } else if (filterOn) { $('scene').style.filter = ''; filterOn = false; }
    if (!c?.yujiro || c.type !== 'judgment') gray = 0; else gray = Math.max(0, gray - dt * 1.4);
    const ca = now - callAt;
    if (callText && ca >= 0 && ca < callLife) { const fade = 1 - ease((ca - callLife + .3) / .3); ovT.textContent = callText; ovT.style.opacity = fade.toFixed(3); ovS.textContent = callSub; ovS.style.opacity = (callSub ? fade : 0).toFixed(3); }
    else { ovT.style.opacity = 0; ovS.style.opacity = 0; }
    ovL.textContent = label; ovL.style.opacity = label ? 1 : 0;
    // Effects.
    for (let i = fxs.length - 1; i >= 0; i--) { const e = fxs[i], u = (now - e.born) / e.life; if (u >= 1) { fxs.splice(i, 1); e.done?.(); kill(e.obj); } else e.update?.(e.obj, u, dt); }
  }
  // No moving, jumping or dashing in the stance, the rush or the judgment; a short heavy step after a failed read.
  function speed() {
    const c = A.cast;
    if (c?.yujiro) return c.type === 'counter' && c.flags.fail ? .3 : 0;
    return A.time < recoverUntil ? .3 : 1;
  }
  const basicFactor = () => active && A.time < buffUntil ? CFG.q.basic : 1;
  function hud() {
    const c = A.cast, now = A.time, y = c?.yujiro ? c : null;
    $('qBtn').classList.toggle('combo', now < buffUntil);
    $('qBtn').querySelector('.skill-type').textContent = y?.type === 'counter' ? (y.read ? (y.hit ? '반격 성공' : '반격') : y.flags.fail ? '실패 · 경직' : (now - y.start < CFG.q.enter ? '자세' : '읽는 중 · 정면 -70%')) : now < buffUntil ? '기본공격 +15% ' + (buffUntil - now).toFixed(1) + '초' : '정면 160° 반격 · 30';
    $('eBtn').querySelector('.skill-type').textContent = y?.type === 'ogre' ? (y.whiff ? '빗나감' : y.stopped ? '연계 중단' : y.flags.kick ? '내려찍기!' : y.flags.hook ? '훅' : y.flags.body ? '바디' : y.target ? '연계' : '돌진') : '18 돌진 · 10+15+20';
    $('rBtn').querySelector('.skill-type').textContent = y?.type === 'judgment' ? (y.fail ? '포착 실패 · 30초' : y.lost ? '종료' : y.flags.final ? '심판' : y.flags.cap ? '붙잡음' : '배면귀') : '25 · 15° 포착 · 최대 100';
    const d = $('debuff'); d.classList.add('on');
    d.textContent = y?.type === 'judgment' ? '오거의 심판 · 경직 저항 · 받는 피해 -30%' : y?.type === 'counter' && !y.read && !y.flags.fail ? '반격 자세 · 정면 160° 직접 공격 반격 · 정면 피해 -70% · 등 뒤는 감소 없음'
      : now < recoverUntil ? '반격 실패 · 경직 ' + (recoverUntil - now).toFixed(1) + '초' : now < buffUntil ? '반격 성공 · 기본공격 +15%' : '지상 최강의 생물 · F/B/G 공격 받기 테스트';
  }
  function killTarget() {
    const c = A.cast, t = c?.target && !gone(c.target) ? c.target : c?.src && !gone(c.src) ? c.src : targets.find(o => !gone(o));
    if (!t) return; A.hit(t, 9999, '#ffffff'); A.toast('대상 처치 테스트 · 연계와 구속을 정리합니다');
  }
  function targetGone() {
    const c = A.cast, t = c?.target && !gone(c.target) ? c.target : null;
    if (!t) { A.toast('이탈 테스트 · 지금 잡고 있는 대상이 없습니다 (E 연계나 R 포착 중에 누르세요)'); return; }
    if (c.type === 'ogre') { movers.delete(t); calm(t); t.locked = false; t.g.position.addScaledVector(c.dir, 5); A.toast('이탈 테스트 · 대상이 연계 범위를 벗어났습니다'); }
    else { movers.delete(t); calm(t); t.locked = false; t.g.visible = false; t.respawn = A.time + 3; t.hp = 0; A.toast('삭제 테스트 · 붙잡힌 대상이 사라졌습니다 (나가기·삭제와 같음)'); }
  }
  function casterDies() {
    const c = A.cast;
    if (c?.yujiro) { c.duration = 0; c.killed = true; }
    A.toast('시전자 사망 테스트 · 스킬을 끊고 대상·카메라·속도를 되돌렸습니다'); A.flash('#000000', .5); A.hp = 200;
  }
  function reset() {
    for (const e of fxs.splice(0)) kill(e.obj);
    for (const o of [...live]) kill(o);
    for (const [t] of movers) { calm(t); visor(t).rotation.y = 0; t.locked = false; t.g.userData.cannonUntil = 0; }
    movers.clear(); for (const t of [...targets, ...extras]) { calm(t); visor(t).rotation.y = 0; }
    if (attacker.lunge) endAttacker();
    buffUntil = 0; recoverUntil = 0; shakeAmp = 0; flashV = 0; vign = 0; redK = 0; gray = 0; demonK = 0; meleeFov = 0; callAt = -9; bodyPose = B.idle;
    body.visible = false; leg.visible = false; if (basePos.y > EYE) basePos.y = EYE; unduck();
    if (filterOn) { $('scene').style.filter = ''; filterOn = false; }
    ovV.style.opacity = ovR.style.opacity = ovF.style.opacity = ovT.style.opacity = ovS.style.opacity = ovL.style.opacity = 0;
  }
  function activate(on) {
    active = on; panel.hidden = !on; document.body.classList.toggle('yujiro', on);
    for (const t of extras) {
      const i = targets.indexOf(t);
      if (on && i < 0) targets.push(t); if (!on && i >= 0) targets.splice(i, 1);
      t.hp = t.max; t.g.visible = on; t.g.position.copy(t.home); t.bar.scale.x = 1; t.bar.position.x = 0; t.locked = false; t.respawn = 0; t.vel = null; t.landed = 0; calm(t);
    }
    if (!on) { if (attacker.lunge) endAttacker(); arms.r.g.visible = arms.l.g.visible = arms.r.up.visible = arms.l.up.visible = false; leg.visible = false; body.visible = false; $('debuff').textContent = ''; $('debuff').classList.remove('on'); }
    refreshPanel();
  }
  function state() {
    const c = A.cast;
    return { active, view: viewMode, buff: A.time < buffUntil, speed: +speed().toFixed(2), hp: A.hp, demon: +demonK.toFixed(2), fp,
      cast: c?.yujiro ? { type: c.type, age: +(A.time - c.start).toFixed(2), read: c.read ?? null, hit: !!c.hit, target: c.target?.index ?? null, lost: !!c.lost, fail: !!c.fail, whiff: !!c.whiff, stopped: !!c.stopped, flags: Object.keys(c.flags) } : null,
      attacker: attacker.lunge ? { kind: attacker.lunge.kind, hp: attacker.hp, countered: !!attacker.lunge.countered } : null,
      pos: basePos.toArray().map(v => +v.toFixed(2)), movers: [...movers].map(([t, m]) => t.index + ':' + m.kind), fx: fxs.length, live: live.size,
      targets: targets.map(t => ({ i: t.index, hp: t.hp, pos: t.g.position.toArray().map(v => +v.toFixed(1)), vis: t.g.visible })) };
  }
  return { begin, update, end, frame, speed, hud, reset, activate, state, basicFactor, enemyAttack, cycleView, setView: v => { viewMode = v; refreshPanel(); }, killTarget, targetGone, casterDies, skills: new Set(['counter', 'ogre', 'judgment']) };
};

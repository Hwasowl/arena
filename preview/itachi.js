// Itachi Uchiha for the browser preview. Timings match roblox/src/ReplicatedStorage/ItachiConfig.luau; distances are
// Roblox studs times S (the preview body is about 0.6 of a Roblox character). Loaded as a classic script before app.js,
// which calls window.ItachiPreview(api) once its scene, targets and helpers exist.
// The preview keeps the same split as the game: the "server" part (who is hit, damage, binds, passive roll) is plain
// logic in this file, the rest is presentation. Victim-side views (Tsukuyomi world, Susanoo seal) are shown by
// switching the camera to the dummy's head: V cycles auto / caster / victim.
window.ItachiPreview = function (A) {
  'use strict';
  const T = A.T, scene = A.scene, camera = A.camera, targets = A.targets, basePos = A.basePos;
  const $ = id => document.getElementById(id);
  const clamp = T.MathUtils.clamp, mix = T.MathUtils.lerp;
  const ease = x => { x = clamp(x, 0, 1); return x * x * (3 - 2 * x); };
  const outP = (x, p = 3) => 1 - Math.pow(1 - clamp(x, 0, 1), p);
  const inP = (x, p = 2) => Math.pow(clamp(x, 0, 1), p);
  const seg = (a, from, to) => clamp((a - from) / (to - from), 0, 1);
  const bump = (a, from, to) => Math.sin(seg(a, from, to) * Math.PI);
  const rnd = (a = -1, b = 1) => a + Math.random() * (b - a);
  const V = (x = 0, y = 0, z = 0) => new T.Vector3(x, y, z);
  const S = .6, EYE = 2.1, UP = V(0, 1, 0);
  const CFG = {
    crow: { chance: .2, icd: 25, back: 12 * S, total: .85, damage: 12 },
    q: { range: 35 * S, angle: 12, damage: 12, bind: 1.4, failCd: 1.5, prep: .3, eye: .55, world: .9, wave: 1.35, crack: 1.5, end: 1.95 },
    e: { range: 65 * S, radius: 20 * S, start: 3 * S, aim: .2, ignite: .55, spread: .8, full: 1.5, burnEnd: 6, gone: 6.7, entry: 10, tick: 6, ticks: 5, slow: .8, flameH: 5 * S },
    // R: Susanoo forms, smashes everything in front three times, then the Totsuka Blade thrusts and seals one target.
    r: { ribs: .5, upper: .9, mirror: 1.4, s1w: 1.6, s1: 1.85, s2w: 2.15, s2: 2.45, s3w: 2.75, s3: 3.05,
      blade: 3.2, aim: 3.7, thrust: 4.0, tip: 4.2, strikeEnd: 4.45, seal: 4.8, sealHit: 5.15, sealEnd: 5.5, end: 6.6, sealFor: 1.8,
      reach: 35 * S, width: 2.4, strikeR: 28 * S, hits: [24, 24, 30], arcs: [55, 85, 50], d1: 10, d2: 15, guard: .4 },
  };
  const RED = 0xd8141c, DEEP = 0x5a0006, GOLD = 0xffc24a, BLACK = 0x060607;

  // ---------- textures ----------
  function canvasTex(size, draw, w = size, h = size) {
    const c = document.createElement('canvas'); c.width = w; c.height = h; draw(c.getContext('2d'), w, h);
    const t = new T.CanvasTexture(c); t.colorSpace = T.SRGBColorSpace; return t;
  }
  const glowTex = canvasTex(128, (g, s) => {
    const r = g.createRadialGradient(s / 2, s / 2, 0, s / 2, s / 2, s / 2);
    r.addColorStop(0, 'rgba(255,255,255,1)'); r.addColorStop(.2, 'rgba(255,255,255,.6)'); r.addColorStop(.5, 'rgba(255,255,255,.15)'); r.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = r; g.fillRect(0, 0, s, s);
  });
  const smokeTex = canvasTex(128, (g, s) => {
    const r = g.createRadialGradient(s / 2, s / 2, 0, s / 2, s / 2, s / 2);
    r.addColorStop(0, 'rgba(255,255,255,.8)'); r.addColorStop(.5, 'rgba(255,255,255,.35)'); r.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = r; g.fillRect(0, 0, s, s);
  });
  // The Akatsuki cloud: red puffs with a white rim, scattered on black cloth.
  function cloud(g, x, y, s) {
    const puffs = [[0, 0, 1], [-.9, .15, .75], [.9, .1, .8], [-.4, -.45, .7], [.45, -.5, .72], [-.35, .55, .6], [.4, .5, .62]];
    g.fillStyle = '#f2f0ec'; for (const [a, b, r] of puffs) { g.beginPath(); g.arc(x + a * s, y + b * s, r * s * .62 + 3, 0, 7); g.fill(); }
    g.fillStyle = '#c3121b'; for (const [a, b, r] of puffs) { g.beginPath(); g.arc(x + a * s, y + b * s, r * s * .62, 0, 7); g.fill(); }
  }
  const cloakTex = canvasTex(256, (g, w, h) => { g.fillStyle = '#0b0b0f'; g.fillRect(0, 0, w, h); cloud(g, 70, 70, 26); cloud(g, 190, 170, 22); cloud(g, 60, 215, 18); });
  cloakTex.wrapS = cloakTex.wrapT = T.RepeatWrapping;
  // Itachi's Mangekyo: red iris, black ring, three curved blades joined at the pupil.
  function drawSharingan(g, s, spin = 0) {
    const c = s / 2; g.clearRect(0, 0, s, s);
    const iris = g.createRadialGradient(c, c, s * .05, c, c, s * .48); iris.addColorStop(0, '#ff2a2a'); iris.addColorStop(.7, '#c40810'); iris.addColorStop(1, '#5a0004');
    g.fillStyle = iris; g.beginPath(); g.arc(c, c, s * .47, 0, 7); g.fill();
    g.strokeStyle = '#120000'; g.lineWidth = s * .03; g.beginPath(); g.arc(c, c, s * .46, 0, 7); g.stroke();
    g.fillStyle = '#0a0000';
    for (let i = 0; i < 3; i++) {
      const a = spin + i * Math.PI * 2 / 3; g.save(); g.translate(c, c); g.rotate(a); g.beginPath();
      g.moveTo(0, -s * .06); g.quadraticCurveTo(s * .2, -s * .18, s * .38, -s * .06); g.quadraticCurveTo(s * .3, s * .02, s * .16, s * .08); g.quadraticCurveTo(s * .07, s * .08, 0, s * .06); g.closePath(); g.fill(); g.restore();
    }
    g.beginPath(); g.arc(c, c, s * .085, 0, 7); g.fill();
  }
  const eyeCanvas = document.createElement('canvas'); eyeCanvas.width = eyeCanvas.height = 256; drawSharingan(eyeCanvas.getContext('2d'), 256);
  const eyeTex = new T.CanvasTexture(eyeCanvas); eyeTex.colorSpace = T.SRGBColorSpace;
  // Yata Mirror face: dark red disc with gold rings and flowing script-like marks.
  const mirrorTex = canvasTex(256, (g, s) => {
    const c = s / 2, r = g.createRadialGradient(c, c, 0, c, c, c); r.addColorStop(0, 'rgba(255,190,90,.55)'); r.addColorStop(.55, 'rgba(200,30,30,.55)'); r.addColorStop(1, 'rgba(120,0,0,.75)');
    g.fillStyle = r; g.beginPath(); g.arc(c, c, c - 2, 0, 7); g.fill();
    g.strokeStyle = 'rgba(255,214,120,.95)'; for (const [rr, w] of [[.96, 6], [.78, 3], [.5, 3], [.2, 2]]) { g.lineWidth = w; g.beginPath(); g.arc(c, c, c * rr - 3, 0, 7); g.stroke(); }
    g.lineWidth = 2.5; for (let i = 0; i < 24; i++) { const a = i / 24 * Math.PI * 2; g.beginPath(); g.moveTo(c + Math.cos(a) * c * .52, c + Math.sin(a) * c * .52); g.quadraticCurveTo(c + Math.cos(a + .14) * c * .66, c + Math.sin(a + .14) * c * .66, c + Math.cos(a + .05) * c * .76, c + Math.sin(a + .05) * c * .76); g.stroke(); }
  });

  // A flame tongue: a white teardrop with a soft edge, tinted per use (black for Amaterasu, red for Susanoo).
  const flameTex = canvasTex(128, (g, w, h) => {
    const grd = g.createRadialGradient(w / 2, h * .74, 2, w / 2, h * .62, w * .55);
    grd.addColorStop(0, 'rgba(255,255,255,1)'); grd.addColorStop(.5, 'rgba(255,255,255,.8)'); grd.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = grd; g.beginPath(); g.moveTo(w * .52, 1);
    g.bezierCurveTo(w * .6, h * .28, w * .98, h * .5, w * .84, h * .8); g.bezierCurveTo(w * .72, h * .99, w * .28, h * .99, w * .16, h * .8);
    g.bezierCurveTo(w * .02, h * .52, w * .42, h * .34, w * .52, 1); g.fill();
  }, 64, 128);

  // ---------- effect bookkeeping ----------
  const fxs = [], live = new Set(), SHARED = new Set();
  function kill(o) {
    if (!o) return; o.parent?.remove(o); live.delete(o);
    o.traverse(x => { if (x.geometry && !SHARED.has(x.geometry)) x.geometry.dispose(); for (const m of [].concat(x.material || [])) if (!SHARED.has(m)) m.dispose(); });
  }
  function fx(obj, life, update, done) { if (obj && !obj.parent) scene.add(obj); const e = { obj, born: A.time, life, update, done }; fxs.push(e); return e; }
  function keep(obj, parent = scene) { parent.add(obj); live.add(obj); return obj; }
  function sprite(tex, color, opacity = 1, additive = false) {
    return new T.Sprite(new T.SpriteMaterial({ map: tex, color, transparent: true, depthWrite: false, opacity, blending: additive ? T.AdditiveBlending : T.NormalBlending }));
  }
  function puff(pos, size, life, vel, color = 0x1a1a1e, opacity = .6) {
    const s = sprite(smokeTex, color, opacity); s.position.copy(pos); s.scale.setScalar(size * .5); const v = vel ? vel.clone() : V(0, .5, 0);
    return fx(s, life, (o, u, dt) => { o.position.addScaledVector(v, dt); o.scale.setScalar(size * (.5 + u)); o.material.opacity = opacity * (1 - u) * Math.min(1, u * 8 + .2); });
  }
  function glowAt(pos, color, size, life, grow = 1.5, opacity = 1) {
    const s = sprite(glowTex, color, opacity, true); s.position.copy(pos); s.scale.setScalar(size);
    return fx(s, life, (o, u) => { o.scale.setScalar(size * (1 + u * grow)); o.material.opacity = opacity * (1 - u); });
  }
  function ring(center, axis, radius, color, life, thick = .05, opacity = .9, from = .2) {
    const m = new T.Mesh(new T.TorusGeometry(1, thick, 6, 64), new T.MeshBasicMaterial({ color, transparent: true, opacity, depthWrite: false }));
    m.position.copy(center); m.quaternion.setFromUnitVectors(V(0, 0, 1), axis.clone().normalize());
    return fx(m, life, (o, u) => { const r = mix(from, radius, outP(u, 3)); o.scale.set(r, r, 1); o.material.opacity = opacity * (1 - u); });
  }
  // Feathers: small dark quads that drift down, rocking side to side.
  const FEATHER_GEO = new T.PlaneGeometry(.07, .2); SHARED.add(FEATHER_GEO);
  const featherMat = new T.MeshBasicMaterial({ color: 0x0c0c10, side: T.DoubleSide, transparent: true }); SHARED.add(featherMat);
  function feather(pos, vel, life = 1.6) {
    const m = new T.Mesh(FEATHER_GEO, featherMat); m.position.copy(pos); m.rotation.set(rnd(0, 6), rnd(0, 6), rnd(0, 6));
    const v = vel.clone(), ph = rnd(0, 6), floor = .03;
    return fx(m, life, (o, u, dt) => {
      v.y = Math.max(v.y - 6 * dt, -.7); v.x *= Math.pow(.2, dt); v.z *= Math.pow(.2, dt);
      o.position.addScaledVector(v, dt); o.position.x += Math.sin(A.time * 5 + ph) * dt * .4;
      if (o.position.y < floor) { o.position.y = floor; o.rotation.x = -Math.PI / 2; } else { o.rotation.z += dt * 3; o.rotation.x = Math.sin(A.time * 4 + ph) * .8; }
      o.scale.setScalar(u > .75 ? 1 - (u - .75) / .25 : 1);
    });
  }

  // ---------- crows: a body, a head, a tail and two flapping wings ----------
  const crowMat = new T.MeshStandardMaterial({ color: 0x0d0d12, roughness: .6, metalness: .2 }); SHARED.add(crowMat);
  const CROW = { body: new T.SphereGeometry(.11, 8, 6), head: new T.SphereGeometry(.07, 8, 6), beak: new T.ConeGeometry(.025, .09, 5), tail: new T.PlaneGeometry(.12, .16), wing: new T.PlaneGeometry(.34, .14) };
  CROW.wing.translate(.17, 0, 0); CROW.tail.translate(0, -.08, 0); for (const g of Object.values(CROW)) SHARED.add(g);
  const crowEyeMat = new T.MeshBasicMaterial({ color: 0xff2222 }); SHARED.add(crowEyeMat);
  const CROW_EYE = new T.SphereGeometry(.016, 5, 4); SHARED.add(CROW_EYE);
  function makeCrow() {
    const g = new T.Group();
    const b = new T.Mesh(CROW.body, crowMat); b.scale.set(1, .85, 2.1); g.add(b);
    const h = new T.Mesh(CROW.head, crowMat); h.position.set(0, .05, -.24); g.add(h);
    const k = new T.Mesh(CROW.beak, crowMat); k.rotation.x = -Math.PI / 2; k.position.set(0, .04, -.33); g.add(k);
    for (const s of [-1, 1]) { const e = new T.Mesh(CROW_EYE, crowEyeMat); e.position.set(s * .045, .08, -.28); g.add(e); }
    const t = new T.Mesh(CROW.tail, crowMat); t.rotation.x = -Math.PI / 2 + .2; t.position.set(0, 0, .2); g.add(t);
    const wl = new T.Group(), wr = new T.Group(); g.add(wl, wr);
    const ml = new T.Mesh(CROW.wing, crowMat); ml.rotation.x = -Math.PI / 2; ml.scale.x = -1; wl.add(ml);
    const mr = new T.Mesh(CROW.wing, crowMat); mr.rotation.x = -Math.PI / 2; wr.add(mr);
    for (const m of [ml, mr]) m.material = crowMat;
    return { g, wl, wr };
  }
  const crows = [];
  // Each crow flies along its own path: `path(u)` gives the world position for u in 0..1 of its life.
  function crow(path, life, size = 1, flap = 26) {
    const c = makeCrow(); c.g.scale.setScalar(size); scene.add(c.g); const ph = rnd(0, 6), prev = path(0).clone();
    c.g.position.copy(prev);
    const e = fx(c.g, life, (o, u) => {
      const p = path(u); const d = p.clone().sub(prev);
      if (d.lengthSq() > 1e-6) { o.lookAt(o.position.clone().sub(d)); }
      o.position.copy(p); prev.copy(p);
      const a = Math.sin(A.time * flap + ph); c.wl.rotation.z = -a * .9 + .1; c.wr.rotation.z = a * .9 - .1;
      const k = u < .08 ? u / .08 : u > .85 ? (1 - u) / .15 : 1; o.scale.setScalar(size * Math.max(.01, k));
    });
    crows.push(e); return e;
  }

  // ---------- sound: synthesised with WebAudio, follows the preview's sound toggle ----------
  let master = null, noiseBuffer = null;
  function ac() { const c = A.audio; if (A.muted || !c) return null; if (!master || master.context !== c) { master = c.createGain(); master.gain.value = .55; master.connect(c.destination); } return c; }
  function noiseBuf(c) { if (noiseBuffer && noiseBuffer.sampleRate === c.sampleRate) return noiseBuffer; const b = c.createBuffer(1, c.sampleRate * 2, c.sampleRate), d = b.getChannelData(0); for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1; return noiseBuffer = b; }
  function envelope(g, at, attack, dur, vol) { g.gain.setValueAtTime(.0001, at); g.gain.exponentialRampToValueAtTime(vol, at + attack); g.gain.exponentialRampToValueAtTime(.0001, at + dur); }
  function tone(o) { const c = ac(); if (!c) return; const at = c.currentTime + (o.at || 0); const osc = c.createOscillator(), g = c.createGain(); osc.type = o.type || 'sine'; osc.frequency.setValueAtTime(o.f0, at); if (o.f1) osc.frequency.exponentialRampToValueAtTime(o.f1, at + o.dur); envelope(g, at, o.attack || .01, o.dur, o.vol || .3); osc.connect(g).connect(master); osc.start(at); osc.stop(at + o.dur + .05); }
  function noise(o) { const c = ac(); if (!c) return; const at = c.currentTime + (o.at || 0); const src = c.createBufferSource(), f = c.createBiquadFilter(), g = c.createGain(); src.buffer = noiseBuf(c); src.loop = true; f.type = o.filter || 'lowpass'; f.Q.value = o.q || .8; f.frequency.setValueAtTime(o.f0, at); if (o.f1) f.frequency.exponentialRampToValueAtTime(o.f1, at + o.dur); envelope(g, at, o.attack || .005, o.dur, o.vol || .3); src.connect(f).connect(g).connect(master); src.start(at, Math.random()); src.stop(at + o.dur + .05); }
  let burnLoop = null;
  function startBurn() {
    const c = ac(); if (!c || burnLoop) return;
    const src = c.createBufferSource(), f = c.createBiquadFilter(), g = c.createGain(); src.buffer = noiseBuf(c); src.loop = true; f.type = 'bandpass'; f.frequency.value = 420; f.Q.value = .6;
    g.gain.value = .0001; g.gain.exponentialRampToValueAtTime(.16, c.currentTime + .5); src.connect(f).connect(g).connect(master); src.start(); burnLoop = { src, g, c };
  }
  function stopBurn() { if (!burnLoop) return; const { src, g, c } = burnLoop; try { g.gain.cancelScheduledValues(c.currentTime); g.gain.setValueAtTime(Math.max(.0001, g.gain.value), c.currentTime); g.gain.exponentialRampToValueAtTime(.0001, c.currentTime + .5); src.stop(c.currentTime + .55); } catch (e) { /* stopped */ } burnLoop = null; }
  const sfx = {
    caw(at = 0) { for (let i = 0; i < 2; i++) { noise({ filter: 'bandpass', f0: 1500, f1: 800, q: 4, dur: .14, vol: .35, attack: .01, at: at + i * .17 }); tone({ type: 'sawtooth', f0: 760, f1: 520, dur: .13, vol: .08, at: at + i * .17 }); } },
    flutter() { for (let i = 0; i < 9; i++) noise({ filter: 'bandpass', f0: 700 + rnd(0, 400), q: 1.2, dur: .06, vol: .25, at: i * .045 }); },
    shimmer() { noise({ filter: 'highpass', f0: 3000, f1: 6000, dur: .5, vol: .1, attack: .1 }); },
    eye() { tone({ type: 'triangle', f0: 1900, f1: 1250, dur: .35, vol: .18 }); tone({ f0: 70, f1: 40, dur: .5, vol: .5 }); noise({ filter: 'bandpass', f0: 2600, q: 6, dur: .25, vol: .12 }); },
    genjutsu() { tone({ f0: 220, f1: 55, dur: 1.2, vol: .3, attack: .1 }); tone({ type: 'triangle', f0: 330, f1: 82, dur: 1.1, vol: .12, attack: .2 }); noise({ filter: 'bandpass', f0: 300, f1: 1800, q: 2, dur: .7, vol: .18, attack: .5 }); },
    wave() { noise({ filter: 'lowpass', f0: 2400, f1: 120, dur: .6, vol: .5 }); tone({ f0: 95, f1: 36, dur: .5, vol: .55 }); },
    crack() { for (let i = 0; i < 4; i++) noise({ filter: 'highpass', f0: rnd(1800, 3400), dur: .08, vol: .2, at: i * .06 }); tone({ type: 'triangle', f0: 900, f1: 300, dur: .5, vol: .08 }); },
    ignite() { noise({ f0: 900, f1: 90, dur: .7, vol: .7 }); tone({ f0: 62, f1: 34, dur: .55, vol: .6 }); noise({ filter: 'bandpass', f0: 380, q: 1, dur: 1, vol: .25, attack: .1 }); },
    hum() { tone({ type: 'sawtooth', f0: 55, f1: 49, dur: 2.4, vol: .14, attack: .4 }); tone({ type: 'sawtooth', f0: 82, f1: 73, dur: 2.2, vol: .08, attack: .5 }); noise({ f0: 200, dur: 2, vol: .12, attack: .5 }); },
    rib() { tone({ f0: 130, f1: 70, dur: .2, vol: .3 }); noise({ filter: 'bandpass', f0: 600, q: 2, dur: .15, vol: .15 }); },
    rise() { tone({ type: 'sawtooth', f0: 40, f1: 90, dur: .8, vol: .2, attack: .2 }); noise({ f0: 150, f1: 900, dur: .8, vol: .25, attack: .2 }); },
    mirror() { tone({ f0: 660, dur: 1.4, vol: .2 }); tone({ f0: 990, dur: 1.1, vol: .1, at: .02 }); tone({ f0: 1320, dur: .8, vol: .06, at: .04 }); },
    liquid() { for (let i = 0; i < 5; i++) tone({ f0: 240 + i * 70, f1: 520 + i * 90, dur: .16, vol: .12, at: i * .12 }); noise({ filter: 'bandpass', f0: 500, f1: 1400, q: 3, dur: .7, vol: .12, attack: .2 }); },
    thrust() { noise({ filter: 'bandpass', f0: 300, f1: 2600, q: .7, dur: .4, vol: .55 }); tone({ f0: 120, f1: 50, dur: .3, vol: .4 }); },
    impact() { noise({ f0: 2600, f1: 80, dur: 1, vol: .9 }); tone({ f0: 90, f1: 30, dur: .9, vol: .9 }); tone({ type: 'triangle', f0: 1400, f1: 900, dur: .4, vol: .12 }); },
    seal() { noise({ filter: 'bandpass', f0: 200, f1: 2400, q: 2, dur: 1.1, vol: .3, attack: .3 }); tone({ f0: 160, f1: 520, dur: 1, vol: .15, attack: .3 }); },
    sealed() { tone({ f0: 520, f1: 130, dur: .5, vol: .25 }); noise({ f0: 1200, f1: 100, dur: .4, vol: .3 }); },
    fade() { noise({ filter: 'highpass', f0: 1200, f1: 400, dur: 1.2, vol: .12, attack: .3 }); },
    punch() { tone({ f0: 140, f1: 60, dur: .15, vol: .5 }); noise({ f0: 1400, f1: 300, dur: .15, vol: .35 }); },
    whoosh() { noise({ filter: 'bandpass', f0: 600, f1: 1500, q: .7, dur: .2, vol: .3 }); },
  };

  // ---------- screen overlay and test panel ----------
  const overlay = document.createElement('div'); overlay.id = 'itOverlay';
  overlay.innerHTML = '<i class="iv"></i><i class="ir"></i><i class="iw"></i><i class="ilt"></i><i class="ilb"></i><svg class="ic" viewBox="0 0 100 100" preserveAspectRatio="none"></svg><img class="is" alt=""><b class="il"></b><b class="it"></b>';
  document.body.append(overlay);
  const [ovV, ovR, ovW, lidT, lidB, ovC, ovS, ovL, ovT] = overlay.children;
  ovS.src = eyeCanvas.toDataURL();
  {
    let d = ''; const r = seeded(7);
    for (let i = 0; i < 14; i++) { let x = 50, y = 50, a = i / 14 * Math.PI * 2 + r() * .3; d += `M${x} ${y}`; for (let k = 0; k < 5; k++) { a += (r() - .5) * .7; x += Math.cos(a) * (6 + r() * 6); y += Math.sin(a) * (6 + r() * 6); d += ` L${x.toFixed(1)} ${y.toFixed(1)}`; } }
    ovC.innerHTML = `<path d="${d}" fill="none" stroke="#fff" stroke-width=".45" vector-effect="non-scaling-stroke"/>`;
  }
  function seeded(seed) { return () => { seed |= 0; seed = seed + 0x6D2B79F5 | 0; let t = Math.imul(seed ^ seed >>> 15, 1 | seed); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
  const panel = document.createElement('div'); panel.id = 'itPanel'; panel.hidden = true;
  panel.innerHTML = '<button data-a="force">패시브 강제 100% · 켜짐</button><button data-a="attack">적 공격 받기 · F</button><button data-a="view">시점: 자동 · V</button><button data-a="killT">대상 처치 테스트 · K</button><button data-a="killMe">시전 중 사망 테스트</button>';
  document.body.append(panel);
  let forcePassive = true, viewMode = 'auto';
  const VIEW_LABEL = { auto: '자동', caster: '시전자', victim: '피격자' };
  function refreshPanel() { panel.querySelector('[data-a=force]').textContent = '패시브 강제 100% · ' + (forcePassive ? '켜짐' : '꺼짐 (20%)'); panel.querySelector('[data-a=view]').textContent = '시점: ' + VIEW_LABEL[viewMode] + ' · V'; }
  panel.addEventListener('click', e => {
    const a = e.target.closest('button')?.dataset.a; if (!a) return;
    if (a === 'force') { forcePassive = !forcePassive; refreshPanel(); }
    if (a === 'attack') enemyAttack();
    if (a === 'view') cycleView();
    if (a === 'killT') killTarget();
    if (a === 'killMe') casterDies();
    e.target.blur();
  });
  function cycleView() { viewMode = viewMode === 'auto' ? 'caster' : viewMode === 'caster' ? 'victim' : 'auto'; refreshPanel(); A.toast('시점 · ' + VIEW_LABEL[viewMode] + (viewMode === 'auto' ? ' (환술·봉인·분신은 피격자/공격자 시점으로 자동 전환)' : '')); }
  window.addEventListener('keydown', e => {
    if (!active || e.repeat) return;
    if (e.code === 'KeyF') enemyAttack(); else if (e.code === 'KeyV') cycleView(); else if (e.code === 'KeyK') killTarget();
  });

  // ---------- first-person arms: black Akatsuki sleeves, pale hands, jointed fingers, purple nails ----------
  const mat = (color, roughness = .6, extra = {}) => new T.MeshStandardMaterial({ color, roughness, metalness: 0, ...extra });
  const mSkin = mat(0xe9cbb2, .62), mNail = mat(0x5b3a8a, .35), mSleeve = mat(0xffffff, .85, { map: cloakTex }), mLining = mat(0x8a0d12, .7), mDark = mat(0x0c0c10, .8);
  const mHair = mat(0x0b0b10, .55), mPlate = mat(0x9aa3ad, .35, { metalness: .6 }), mCloth = mat(0x22242c, .8), mPants = mat(0x2c2f3a, .8);
  function part(geo, m, parent, pos, rot, scale) {
    const x = new T.Mesh(geo, m); parent.add(x); if (pos) x.position.set(...pos); if (rot) x.rotation.set(...rot); if (scale) x.scale.set(...scale);
    x.renderOrder = 102; x.frustumCulled = false; return x;
  }
  const FING = [[.034, .042, .03, .024], [.011, .046, .032, .026], [-.012, .044, .03, .024], [-.034, .034, .025, .021]];
  function makeArm(side) {
    const g = new T.Group(); camera.add(g); g.visible = false; const order = [];
    const palm = part(new T.BoxGeometry(.095, .1, .03), mSkin, g, [0, .05, 0]); order.push(palm);
    const fingers = [];
    for (let i = 0; i < 4; i++) {
      const [x, a, b, c] = FING[i];
      const j1 = new T.Group(); g.add(j1); j1.position.set(-side * x, .1, 0);
      const p1 = part(new T.CapsuleGeometry(.0105, a - .012, 3, 8), mSkin, j1, [0, a / 2, 0]);
      const j2 = new T.Group(); j1.add(j2); j2.position.y = a;
      const p2 = part(new T.CapsuleGeometry(.0098, b - .012, 3, 8), mSkin, j2, [0, b / 2, 0]);
      const j3 = new T.Group(); j2.add(j3); j3.position.y = b;
      const p3 = part(new T.CapsuleGeometry(.009, c - .012, 3, 8), mSkin, j3, [0, c / 2, 0]);
      const nail = part(new T.BoxGeometry(.014, .014, .004), mNail, j3, [0, c - .006, .0085]);
      fingers.push({ j1, j2, j3 }); order.unshift(p3, nail); order.push(p2, p1);
    }
    const thumb = new T.Group(); g.add(thumb); thumb.position.set(-side * .048, .02, -.01);
    const t1 = part(new T.CapsuleGeometry(.012, .03, 3, 8), mSkin, thumb, [0, .022, 0]);
    const t2 = new T.Group(); thumb.add(t2); t2.position.y = .045;
    const t3 = part(new T.CapsuleGeometry(.011, .024, 3, 8), mSkin, t2, [0, .017, 0]);
    part(new T.BoxGeometry(.014, .012, .004), mNail, t2, [0, .03, .009]); order.push(t1, t3);
    const wrist = part(new T.CylinderGeometry(.034, .04, .14, 12), mSkin, g, [0, -.04, 0]); order.push(wrist);
    // Wide Akatsuki sleeve: open at the wrist, red lining visible inside, clouds on the cloth.
    const sleeve = part(new T.CylinderGeometry(.115, .1, .62, 18, 1, true), mSleeve, g, [0, -.38, -.01]); sleeve.material.side = T.DoubleSide;
    const lining = part(new T.CylinderGeometry(.11, .11, .04, 18, 1, true), mLining, g, [0, -.085, -.01]); lining.material.side = T.BackSide;
    order.push(lining, sleeve);
    const up = new T.Group(); camera.add(up); up.visible = false;
    const upper = part(new T.CylinderGeometry(.11, .1, 1, 16), mSleeve, up); order.push(upper);
    const shoulder = part(new T.SphereGeometry(.14, 14, 10), mSleeve, up); order.push(shoulder);
    g.traverse(o => { o.castShadow = false; });
    return { g, up, upper, shoulder, side, fingers, thumb, t2, order, k: 1 };
  }
  const arms = { r: makeArm(1), l: makeArm(-1) };
  const pose = (pos, fin, palm, curl, sh = [.62, -.86, .05]) => ({ pos: V(...pos), fin: V(...fin), palm: V(...palm), curl: typeof curl === 'number' ? [curl, curl, curl, curl, curl] : curl.slice(), sh: V(...sh) });
  const mirror = p => ({ pos: V(-p.pos.x, p.pos.y, p.pos.z), fin: V(-p.fin.x, p.fin.y, p.fin.z), palm: V(-p.palm.x, p.palm.y, p.palm.z), curl: p.curl.slice(), sh: V(-p.sh.x, p.sh.y, p.sh.z) });
  function lerpPose(a, b, k) {
    if (k <= 0) return a; if (k >= 1) return b;
    return { pos: a.pos.clone().lerp(b.pos, k), fin: a.fin.clone().lerp(b.fin, k), palm: a.palm.clone().lerp(b.palm, k), curl: a.curl.map((c, i) => mix(c, b.curl[i], k)), sh: a.sh.clone().lerp(b.sh, k) };
  }
  // Calm: hands low and relaxed, fingers loosely bent, the sleeves hanging.
  const REST = pose([.3, -.5, -.6], [-.08, .35, -1], [-1, -.1, -.15], [.35, .42, .5, .55, .3]);
  const L_REST = mirror(REST);
  const LOW = pose([.36, -.66, -.5], [-.05, -.2, -1], [-1, 0, 0], [.3, .35, .4, .45, .25], [.62, -.95, .1]);
  // Tiger seal: palms together in front of the chest, index and middle up, the rest folded.
  const SEAL = pose([.035, -.3, -.5], [0, 1, -.15], [-1, 0, 0], [0, 0, 1, 1, .7], [.5, -.84, .05]);
  const L_SEAL = mirror(SEAL);
  // Q: the right hand rises beside the face with two fingers up; the left hand holds the right sleeve.
  const FACE = pose([.13, -.11, -.42], [-.25, 1, .2], [-.2, 0, 1], [0, 0, .95, .95, .7], [.5, -.78, .05]);
  const L_GRIP = pose([.02, -.4, -.5], [.95, .25, -.3], [0, 1, .2], [.85, .85, .85, .85, .6], [-.52, -.9, .05]);
  const POINT = pose([.2, -.24, -.78], [-.06, .1, -1], [-.2, -1, 0], [0, 1, 1, 1, .8], [.55, -.84, -.1]);
  const KNIFE = pose([.1, -.28, -.95], [0, .1, -1], [-1, 0, 0], [0, 0, .05, .1, .3], [.5, -.84, -.15]);
  const _m = new T.Matrix4(), _x = V(), _y = V(), _z = V(), _q = new T.Quaternion();
  function poseArm(arm, P, show = true) {
    const vis = show && active && fp; arm.g.visible = arm.up.visible = vis; if (!vis) return;
    const ratio = clamp(camera.aspect, .55, 1);
    arm.g.position.copy(P.pos); arm.g.position.x *= ratio;
    _y.copy(P.fin).normalize(); _z.copy(P.palm).normalize().negate(); _z.addScaledVector(_y, -_z.dot(_y)).normalize(); _x.crossVectors(_y, _z);
    _m.makeBasis(_x, _y, _z); arm.g.quaternion.setFromRotationMatrix(_m); arm.g.scale.setScalar(mix(.85, 1, ratio));
    for (let i = 0; i < 4; i++) { const f = arm.fingers[i], c = P.curl[i]; f.j1.rotation.set(-c * 1.45, 0, 0); f.j2.rotation.x = -c * 1.6; f.j3.rotation.x = -c * 1.1; }
    arm.thumb.rotation.set(-.3 - P.curl[4] * .7, 0, arm.side * (.8 - P.curl[4] * .6)); arm.t2.rotation.x = -P.curl[4] * .9;
    const elbow = arm.g.position.clone().addScaledVector(_y, -.72);
    const sh = P.sh.clone(); sh.x *= mix(.85, 1, ratio);
    const d = sh.clone().sub(elbow), len = d.length(); d.normalize(); _q.setFromUnitVectors(UP, d);
    arm.upper.position.copy(elbow).addScaledVector(d, len / 2); arm.upper.quaternion.copy(_q); arm.upper.scale.set(1, len, 1);
    arm.shoulder.position.copy(sh);
    // Crow clone: parts vanish fingertip-first as k falls to 0, and come back in reverse.
    const n = arm.order.length, shown = Math.round(arm.k * n);
    for (let i = 0; i < n; i++) arm.order[i].visible = i >= n - shown;
  }
  // Black feathers peel off whatever part of an arm is dissolving.
  function shedFeathers(arm, n = 2) {
    if (!arm.g.visible) return;
    for (let i = 0; i < n; i++) { const p = camera.localToWorld(arm.g.position.clone().add(V(rnd(-.06, .06), rnd(-.25, .1), rnd(-.04, .04)))); feather(p, V(rnd(-1, 1), rnd(.2, 1.4), rnd(-1, 1)), rnd(.6, 1.1)); }
  }

  // ---------- third-person Itachi (seen in cinematic shots, victim views and by the attacker) ----------
  const body = new T.Group(); scene.add(body); body.visible = false;
  const bpart = (geo, m, parent, pos, rot, scale) => { const x = new T.Mesh(geo, m); parent.add(x); if (pos) x.position.set(...pos); if (rot) x.rotation.set(...rot); if (scale) x.scale.set(...scale); x.castShadow = true; return x; };
  for (const s of [-1, 1]) { bpart(new T.CylinderGeometry(.11, .09, .9, 10), mPants, body, [s * .13, .5, 0]); bpart(new T.BoxGeometry(.14, .08, .26), mDark, body, [s * .13, .05, -.04]); }
  const cloak = bpart(new T.CylinderGeometry(.27, .4, 1.25, 18, 1, true), mSleeve, body, [0, .98, 0]); cloak.material = mSleeve; cloak.material.side = T.DoubleSide;
  bpart(new T.CylinderGeometry(.24, .27, .32, 18), mSleeve, body, [0, 1.72, 0]);
  bpart(new T.CylinderGeometry(.2, .24, .22, 18, 1, true), mSleeve, body, [0, 1.95, 0]).material.side = T.DoubleSide; // the high collar
  const bhead = new T.Group(); body.add(bhead); bhead.position.y = 2.06;
  bpart(new T.SphereGeometry(.15, 16, 12), mSkin, bhead, [0, 0, 0], null, [1, 1.12, 1]);
  bpart(new T.SphereGeometry(.165, 16, 12, 0, Math.PI * 2, 0, Math.PI * .55), mHair, bhead, [0, .03, .01]);
  for (const s of [-1, 1]) bpart(new T.BoxGeometry(.05, .2, .03), mHair, bhead, [s * .1, -.05, -.13], [0, 0, s * .1]); // long bangs framing the face
  bpart(new T.BoxGeometry(.3, .045, .02), mCloth, bhead, [0, .07, -.145]);
  bpart(new T.BoxGeometry(.12, .055, .012), mPlate, bhead, [0, .07, -.157]);
  bpart(new T.BoxGeometry(.13, .006, .004), mDark, bhead, [0, .07, -.164], [0, 0, .18]); // the slash across the leaf
  bpart(new T.CylinderGeometry(.025, .015, .28, 6), mHair, bhead, [0, -.08, .17], [.35, 0, 0]); // low ponytail
  const eyes = [];
  for (const s of [-1, 1]) { const e = sprite(eyeTex, 0xffffff, 1, false); e.scale.setScalar(.05); e.position.set(s * .055, .015, -.15); bhead.add(e); eyes.push(e); }
  const bArms = [];
  for (const s of [-1, 1]) {
    const piv = new T.Group(); body.add(piv); piv.position.set(s * .32, 1.78, 0);
    bpart(new T.CylinderGeometry(.09, .14, .72, 12, 1, true), mSleeve, piv, [0, -.36, 0]).material.side = T.DoubleSide;
    const hand = bpart(new T.SphereGeometry(.055, 10, 8), mSkin, piv, [0, -.76, 0], null, [1, 1.3, .8]);
    bArms.push({ piv, hand, s });
  }
  // Pose the body at the caster's real position. `reach` lifts the right arm forward, `nod` bows the head.
  function poseBody(reach = 0, nod = 0, rise = 1) {
    body.position.copy(basePos).setY(basePos.y - EYE); body.rotation.set(0, A.yaw, 0);
    body.scale.set(1, Math.max(.001, rise), 1);
    const [L, R] = bArms; R.piv.rotation.set(-1.45 * reach, 0, -.05); L.piv.rotation.set(0, 0, .08); bhead.rotation.x = .35 * nod;
  }

  // ---------- training dummies: one patrols (for Amaterasu), one attacks you (for the crow clone) ----------
  const walker = A.makeTarget(-5, -13, 4); walker.itOnly = true; walker.patrol = { a: V(-6, 0, -13), b: V(6, 0, -13), u: 0, dir: 1 };
  const attacker = A.makeTarget(-11, -3, 5); attacker.itOnly = true;
  const extras = [walker, attacker];
  for (const t of extras) { targets.splice(targets.indexOf(t), 1); t.g.visible = false; }
  const limbs = t => [t.g.children[3], t.g.children[4]];
  function calm(t) { for (const l of limbs(t)) l.rotation.set(0, 0, 0); t.g.rotation.set(0, 0, 0); t.g.scale.setScalar(1); }
  function alive(t) { return t && t.hp > 0 && t.g.visible !== false; }
  const inObstacle = (p, m = .45) => A.obstacles.find(o => p.x > o.x0 - m && p.x < o.x1 + m && p.z > o.z0 - m && p.z < o.z1 + m && (p.y ?? 0) < o.h);
  function blocked(from, to) { const d = to.clone().sub(from), len = d.length(); if (len < .01) return false; return A.wallOnRay(from, d.normalize(), len); }
  function firstAhead(from, dir, reach, width) {
    let best = null, bestAlong = Infinity;
    for (const t of targets) {
      if (!alive(t) || t === attacker) continue;
      const rel = t.g.position.clone().sub(from).setY(0), along = rel.dot(dir), side = rel.clone().addScaledVector(dir, -along).length();
      if (along > .3 && along <= reach && side <= width && along < bestAlong && !blocked(from.clone().setY(1.4), t.g.position.clone().setY(1.4))) { best = t; bestAlong = along; }
    }
    return best;
  }
  function safeGround(p, avoid) {
    const q = p.clone().setY(0); const lim = A.arenaR - 1.2, r = Math.hypot(q.x, q.z); if (r > lim) { q.x *= lim / r; q.z *= lim / r; }
    for (let i = 0; i < 40 && (inObstacle(q.clone().setY(.5), .6)); i++) q.addScaledVector(avoid || V(0, 0, 1), .3);
    return q;
  }

  // ---------- state ----------
  let active = false, fp = true, glow = 0, crowReady = 0, passive = null, playerSlowUntil = 0;
  let vign = 0, red = 0, vortex = 0, lid = 0, eyeFlash = 0, crack = 0, shakeAmp = 0, filterOn = false, label = '', talk = '', talkUntil = 0;
  const fields = [];
  const binds = new Map(); // target -> { until, kind }
  function shake(a) { shakeAmp = Math.max(shakeAmp, a * (A.comfort ? .3 : 1)); }
  function say(text, life = 1.2) { talk = text; talkUntil = A.time + life; }

  // ---------- Passive: Crow Clone ----------
  // Resolved where a hit would land, before any damage: a roll (or the test override) and a 25 s internal cooldown.
  function incomingHit(amount, from, kind = 'melee') {
    const dodgeable = ['melee', 'dash', 'projectile'].includes(kind);
    if (dodgeable && !passive && A.time >= crowReady && (forcePassive || Math.random() < CFG.crow.chance)) { startCrow(from); return 0; }
    let dealt = amount;
    const c = A.cast;
    if (c?.itachi && c.type === 'susanoo' && c.age >= CFG.r.mirror && c.age < CFG.r.sealEnd + .3) {
      const fwd = A.flatForward(), toFrom = from.clone().sub(basePos).setY(0).normalize();
      if (fwd.dot(toFrom) > .35) { dealt = Math.round(amount * CFG.r.guard); mirrorRipple(); say('야타의 거울 · 전방 피해 60% 감소', 1); }
    }
    A.hp = Math.max(1, A.hp - dealt); A.flash('#ff2a2a', .22); shake(.05); return dealt;
  }
  function startCrow(from) {
    const back = A.flatForward().negate(), side = V().crossVectors(back, UP).normalize();
    const tries = [back, back.clone().add(side).normalize(), back.clone().sub(side).normalize(), side, side.clone().negate()];
    let to = null;
    for (const d of tries) {
      const p = basePos.clone().setY(0).addScaledVector(d, CFG.crow.back);
      if (Math.hypot(p.x, p.z) > A.arenaR - 1.5 || inObstacle(p.clone().setY(.5), .7) || blocked(basePos.clone().setY(1.2), p.clone().setY(1.2))) continue;
      if (targets.some(t => alive(t) && t.g.position.distanceTo(p) < 1.4)) continue;
      to = p; break;
    }
    const start = basePos.clone();
    passive = { start: A.time, from: start, to: to ? to.setY(basePos.y) : start.clone(), attacker: from, moved: !!to, flags: {} };
    crowReady = A.time + CFG.crow.icd;
    A.toast('까마귀 분신 · 공격 무효' + (to ? ' · 후방 12스터드 재등장' : ' · 안전한 위치가 없어 제자리 회피') + ' · 내부 재사용 25초');
  }
  function updateCrow(dt) {
    const p = passive, a = A.time - p.start, C = CFG.crow;
    // 0.0-0.1 a flinch; 0.1-0.25 the body breaks into crows; 0.25-0.45 moved; 0.45-0.65 reformed feet first; then settle.
    if (!p.flags.burst && a >= 0) {
      p.flags.burst = true; sfx.caw(); sfx.flutter();
      for (let i = 0; i < 8; i++) feather(p.from.clone().setY(1.7 + rnd(-.2, .2)).add(V(rnd(-.3, .3), 0, rnd(-.3, .3))), V(rnd(-1.5, 1.5), rnd(.5, 2), rnd(-1.5, 1.5)));
    }
    if (a >= .1 && !p.flags.crows) {
      p.flags.crows = true; sfx.flutter(); sfx.caw(.1);
      // Crows scatter from the body: some climb, some peel off left and right, each at its own speed.
      for (let i = 0; i < 34; i++) {
        const o = p.from.clone().setY(rnd(.3, 2.1)).add(V(rnd(-.25, .25), 0, rnd(-.25, .25)));
        const ang = rnd(0, Math.PI * 2), up = Math.random() < .4 ? rnd(2, 5) : rnd(-.2, 1.5), sp = rnd(3, 7);
        const dir = V(Math.cos(ang), 0, Math.sin(ang)).multiplyScalar(sp).setY(up);
        const regroup = i < 20; const life = regroup ? .55 - rnd(0, .1) : rnd(.7, 1.1);
        if (regroup) {
          // These ones swing out and spiral back into the new position.
          const end = p.to.clone().setY(rnd(.3, 2)), spin = rnd(2, 4) * (i % 2 ? 1 : -1);
          crow(u => { const out = o.clone().addScaledVector(dir, .22 * Math.sin(u * Math.PI)); const k = ease(u); const pos = out.lerp(end, k); const r = .8 * (1 - k) * Math.sin(u * Math.PI); return pos.add(V(Math.cos(u * spin * 6) * r, 0, Math.sin(u * spin * 6) * r)); }, life, rnd(.8, 1.2));
        } else crow(u => o.clone().addScaledVector(dir, u).add(V(0, u * u * 1.5, 0)), life, rnd(.8, 1.3));
      }
      for (let i = 0; i < 18; i++) feather(p.from.clone().setY(rnd(.6, 2)).add(V(rnd(-.4, .4), 0, rnd(-.4, .4))), V(rnd(-1, 1), rnd(0, 1), rnd(-1, 1)), rnd(1.4, 2.4));
      // Wings brushing past the lens.
      for (let i = 0; i < 6; i++) { const s = V(rnd(-1, 1), rnd(-.4, .6), 0).normalize(); crow(u => camera.localToWorld(V(s.x * (.25 + u * 2.4), s.y * (.2 + u * 1.6), -.55 - u * .4)), .35 + rnd(0, .15), .9, 34); }
    }
    if (a >= .25) { const k = ease(seg(a, .25, .45)); basePos.x = mix(p.from.x, p.to.x, k); basePos.z = mix(p.from.z, p.to.z, k); }
    if (a >= .45 && !p.flags.reform) { p.flags.reform = true; sfx.flutter(); for (let i = 0; i < 10; i++) { const ang = i / 10 * Math.PI * 2; crow(u => p.to.clone().setY(.2 + u * 1.8).add(V(Math.cos(ang + u * 9) * 1.1 * (1 - u), 0, Math.sin(ang + u * 9) * 1.1 * (1 - u))), .3, .8); } }
    if (a >= .62 && !p.flags.eye) { p.flags.eye = true; eyeFlash = Math.max(eyeFlash, .6); sfx.eye(); }
    if (a >= .65 && !p.flags.leave) { p.flags.leave = true; for (let i = 0; i < 6; i++) { const d = V(rnd(), rnd(.3, 1), rnd()).normalize(); const o = p.to.clone().setY(1.5); crow(u => o.clone().addScaledVector(d, u * 4), .5, .7); } for (let i = 0; i < 8; i++) feather(p.to.clone().setY(rnd(.5, 2)), V(rnd(-.6, .6), rnd(0, .8), rnd(-.6, .6)), rnd(1.4, 2)); }
    // Arms: edges shed at once, gone by 0.25, rebuilt 0.45-0.65 shoulder first.
    const k = a < .1 ? 1 - .25 * (a / .1) : a < .25 ? .75 * (1 - seg(a, .1, .25)) : a < .45 ? 0 : seg(a, .45, .65);
    arms.r.k = arms.l.k = k; if (a < .3) { shedFeathers(arms.r, 2); shedFeathers(arms.l, 2); }
    camera.fov = 66 - 9 * bump(a, 0, .3) + 4 * bump(a, .45, .85);
    camera.position.y -= .25 * bump(a, .1, .6);
    vign = Math.max(vign, .5 * bump(a, 0, .7));
    if (a >= C.total) { passive = null; arms.r.k = arms.l.k = 1; }
  }
  function enemyAttack(fromDemo = false) {
    if (!active || attacker.lunge) return;
    if (!fromDemo) { A.stopDemo?.(); }
    const f = A.flatForward(), at = basePos.clone().setY(0).addScaledVector(f, 2.4);
    attacker.hp = attacker.max; attacker.g.visible = true; attacker.g.position.copy(at); attacker.g.lookAt(basePos.clone().setY(0)); attacker.locked = true; attacker.g.userData.cannonUntil = Infinity;
    attacker.lunge = { start: A.time, hit: false, at: at.clone() };
    puff(at.clone().setY(.4), 1.2, .5, V(0, .6, 0), 0xd8d2c8, .5); A.toast('훈련 상대가 정면에서 주먹을 날립니다');
  }
  function updateAttacker(dt) {
    const L = attacker.lunge; if (!L) return;
    const a = A.time - L.start, [la, ra] = limbs(attacker);
    const toMe = basePos.clone().setY(0).sub(attacker.g.position).setY(0); const dist = toMe.length(); toMe.normalize();
    attacker.g.lookAt(attacker.g.position.clone().sub(toMe));
    // Wind up (lean back, fist cocked), then the punch.
    const wind = ease(seg(a, 0, .35)), strike = outP(seg(a, .35, .45), 3), back = ease(seg(a, .7, 1.1));
    ra.rotation.x = mix(mix(0, .9, wind), -1.6, strike) * (1 - back); la.rotation.x = .4 * wind * (1 - back);
    attacker.g.rotation.x = mix(-.12 * wind, .18, strike) * (1 - back);
    if (a >= .3 && a < .45) attacker.g.position.addScaledVector(toMe, Math.max(0, dist - 1.4) * dt * 6);
    if (a >= .42 && !L.hit) {
      L.hit = true; sfx.whoosh();
      if (basePos.distanceTo(attacker.g.position.clone().setY(EYE)) < 3.2) { const dealt = incomingHit(CFG.crow.damage, attacker.g.position.clone(), 'melee'); if (dealt) { sfx.punch(); A.toast('피격 · ' + dealt + ' 피해' + (A.time < crowReady ? ' (까마귀 분신 재사용 대기)' : '')); } else L.dodged = true; }
      else L.dodged = true;
    }
    if (a > 1.6) { attacker.lunge = null; attacker.g.visible = false; attacker.locked = false; calm(attacker); attacker.g.position.copy(attacker.home); }
  }

  // ---------- Q: Tsukuyomi ----------
  function pickTsukuyomi() {
    const eye = basePos.clone(), aim = A.aimDir(); let best = null, bestA = Infinity;
    for (const t of targets) {
      if (!alive(t) || t === attacker) continue;
      const chest = t.g.position.clone().setY(t.g.position.y + 1.5), d = chest.clone().sub(eye), dist = d.length();
      if (dist > CFG.q.range) continue;
      const ang = T.MathUtils.radToDeg(d.normalize().angleTo(aim));
      if (ang > CFG.q.angle || blocked(eye, chest)) continue;
      if (ang < bestA) { best = t; bestA = ang; }
    }
    return best;
  }
  const shadows = [];
  function makeShadow() {
    const g = body.clone(true); g.traverse(o => { if (o.isMesh) { o.material = new T.MeshBasicMaterial({ color: 0x050505 }); o.castShadow = false; } if (o.isSprite) { o.material = o.material.clone(); o.material.color.set(0xff3030); } });
    g.visible = false; g.scale.setScalar(1); scene.add(g); live.add(g); return g;
  }
  let moon = null, voidFloor = null;
  function beginTsukuyomi(c) {
    const t = pickTsukuyomi();
    if (!t) { c.fail = true; c.duration = .45; A.cooldowns.tsukuyomi = A.time + CFG.q.failCd; A.toast('츠쿠요미 · 35스터드·12° 안에 보이는 대상이 없습니다 · 재사용 1.5초'); return; }
    if ((binds.get(t)?.until || 0) > A.time) { c.fail = true; c.duration = .3; A.cooldowns.tsukuyomi = 0; A.toast('이미 환술·봉인에 걸린 대상입니다'); return; }
    c.target = t; c.duration = CFG.q.end + .05;
    A.title('万華鏡写輪眼', '츠쿠요미', '35스터드·12° 단일 대상 · 환술 1.4초 구속 · 12 피해', '#ff3b3b');
  }
  function updateTsukuyomi(c, a) {
    const Q = CFG.q, t = c.target;
    // Caster: the head dips and comes up, the right hand rises beside the face, the left holds the sleeve.
    const raise = ease(seg(a, .08, .4)), lower = ease(seg(a, 1.5, 1.95));
    poseArm(arms.r, lerpPose(lerpPose(REST, FACE, raise), REST, lower)); poseArm(arms.l, lerpPose(lerpPose(L_REST, L_GRIP, raise), L_REST, lower));
    camera.rotation.x += -.12 * bump(a, 0, .45);
    camera.fov = 66 - 7 * ease(seg(a, 0, .3)) * (1 - ease(seg(a, 1.5, 1.95)));
    vign = Math.max(vign, .55 * ease(seg(a, 0, .3)) * (1 - lower));
    if (c.fail) return;
    if (a >= Q.prep && !c.flags.eye) { c.flags.eye = true; sfx.eye(); glow = 1; }
    eyeFlash = Math.max(eyeFlash, a >= Q.prep && a < Q.eye + .1 ? .55 * bump(a, Q.prep, Q.eye + .1) : 0);
    if (!alive(t)) { if (!c.flags.lost) { c.flags.lost = true; releaseBind(t); c.duration = Math.min(c.duration, a + .3); } return; }
    if (a >= Q.eye && !c.flags.bind) {
      c.flags.bind = true; binds.set(t, { until: A.time + Q.bind, kind: 'tsukuyomi' }); t.locked = true; t.g.userData.cannonUntil = Infinity; t.vel = null;
      sfx.genjutsu(); say('환술 세계 · 대상 이동·점프·대시·스킬 불가 1.4초', 1.4);
    }
    // The victim stiffens where it stands, head bowed, arms dead.
    if (c.flags.bind && a < Q.end) { const k = ease(seg(a, Q.eye, Q.eye + .2)) * (1 - ease(seg(a, 1.8, 1.95))); t.g.rotation.x = .2 * k; const [la, ra] = limbs(t); la.rotation.z = -.05 * k; ra.rotation.z = .05 * k; if (Math.random() < .25) feather(t.g.position.clone().setY(rnd(1.5, 2.8)), V(rnd(-.2, .2), -.2, rnd(-.2, .2)), 1.2); }
    if (a >= Q.wave && !c.flags.hit) { c.flags.hit = true; A.hit(t, Q.damage, '#ff5a5a'); sfx.wave(); if (victimView(c)) { shake(.06); red = 1; } glowAt(t.g.position.clone().setY(1.6), RED, 1.2, .4, 1.5, .8); }
    if (a >= Q.crack && !c.flags.crack) { c.flags.crack = true; sfx.crack(); }
    if (a >= Q.end - .02 && !c.flags.free) { c.flags.free = true; releaseBind(t); }
    // Victim's world: everything goes black, grey and red, a huge red moon, Itachi shadows all around.
    c.world = a >= Q.eye && a < Q.end ? ease(seg(a, Q.eye, Q.world)) * (1 - ease(seg(a, 1.6, 1.95))) : 0;
    if (c.world > 0 && !moon) {
      moon = keep(sprite(glowTex, 0xff1010, 1, false)); voidFloor = keep(new T.Mesh(new T.CircleGeometry(30, 48), new T.MeshBasicMaterial({ color: 0x050303, transparent: true, depthWrite: false })));
      voidFloor.rotation.x = -Math.PI / 2; voidFloor.position.copy(t.g.position).setY(.02);
      for (let i = 0; i < 6; i++) shadows.push({ g: makeShadow(), ang: (i - 2.5) * .36, rad: 3.6 + (i % 3) * 1.6, next: 0 });
      const core = keep(new T.Mesh(new T.CircleGeometry(1, 48), new T.MeshBasicMaterial({ color: 0xff2020, transparent: true, depthWrite: false, fog: false }))); moon.userData.core = core;
      moon.material.fog = false; moon.material.depthTest = false; core.material.depthTest = false; moon.renderOrder = core.renderOrder = -1; voidFloor.material.fog = false;
      for (const s of shadows) s.g.traverse(o => { if (o.material) o.material.fog = false; });
    }
    if (moon) {
      const eye = t.g.position.clone().setY(2.35), toMe = basePos.clone().sub(eye).setY(0).normalize();
      const mp = eye.clone().addScaledVector(toMe, 30).add(V(0, 9, 0)); const r = 6 * (.6 + .4 * c.world);
      moon.position.copy(mp); moon.scale.setScalar(r * 3.2); moon.material.opacity = .9 * c.world;
      const core = moon.userData.core; core.position.copy(mp); core.lookAt(eye); core.scale.setScalar(r); core.material.opacity = c.world;
      voidFloor.material.opacity = .85 * c.world; voidFloor.visible = c.world > .01;
      const vis = c.world > .02 && (victimView(c));
      moon.visible = core.visible = vis; voidFloor.visible = vis;
      // Shadows stand in a ring, all facing the victim; in the attack window they vanish and reappear elsewhere.
      for (const s of shadows) {
        if (a > .9 && a < 1.5 && A.time > s.next) { s.next = A.time + rnd(.08, .2); if (Math.random() < .5) { s.ang = Math.max(-1.1, Math.min(1.1, s.ang + rnd(-.7, .7))); s.rad = rnd(3, 7); feather(s.g.position.clone().setY(1.6), V(rnd(-1, 1), 1, rnd(-1, 1)), .8); } }
        const base = Math.atan2(toMe.z, toMe.x) + s.ang, p = t.g.position.clone().add(V(Math.cos(base) * s.rad, 0, Math.sin(base) * s.rad));
        s.g.position.copy(p); s.g.lookAt(t.g.position.clone()); s.g.rotateY(Math.PI);
        s.g.visible = vis && c.world > .3 && a < 1.62; s.g.scale.set(1, 1, 1);
      }
      if (a >= 1.62 && !c.flags.scatter) { c.flags.scatter = true; for (const s of shadows) for (let i = 0; i < 6; i++) feather(s.g.position.clone().setY(rnd(.5, 2.2)), V(rnd(-1.5, 1.5), rnd(.5, 2), rnd(-1.5, 1.5)), 1.4); }
    }
    // The wave: a red ring travelling from Itachi's outstretched hand to the victim.
    if (a >= 1.18 && !c.flags.waveFx) { c.flags.waveFx = true; const from = basePos.clone().setY(1.6), to = t.g.position.clone().setY(1.6), dir = to.clone().sub(from).normalize(); const m = new T.Mesh(new T.TorusGeometry(1, .08, 6, 48), new T.MeshBasicMaterial({ color: 0xff1a1a, transparent: true, depthWrite: false })); m.quaternion.setFromUnitVectors(V(0, 0, 1), dir); fx(m, .3, (o, u) => { o.position.lerpVectors(from, to, u); o.scale.setScalar(.4 + 1.6 * u); o.material.opacity = (victimView(c) ? 1 : .5) * (1 - u * .4); }); }
    crack = a >= Q.crack ? ease(seg(a, Q.crack, 1.75)) * (1 - ease(seg(a, 1.75, 1.95))) : 0;
  }
  function releaseBind(t) { if (!t) return; binds.delete(t); t.locked = false; t.g.userData.cannonUntil = 0; calm(t); }
  function endTsukuyomi(c) {
    releaseBind(c.target); clearWorld();
  }
  function clearWorld() { if (moon) { kill(moon.userData.core); kill(moon); moon = null; } if (voidFloor) { kill(voidFloor); voidFloor = null; } for (const s of shadows.splice(0)) kill(s.g); }

  // ---------- E: Amaterasu ----------
  // A ray from the centre of the screen: the first thing it meets must be open, level floor in range.
  function aimGround() {
    const from = basePos.clone(), dir = A.aimDir(), p = V();
    for (let s = .2; s <= CFG.e.range; s += .15) {
      p.copy(from).addScaledVector(dir, s);
      for (const t of targets) { if (!alive(t)) continue; const tp = t.g.position; if (Math.hypot(p.x - tp.x, p.z - tp.z) < .55 && p.y > tp.y && p.y < tp.y + 2.7) return { error: '적이 시야를 가리고 있습니다 · 바닥을 바라보세요' }; }
      const o = inObstacle(p, 0); if (o) return { error: p.y > o.h - .4 ? '구조물 위는 대상이 아닙니다' : '벽면에는 흑염을 만들 수 없습니다' };
      if (p.y <= 0) { const q = p.clone().setY(0); if (Math.hypot(q.x, q.z) > A.arenaR - .5) return { error: '경기장 밖입니다' }; return { point: q, dist: s }; }
    }
    return { error: '65스터드 안에 바닥이 없습니다 · 지면을 바라보세요' };
  }
  // A flame tongue: a round bulb at the base tapering to a wavy, curling tip (not a cone).
  const FLAME_GEO = (() => {
    const pts = [];
    for (let i = 0; i <= 14; i++) { const y = i / 14; const r = y < .22 ? .5 * Math.pow(Math.sin(y / .22 * Math.PI / 2), .6) : .5 * Math.pow(1 - (y - .22) / .78, 1.25); pts.push(new T.Vector2(Math.max(.001, r), y)); }
    const g = new T.LatheGeometry(pts, 10); const p = g.attributes.position;
    for (let i = 0; i < p.count; i++) { const y = p.getY(i), tw = y * 2.2; const x = p.getX(i), z = p.getZ(i); p.setXYZ(i, x * Math.cos(tw) - z * Math.sin(tw) + Math.sin(y * 4) * .12 * y, y, x * Math.sin(tw) + z * Math.cos(tw)); }
    g.computeVertexNormals(); return g;
  })(); SHARED.add(FLAME_GEO);
  // Flames lick upward: each instance sways and swells along its height; black core with a dark red rim.
  const FLAME_VS = 'uniform float uTime;varying float vY;varying vec3 vN;varying vec3 vV;void main(){vec3 p=position;mat4 m=modelMatrix;\n#ifdef USE_INSTANCING\nm=modelMatrix*instanceMatrix;\n#endif\nvec4 c=m*vec4(0.,0.,0.,1.);float ph=c.x*1.7+c.z*2.3;float y=p.y;p.x+=sin(y*5.-uTime*7.+ph)*.2*y;p.z+=cos(y*4.-uTime*6.+ph*1.3)*.16*y;p.xz*=1.+.18*sin(uTime*11.+ph+y*8.)*y;vec4 w=m*vec4(p,1.);vY=y;vN=normalize(mat3(m)*normal);vV=normalize(cameraPosition-w.xyz);gl_Position=projectionMatrix*viewMatrix*w;}';
  function flameCore() {
    return new T.ShaderMaterial({ uniforms: { uTime: { value: 0 } }, vertexShader: FLAME_VS,
      fragmentShader: 'uniform float uTime;varying float vY;varying vec3 vN;varying vec3 vV;void main(){float f=pow(1.-abs(dot(normalize(vN),vV)),1.6);float band=.5+.5*sin(vY*14.-uTime*9.);vec3 c=mix(vec3(.012,.004,.006),vec3(.42,.015,.03),clamp(f*.95+band*.18*vY,0.,1.));gl_FragColor=vec4(c,1.);}' });
  }
  function flameHalo() {
    return new T.ShaderMaterial({ uniforms: { uTime: { value: 0 } }, vertexShader: FLAME_VS, transparent: true, depthWrite: false, side: T.BackSide,
      fragmentShader: 'uniform float uTime;varying float vY;varying vec3 vN;varying vec3 vV;void main(){float band=.6+.4*sin(vY*11.-uTime*8.);gl_FragColor=vec4(vec3(.55,.02,.04),.6*(1.-vY*.7)*band);}' });
  }
  function beginAmaterasu(c) {
    const aim = aimGround();
    if (aim.error) { c.fail = true; c.duration = .05; A.cooldowns.amaterasu = 0; A.toast('아마테라스 미발동 · ' + aim.error); return; }
    c.point = aim.point; c.duration = 1.05;
    A.title('天照', '아마테라스', '바라본 지면에 흑염 · 반경 20 · 진입 10 + 초당 6 ×5 · 둔화 20% · 6초', '#ff3b3b');
    // A faint black mark where the eyes settle.
    const m = new T.Mesh(new T.RingGeometry(.5, .62, 40), new T.MeshBasicMaterial({ color: 0x000000, transparent: true, opacity: .5, depthWrite: false })); m.rotation.x = -Math.PI / 2; m.position.copy(c.point).setY(.03);
    fx(m, .5, (o, u) => { o.material.opacity = .45 * (1 - u); o.scale.setScalar(1 - .3 * u); });
  }
  function updateAmaterasu(c, a) {
    const E = CFG.e;
    // Caster: a slight bow, one eye closing and opening; the hands barely move.
    poseArm(arms.r, lerpPose(REST, LOW, .4 * ease(seg(a, .1, .3)))); poseArm(arms.l, lerpPose(L_REST, mirror(LOW), .4 * ease(seg(a, .1, .3))));
    camera.rotation.x += -.07 * bump(a, .15, .9);
    lid = c.fail ? 0 : a < .45 ? .55 * ease(seg(a, .2, .42)) : .55 * (1 - ease(seg(a, .45, .52)));
    camera.fov = 66 - 8 * ease(seg(a, .2, .55)) * (1 - ease(seg(a, .8, 1.05)));
    vign = Math.max(vign, .6 * ease(seg(a, .2, .55)) * (1 - ease(seg(a, .8, 1.05))));
    if (c.fail) return;
    if (a >= .45 && !c.flags.eye) { c.flags.eye = true; eyeFlash = Math.max(eyeFlash, .4); glow = 1; sfx.eye(); }
    if (a >= E.ignite && !c.flags.field) { c.flags.field = true; fields.push(makeField(c.point, c.start)); sfx.ignite(); startBurn(); shake(.03); }
  }
  function makeField(center, start) {
    const E = CFG.e, R = E.radius;
    // An irregular edge: the reach in each direction wobbles, and walls cut the fire off from the far side.
    const edge = Array.from({ length: 48 }, (_, i) => { const a = i / 48 * Math.PI * 2; return R * (.8 + .12 * Math.sin(a * 3 + 1.3) + .08 * Math.sin(a * 7 + .4) + rnd(0, .05)); });
    const reach = a => { const f = ((a % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2) / (Math.PI * 2) * 48, i = Math.floor(f), k = f - i; return mix(edge[i % 48], edge[(i + 1) % 48], k); };
    const list = [];
    for (let x = -R; x <= R; x += .62) for (let z = -R; z <= R; z += .62) {
      const px = x + rnd(-.28, .28), pz = z + rnd(-.28, .28), d = Math.hypot(px, pz), ang = Math.atan2(pz, px);
      if (d > reach(ang)) continue;
      const p = center.clone().add(V(px, 0, pz));
      if (Math.hypot(p.x, p.z) > A.arenaR - .3 || inObstacle(p.clone().setY(.3), .1)) continue;
      if (d > .5 && A.wallOnRay(center.clone().setY(.4), V(px, 0, pz).normalize(), d)) continue;
      const rim = d / reach(ang), big = Math.random() < .22 * (1 - rim * .6);
      const h = big ? rnd(1.6, E.flameH) : rnd(.25, 1.1) * (1.1 - rim * .5);
      const born = d < E.start ? E.ignite + rnd(0, .08) : E.spread + (d - E.start) / (R - E.start) * (E.full - E.spread) + rnd(-.04, .08);
      list.push({ p, d, rim, h, w: big ? rnd(.45, .8) : rnd(.22, .45), born, die: E.burnEnd + (1 - rim) * (E.gone - E.burnEnd - .1) + rnd(0, .08), ph: rnd(0, 6), f: rnd(6, 11) });
    }
    const n = list.length;
    const core = new T.InstancedMesh(FLAME_GEO, flameCore(), n);
    const halo = new T.InstancedMesh(FLAME_GEO, flameHalo(), n);
    core.frustumCulled = halo.frustumCulled = false; core.instanceMatrix.setUsage(T.DynamicDrawUsage); halo.instanceMatrix.setUsage(T.DynamicDrawUsage);
    keep(core); keep(halo);
    // Scorched ground under the fire.
    const shape = new T.Shape(); for (let i = 0; i <= 48; i++) { const a = i / 48 * Math.PI * 2, r = edge[i % 48] * 1.02; i ? shape.lineTo(Math.cos(a) * r, Math.sin(a) * r) : shape.moveTo(Math.cos(a) * r, Math.sin(a) * r); }
    const scorch = keep(new T.Mesh(new T.ShapeGeometry(shape), new T.MeshBasicMaterial({ color: 0x0a0606, transparent: true, opacity: 0, depthWrite: false })));
    scorch.rotation.x = Math.PI / 2; scorch.scale.y = -1; scorch.position.copy(center).setY(.02);
    const glowDisc = keep(sprite(glowTex, 0x7a0008, 0, false)); glowDisc.position.copy(center).setY(.6); glowDisc.scale.setScalar(R * 2.4);
    // Black flame sheets over the tongues: billboards that flicker and sway, a dark red rim behind each.
    const sheets = keep(new T.Group()), tongues = [];
    const tall = list.filter(f => f.h > .9 * S || Math.random() < .12).sort(() => Math.random() - .5).slice(0, 90);
    for (const f of tall) {
      const rim = new T.Sprite(new T.SpriteMaterial({ map: flameTex, color: 0x8a0610, transparent: true, depthWrite: false, opacity: 0 })); rim.renderOrder = 3;
      const core = new T.Sprite(new T.SpriteMaterial({ map: flameTex, color: 0x050304, transparent: true, depthWrite: false, opacity: 0 })); core.renderOrder = 4;
      sheets.add(rim, core); tongues.push({ f, rim, core, ph: rnd(0, 6), s: rnd(1.1, 1.8) });
    }
    return { center, start, list, core, halo, scorch, glowDisc, sheets, tongues, reach, hits: new Map(), dummy: new T.Object3D(), nextEmber: 0, flags: {} };
  }
  // Damage, slow and visuals of one fire field. Damage: first entry 10 once per field, then 6 every second inside, 5 at most.
  function updateField(F, dt) {
    const E = CFG.e, a = A.time - F.start, D = F.dummy;
    let shown = 0;
    for (let i = 0; i < F.list.length; i++) {
      const f = F.list[i]; let k = seg(a, f.born, f.born + .18); k = outP(k, 2) * (1 - ease(seg(a, f.die, f.die + .3)));
      if (k <= .001) { D.scale.setScalar(0); D.position.copy(f.p); D.updateMatrix(); F.core.setMatrixAt(i, D.matrix); F.halo.setMatrixAt(i, D.matrix); continue; }
      shown++;
      const fl = .78 + .22 * Math.sin(A.time * f.f + f.ph) + .1 * Math.sin(A.time * f.f * 2.3 + f.ph * 2);
      D.position.copy(f.p); D.rotation.set(Math.sin(A.time * 2 + f.ph) * .12, A.time * .8 + f.ph, Math.cos(A.time * 2.4 + f.ph) * .12);
      D.scale.set(f.w * k, f.h * k * fl, f.w * k); D.updateMatrix(); F.core.setMatrixAt(i, D.matrix);
      D.scale.set(f.w * k * 1.32, f.h * k * fl * 1.12, f.w * k * 1.32); D.updateMatrix(); F.halo.setMatrixAt(i, D.matrix);
    }
    F.core.instanceMatrix.needsUpdate = F.halo.instanceMatrix.needsUpdate = true;
    F.core.material.uniforms.uTime.value = F.halo.material.uniforms.uTime.value = A.time;
    for (const g of F.tongues) {
      const f = g.f; let k = seg(a, f.born, f.born + .22); k = outP(k, 2) * (1 - ease(seg(a, f.die - .1, f.die + .25)));
      const fl = .8 + .2 * Math.sin(A.time * 9 + g.ph) + .1 * Math.sin(A.time * 21 + g.ph * 2), h = Math.max(.01, f.h * g.s * k * fl), w = h * .5;
      g.core.position.copy(f.p).setY(f.p.y + h * .46); g.core.scale.set(w, h, 1); g.core.material.opacity = .92 * Math.min(1, k * 1.5);
      g.rim.position.copy(g.core.position).setY(g.core.position.y + h * .02); g.rim.scale.set(w * 1.28, h * 1.1, 1); g.rim.material.opacity = .7 * Math.min(1, k * 1.5);
      g.core.material.rotation = g.rim.material.rotation = Math.sin(A.time * 3 + g.ph) * .14;
    }
    const life = seg(a, E.ignite, E.full) * (1 - seg(a, E.burnEnd, E.gone));
    F.scorch.material.opacity = .75 * outP(seg(a, E.ignite, E.full), 2) * (1 - seg(a, E.gone - .2, E.gone + .5));
    F.glowDisc.material.opacity = .45 * life;
    const rNow = a < E.spread ? E.start * outP(seg(a, E.ignite, E.ignite + .2)) : mix(E.start, E.radius, ease(seg(a, E.spread, E.full)));
    // Heat: dark smoke, ash and red sparks drifting up from the fire.
    if (life > .05 && A.time >= F.nextEmber) {
      F.nextEmber = A.time + .03;
      const f = F.list[Math.floor(Math.random() * F.list.length)];
      if (f && a > f.born) {
        if (Math.random() < .5) puff(f.p.clone().setY(f.h * .8), rnd(1.2, 2.4), rnd(1.2, 2), V(rnd(-.2, .2), rnd(.6, 1.2), rnd(-.2, .2)), 0x120c0c, .45);
        const e = sprite(glowTex, Math.random() < .6 ? 0xff2a1a : 0x220000, 1, false); e.position.copy(f.p).setY(rnd(.2, f.h)); e.scale.setScalar(rnd(.06, .12)); const v = V(rnd(-.3, .3), rnd(1, 2.2), rnd(-.3, .3));
        fx(e, rnd(.8, 1.4), (o, u, d) => { o.position.addScaledVector(v, d); o.material.opacity = 1 - u; });
      }
    }
    if (a >= E.spread && !F.flags.spread) { F.flags.spread = true; if (basePos.distanceTo(F.center) < 30) shake(.05); sfx.ignite(); }
    // Server rule: inside = within the current fire edge, standing (not flying above the flames), not behind a wall.
    for (const t of targets) {
      if (!alive(t) || t === attacker) continue;
      const rel = t.g.position.clone().sub(F.center).setY(0), d = rel.length(), ang = Math.atan2(rel.z, rel.x);
      const inside = a >= E.ignite && a < E.burnEnd + .3 && d < Math.min(rNow, F.reach(ang)) && t.g.position.y < E.flameH && !(d > .5 && A.wallOnRay(F.center.clone().setY(.4), rel.clone().normalize(), d));
      let h = F.hits.get(t);
      if (inside) {
        if (!h) { h = { ticks: 0, last: A.time }; F.hits.set(t, h); A.hit(t, E.entry, '#ff4040'); feetFire(t); }
        else if (h.ticks < E.ticks && A.time - h.last >= 1) { h.ticks++; h.last = A.time; A.hit(t, E.tick, '#c02828'); feetFire(t); }
        h.inside = true; t.itBurnUntil = A.time + .1;
      } else if (h) { h.inside = false; if (A.time - h.last >= 1) h.last = A.time - .999; }
    }
    if (a >= E.gone + .6) { kill(F.core); kill(F.halo); kill(F.scorch); kill(F.glowDisc); kill(F.sheets); return false; }
    return true;
  }
  // A few black tongues licking up around a burning dummy's feet (the fire on the ground stays the main thing).
  function feetFire(t) {
    for (let i = 0; i < 5; i++) {
      const m = new T.Mesh(FLAME_GEO, new T.MeshBasicMaterial({ color: BLACK })); const a = i / 5 * Math.PI * 2 + rnd(0, .5);
      m.position.copy(t.g.position).add(V(Math.cos(a) * .4, 0, Math.sin(a) * .4)); const h = rnd(.6, 1.1), w = rnd(.2, .32);
      fx(m, .8, (o, u) => { const k = Math.sin(u * Math.PI); o.scale.set(w * k, h * k * (.8 + .2 * Math.sin(A.time * 20 + i)), w * k); o.position.x = t.g.position.x + Math.cos(a) * .4; o.position.z = t.g.position.z + Math.sin(a) * .4; });
    }
  }

  // ---------- R: Susanoo · Yata Mirror · Totsuka Blade ----------
  function chakra(color = 0xff2b2b, edge = 0xffb070, opacity = .5) {
    return new T.ShaderMaterial({
      uniforms: { uColor: { value: new T.Color(color) }, uEdge: { value: new T.Color(edge) }, uOp: { value: opacity }, uK: { value: 0 }, uTime: { value: 0 } },
      // Chakra burns like fire: the surface licks upward (vertex wobble along the normal) and bright tongues of
      // flame run up through it; the rim glows gold.
      vertexShader: 'uniform float uTime;varying vec3 vN;varying vec3 vV;varying vec3 vW;void main(){vec4 w0=modelMatrix*vec4(position,1.);float fl=(sin(w0.y*3.1-uTime*7.+w0.x*2.3)*.5+.5)*(sin(w0.y*1.7-uTime*4.3+w0.z*2.9)*.5+.5);vec3 p=position+normal*fl*.14;vec4 w=modelMatrix*vec4(p,1.);vW=w.xyz;vN=normalize(mat3(modelMatrix)*normal);vV=normalize(cameraPosition-w.xyz);gl_Position=projectionMatrix*viewMatrix*w;}',
      fragmentShader: 'uniform vec3 uColor;uniform vec3 uEdge;uniform float uOp;uniform float uK;uniform float uTime;varying vec3 vN;varying vec3 vV;varying vec3 vW;void main(){float f=pow(1.-abs(dot(normalize(vN),vV)),2.);float n1=sin(vW.y*3.2-uTime*8.+sin(vW.x*2.1+uTime*1.7)*2.)*.5+.5;float n2=sin(vW.y*6.1-uTime*11.+vW.z*3.3+sin(vW.x*4.+uTime*2.)*1.5)*.5+.5;float flame=n1*n2;float form=smoothstep(uK-.25,uK,fract(vW.y*.35+n1*.15));vec3 c=mix(uColor*(.5+.6*flame),uEdge,clamp(f*.8+flame*.4,0.,1.));float a=uOp*(.28+.6*f+.55*flame)*uK*(1.-form*(1.-uK));gl_FragColor=vec4(c,clamp(a,0.,1.));}',
      transparent: true, depthWrite: false, side: T.DoubleSide,
    });
  }
  let su = null;
  function buildSusanoo() {
    const g = new T.Group(); scene.add(g); live.add(g); const parts = [];
    const add = (geo, stage, at, dur, pos, rot, scale, parent = g, m = chakra()) => { const x = new T.Mesh(geo, m); parent.add(x); if (pos) x.position.set(...pos); if (rot) x.rotation.set(...rot); if (scale) x.scale.set(...scale); x.frustumCulled = false; x.renderOrder = 5; parts.push({ x, stage, at, dur }); return x; };
    // Ribs: six pairs appearing one by one around the caster.
    for (let i = 0; i < 6; i++) for (const s of [-1, 1]) {
      const w = new T.Group(); g.add(w); w.position.set(0, 2.55 - i * .36, 0); w.rotation.y = 1.17; w.scale.x = s;
      const r = 1.25 - Math.abs(i - 2) * .06; add(new T.TorusGeometry(r, .075 - i * .004, 6, 28, 2.74), 'ribs', CFG.r.ribs + i * .07, .18, null, [Math.PI / 2, 0, 0], null, w);
    }
    for (let i = 0; i < 8; i++) add(new T.BoxGeometry(.32, .26, .3), 'spine', CFG.r.upper + i * .03, .15, [0, .5 + i * .58, 1.35]);
    add(new T.SphereGeometry(2.6, 22, 14, 0, Math.PI * 2, 0, Math.PI * .62), 'torso', 1.0, .25, [0, 4.1, .7], null, [1.25, 1, .85], g, chakra(0xff2424, 0xffa060, .32));
    const head = new T.Group(); g.add(head); head.position.set(0, 7.25, .55);
    add(new T.SphereGeometry(1.05, 20, 14), 'head', 1.15, .2, null, null, [1, 1.12, 1.05], head);
    add(new T.ConeGeometry(.22, 1.3, 10), 'head', 1.17, .2, [0, -.05, -1.35], [-Math.PI / 2, 0, 0], null, head);           // the long nose
    add(new T.BoxGeometry(1.3, .45, .9), 'head', 1.19, .2, [0, -.85, -.35], null, null, head);                               // jaw
    for (const s of [-1, 1]) add(new T.ConeGeometry(.16, 1.2, 8), 'head', 1.21, .2, [s * .55, .95, .3], [-.5, 0, s * .4], null, head);
    const eyesS = []; for (const s of [-1, 1]) { const e = sprite(glowTex, 0xffd080, 0, true); e.position.set(s * .38, .1, -.92); e.scale.setScalar(.6); head.add(e); eyesS.push(e); }
    const mkArm = s => {
      const sh = new T.Group(); g.add(sh); sh.position.set(s * 3.1, 5.6, .45); sh.rotation.order = 'YXZ';   // yaw swings the raised arm sideways
      add(new T.SphereGeometry(.95, 16, 12), 'arms', .95, .15, null, null, null, sh);
      add(new T.CylinderGeometry(.55, .45, 2.9, 14), 'arms', 1.0, .15, [0, -1.45, 0], null, null, sh);
      const el = new T.Group(); sh.add(el); el.position.y = -2.9;
      add(new T.CylinderGeometry(.45, .4, 2.6, 14), 'arms', 1.05, .15, [0, -1.3, 0], null, null, el);
      const hand = new T.Group(); el.add(hand); hand.position.y = -2.75;
      add(new T.BoxGeometry(1.05, 1.15, .45), 'hands', 1.1, .15, null, null, null, hand);
      for (let i = 0; i < 4; i++) add(new T.CapsuleGeometry(.13, .65, 4, 8), 'hands', 1.12 + i * .02, .12, [(-.36 + i * .24) * s, -.95, -.05], [.35, 0, 0], null, hand);
      add(new T.CapsuleGeometry(.15, .5, 4, 8), 'hands', 1.2, .12, [s * .62, -.25, -.2], [0, 0, s * .8], null, hand);
      return { sh, el, hand, s };
    };
    const L = mkArm(-1), R = mkArm(1);
    // Yata Mirror on the left hand; the Totsuka blade lives in the world so it can aim freely.
    const mirrorG = new T.Group(); L.hand.add(mirrorG); mirrorG.position.set(0, -1.2, -.6); mirrorG.rotation.x = Math.PI / 2;
    const mirrorFace = new T.Mesh(new T.CircleGeometry(2.3, 48), new T.MeshBasicMaterial({ map: mirrorTex, transparent: true, opacity: 0, depthWrite: false, side: T.DoubleSide })); mirrorG.add(mirrorFace);
    const mirrorRim = new T.Mesh(new T.TorusGeometry(2.32, .12, 8, 64), chakra(0xffb040, 0xfff0b0, .9)); mirrorG.add(mirrorRim);
    const blade = new T.Group(); scene.add(blade); live.add(blade);
    const bladeCore = new T.Mesh(new T.CylinderGeometry(.16, .34, 1, 14, 1, true), chakra(0xff2a1c, 0xffd070, .95)); bladeCore.geometry.translate(0, .5, 0); bladeCore.rotation.x = Math.PI / 2; blade.add(bladeCore);
    const bladeTip = new T.Mesh(new T.ConeGeometry(.16, .9, 12), chakra(0xff3a20, 0xffe090, .95)); bladeTip.rotation.x = Math.PI / 2; blade.add(bladeTip);
    const blobs = []; for (let i = 0; i < 10; i++) { const b = new T.Mesh(new T.SphereGeometry(.22, 10, 8), chakra(0xff3020, 0xffd080, .9)); scene.add(b); live.add(b); b.visible = false; blobs.push({ b, o: V(rnd(-2, 2), rnd(-1.5, 2), rnd(-2, 2)) }); }
    blade.visible = false;
    return { g, parts, head, eyesS, L, R, mirrorG, mirrorFace, mirrorRim, blade, bladeCore, bladeTip, blobs, len: 0 };
  }
  function mirrorRipple() { if (!su) return; const p = su.mirrorG.getWorldPosition(V()); ring(p, A.flatForward(), 3.6, 0xff4030, .45, .08, .9, 2.2); glowAt(p, 0xff6040, 2.5, .3, 1.2, .7); sfx.mirror(); }
  function beginSusanoo(c) {
    c.dir = A.flatForward(); c.duration = CFG.r.end + .05; c.state = 'Casting';
    if (su) disposeSusanoo();
    su = buildSusanoo(); su.g.position.copy(basePos).setY(0); su.g.rotation.y = A.yaw;
    c.yaw0 = A.yaw;
    A.title('須佐能乎', '스사노오 · 토츠카의 검', '형성 → 야타의 거울(전방 피해 60%↓) → 전방 강타 24 · 24 · 30 → 토츠카의 검 찌르기 10 → 봉인 15', '#ff3b3b');
    sfx.eye(); sfx.hum();
  }
  // Right-arm keyframes for the three smashes: [time, shoulder pitch, elbow, shoulder yaw (+ = left), roll, body twist].
  function armKeys(a) {
    const R = CFG.r;
    const K = [[0, .25, .45, 0, .15, 0], [R.s1w, .25, .45, 0, .15, 0], [R.s1w + .17, .15, 1.9, -.25, .2, -.25], [R.s1, 1.5, .05, -.05, .12, .1],
      [R.s2w, 1.0, .5, -.3, .3, 0], [R.s2w + .18, 1.35, .25, -1.05, .55, -.35], [R.s2, 1.35, .2, 1.0, .4, .35],
      [R.s3w, 1.1, .6, .3, .2, 0], [R.s3w + .2, 2.9, .5, 0, .1, 0], [R.s3, .95, .05, 0, .1, 0], [R.blade, .25, .45, 0, .15, 0]];
    if (a >= K[K.length - 1][0]) return K[K.length - 1].slice(1);
    let i = 0; while (i < K.length - 2 && a >= K[i + 1][0]) i++;
    const [t0, ...p] = K[i], [t1, ...q] = K[i + 1];
    const hitKey = t1 === R.s1 || t1 === R.s2 || t1 === R.s3, k = hitKey ? outP(seg(a, t0, t1), 3) : ease(seg(a, t0, t1));
    return p.map((v, j) => mix(v, q[j], k));
  }
  // One smash: every body in front (within reach and the arc, not behind a wall, not sealed) takes the hit once.
  function susanooSmash(c, i, fist) {
    const R = CFG.r, dmg = R.hits[i], arc = R.arcs[i] * Math.PI / 180, me = basePos.clone().setY(0), dir = c.dir;
    let n = 0;
    for (const t of targets) {
      if (!alive(t) || t === attacker || binds.get(t)?.kind === 'seal' || binds.get(t)?.kind === 'sealed') continue;
      const rel = t.g.position.clone().setY(0).sub(me), d = rel.length();
      if (d > R.strikeR || d < .2 || Math.acos(clamp(rel.clone().normalize().dot(dir), -1, 1)) > arc) continue;
      if (A.wallOnRay(me.clone().setY(1), rel.clone().normalize(), d)) continue;
      A.hit(t, dmg, '#ff6a4a'); n++;
      if (!t.locked) { const push = rel.normalize(); t.vel = push.multiplyScalar(i === 2 ? 3 : 2.5).add(V(0, i === 2 ? 7 : 3.5, 0)); }
      glowAt(t.g.position.clone().setY(1.4), 0xff4020, 1.6, .3, 1.5, .9);
    }
    const ground = me.clone().addScaledVector(dir, i === 2 ? 6 : 7).setY(.08);
    const at = i === 2 ? ground : fist;
    glowAt(at, 0xffb060, i === 2 ? 5 : 3.5, .35, 1.6, .9); glowAt(at, 0xff2a1a, i === 2 ? 8 : 6, .5, 1.2, .7);
    ring(i === 2 ? ground : at, i === 2 ? UP : dir, i === 2 ? 9 : 6, 0xff3020, .55, .08, .9, 1);
    for (let k = 0; k < (i === 2 ? 22 : 12); k++) puff(ground.clone().add(V(rnd(-3, 3), 0, rnd(-3, 3))), rnd(1.4, 2.6), rnd(.7, 1.1), V(rnd(-2, 2), rnd(.5, 2), rnd(-2, 2)), 0x2a1010, .5);
    if (i === 1) for (let k = 0; k < 18; k++) { const ang = -1 + k / 17 * 2, p = me.clone().add(V(0, 3.2, 0)).addScaledVector(dir.clone().applyAxisAngle(UP, ang), 7); const e = sprite(flameTex, k % 3 ? 0xff2a1a : GOLD, .9, true); e.position.copy(p); e.scale.set(1.2, 2.4, 1); fx(e, .4, (o, u) => { o.material.opacity = .9 * (1 - u); o.position.y += .03; }); }
    sfx.impact(); A.hitstop(i === 2 ? 110 : 70); shake(i === 2 ? .22 : .14); A.flash('#ff6040', i === 2 ? .3 : .2);
    say(['스사노오 강타 · ', '스사노오 휩쓸기 · ', '스사노오 내려치기 · '][i] + dmg + (n ? '' : ' · 빗나감'), .8);
  }
  // Rising tongues of red chakra flame from random parts of the formed body.
  function flameTongues(s, a) {
    const shown = s.parts.filter(p => p.x.visible); if (!shown.length || a > CFG.r.end - .3) return;
    for (let k = 0; k < 12; k++) {
      const p = shown[Math.floor(Math.random() * shown.length)].x; const w = p.getWorldPosition(V());
      const r = (p.geometry.boundingSphere || (p.geometry.computeBoundingSphere(), p.geometry.boundingSphere)).radius * p.getWorldScale(V()).x;
      w.add(V(rnd(-r, r), rnd(-r * .5, r * .5), rnd(-r, r)));
      const e = sprite(flameTex, Math.random() < .25 ? 0xff9a3a : 0xff2418, .85, true); e.position.copy(w);
      const sz = rnd(.8, 1.7) * (1 + r * .15), v = V(rnd(-.3, .3), rnd(3, 5.5), rnd(-.3, .3)), rot = rnd(-.3, .3); e.material.rotation = rot;
      fx(e, rnd(.35, .6), (o, u, d) => { o.position.addScaledVector(v, d); const g = Math.sin(u * Math.PI); o.scale.set(sz * (1 - u * .5), sz * 2 * g + .01, 1); o.material.opacity = .85 * (1 - u); });
    }
  }
  function stageK(p, a) { return ease(seg(a, p.at, p.at + p.dur)); }
  function updateSusanoo(c, a, dt) {
    const R = CFG.r, s = su; if (!s) return;
    c.state = a < R.ribs ? 'Casting' : a < R.mirror ? 'SusanooForming' : a < R.s1w ? 'Shielding' : a < R.blade ? 'Smashing' : a < R.thrust ? 'BladeCharging' : a < R.strikeEnd ? 'Striking' : a < R.sealEnd && c.target ? 'Sealing' : 'Recovering';
    const fadeAll = ease(seg(a, R.end - .8, R.end - .3)), ribsFade = ease(seg(a, R.end - .4, R.end - .05));
    for (const p of s.parts) {
      const k = stageK(p, a) * (p.stage === 'ribs' ? 1 - ribsFade : 1 - fadeAll);
      p.x.material.uniforms.uK.value = k; p.x.material.uniforms.uTime.value = A.time; p.x.visible = k > .01;
      if (p.stage === 'ribs' && a < p.at + p.dur + .02 && a >= p.at && !p.played) { p.played = true; if (p.x.parent.scale.x > 0) sfx.rib(); }
    }
    for (const e of s.eyesS) e.material.opacity = ease(seg(a, 1.2, 1.35)) * (1 - fadeAll);
    // Ground ring when the ribcage closes; the rise sound with the upper body.
    if (a >= .95 && !c.flags.ring) { c.flags.ring = true; ring(basePos.clone().setY(.06), UP, 6, 0xff2a2a, .6, .06, .9, 1); for (let i = 0; i < 10; i++) puff(basePos.clone().setY(.2).add(V(rnd(-2, 2), 0, rnd(-2, 2))), 1.6, .8, V(rnd(-1.5, 1.5), .3, rnd(-1.5, 1.5)), 0x2a0a0a, .4); }
    if (a >= R.upper && !c.flags.rise) { c.flags.rise = true; sfx.rise(); }
    // Chakra drifting up around the caster.
    if (a < R.end - .6 && Math.random() < .6) { const e = sprite(glowTex, Math.random() < .5 ? 0xff2020 : 0x600000, 1, true); e.position.copy(basePos).setY(rnd(.2, 2.5)).add(V(rnd(-1.4, 1.4), 0, rnd(-1.4, 1.4))); e.scale.setScalar(rnd(.08, .18)); const v = V(0, rnd(.8, 2), 0); fx(e, .9, (o, u, d) => { o.position.addScaledVector(v, d); o.material.opacity = 1 - u; }); }
    // Arm motion. Rest: arms hang forward. Mirror: left arm up and forward. Blade: right hand raised, drawn back, thrust.
    const L = s.L, Rr = s.R;
    const mUp = ease(seg(a, R.mirror, R.mirror + .4)) * (1 - ease(seg(a, R.sealEnd + .15, R.sealEnd + .6)));
    L.sh.rotation.set(.25 + .95 * mUp, 0, -.15 + .3 * mUp); L.el.rotation.set(.45 - .1 * mUp, 0, 0); L.hand.rotation.set(0, 0, 0);
    const raise = ease(seg(a, R.blade, R.blade + .5)), pull = ease(seg(a, R.aim, R.thrust)), thrust = outP(seg(a, R.thrust, R.thrust + .25), 4), lowerR = ease(seg(a, R.sealEnd, R.sealEnd + .55));
    // Before the blade: a straight punch, a sweep from right to left, an overhead hammer into the ground.
    let [shX, elX, shY, shZ, twist] = armKeys(a);
    if (a >= R.blade) {
      shX = mix(.25, 1.0, raise); elX = mix(.45, 1.5, raise); shY = 0; shZ = .15; twist = 0;
      shX = mix(shX, .25, pull); elX = mix(elX, 1.9, pull); shY = -.35 * pull;
      shX = mix(shX, 1.55, thrust); elX = mix(elX, .05, thrust); shY = mix(shY, .12, thrust);
    }
    Rr.sh.rotation.set(mix(shX, .25, lowerR), mix(shY, 0, lowerR), mix(shZ, .15, lowerR)); Rr.el.rotation.set(mix(elX, .45, lowerR), 0, 0);
    s.g.rotation.y = c.yaw0 + twist;
    s.g.rotation.x = (mix(0, -.12, pull) * (1 - thrust * .5) - .1 * bump(a, R.s1w, R.s1 + .2) - .16 * bump(a, R.s3w + .1, R.s3 + .25)) * (1 - lowerR);
    for (let i = 0; i < 3; i++) if (a >= [R.s1, R.s2, R.s3][i] && !c.flags['smash' + i]) { c.flags['smash' + i] = true; s.g.updateMatrixWorld(true); susanooSmash(c, i, Rr.hand.getWorldPosition(V())); }
    // Fire: tongues of red chakra flame rising off the whole body.
    flameTongues(s, a);
    // Mirror: its surface flows; it shatters into red motes at the end.
    // The mirror thins while the right arm smashes through the space in front of it, so the hits stay readable.
    const thin = 1 - .75 * ease(seg(a, R.s1w - .1, R.s1w + .1)) * (1 - ease(seg(a, R.blade - .1, R.blade + .2)));
    s.mirrorFace.material.opacity = .85 * thin * ease(seg(a, R.mirror + .15, R.mirror + .55)) * (1 - ease(seg(a, R.sealEnd + .15, R.sealEnd + .45)));
    s.mirrorFace.rotation.z = A.time * .6; s.mirrorRim.material.uniforms.uK.value = ease(seg(a, R.mirror + .1, R.mirror + .45)) * (1 - ease(seg(a, R.sealEnd + .15, R.sealEnd + .45))); s.mirrorRim.material.uniforms.uTime.value = A.time;
    if (a >= R.mirror + .2 && !c.flags.mirror) { c.flags.mirror = true; sfx.mirror(); say('야타의 거울 · 전방 피해 60% 감소', 1.5); }
    if (a >= R.sealEnd + .15 && !c.flags.mirrorBreak) { c.flags.mirrorBreak = true; const p = s.mirrorG.getWorldPosition(V()); for (let i = 0; i < 40; i++) { const e = sprite(glowTex, 0xff3020, 1, true); e.position.copy(p).add(V(rnd(-2, 2), rnd(-2, 2), rnd(-.3, .3))); e.scale.setScalar(rnd(.15, .35)); const v = V(rnd(-1, 1), rnd(0, 2), rnd(-1, 1)); fx(e, rnd(.6, 1.1), (o, u, d) => { o.position.addScaledVector(v, d); o.material.opacity = 1 - u; }); } sfx.fade(); }
    // Blade: liquid gathers at the right hand, stretches into a sword, extends on the thrust.
    s.g.updateMatrixWorld(true);
    const hand = Rr.hand.getWorldPosition(V()).add(V(0, -1, 0));
    const gather = seg(a, R.blade, R.blade + .4), form = ease(seg(a, R.blade + .3, R.aim));
    for (const b of s.blobs) { b.b.visible = gather > 0 && form < 1; b.b.position.copy(hand).addScaledVector(b.o, 1 - ease(gather)); b.b.scale.setScalar(.5 + .8 * (1 - form)); b.b.material.uniforms.uK.value = 1 - form; b.b.material.uniforms.uTime.value = A.time; }
    if (a >= R.blade && !c.flags.liquid) { c.flags.liquid = true; sfx.liquid(); }
    let aimPt = hand.clone().addScaledVector(c.dir, 10).setY(2);
    if (a >= R.thrust && !c.flags.pick) {
      c.flags.pick = true; c.state = 'Striking';
      const t = firstAhead(basePos.clone().setY(0), c.dir, R.reach, R.width);
      if (t && (binds.get(t)?.kind !== 'seal')) { c.target = t; c.hitPoint = t.g.position.clone().setY(1.4); }
      sfx.thrust();
    }
    if (c.target) aimPt = c.sealPoint || c.target.g.position.clone().setY(c.target.g.position.y + 1.4);
    else if (a >= R.thrust) { const w = firstWall(basePos.clone().setY(1.4), c.dir, R.reach); aimPt = basePos.clone().setY(1.6).addScaledVector(c.dir, w); }
    const full = hand.distanceTo(aimPt);
    let len = 5.5 * form;
    if (a >= R.thrust) len = mix(5.5, full, outP(seg(a, R.thrust, R.tip), 3));
    if (!c.target && a >= R.tip) len = mix(full, 5.5, ease(seg(a, R.tip + .1, R.strikeEnd + .2)));
    if (c.target && a >= R.seal) len = mix(full, 4.5, ease(seg(a, R.sealEnd, R.sealEnd + .35)));
    const bladeK = form * (1 - ease(seg(a, R.sealEnd, R.sealEnd + .35)));
    s.blade.visible = bladeK > .01; s.blade.position.copy(hand); s.blade.lookAt(a >= R.aim - .1 ? aimPt : hand.clone().addScaledVector(c.dir, 5).add(V(0, 2.5 * (1 - pull), 0)));
    s.bladeCore.scale.set(1 + .3 * Math.sin(A.time * 9), 1 + .3 * Math.sin(A.time * 9), Math.max(.01, len)); s.bladeCore.position.z = 0;
    s.bladeCore.scale.y = Math.max(.01, len); s.bladeCore.scale.x = s.bladeCore.scale.z = 1 + .15 * Math.sin(A.time * 11);
    s.bladeTip.position.set(0, 0, len + .4);
    for (const m of [s.bladeCore, s.bladeTip]) { m.material.uniforms.uK.value = bladeK; m.material.uniforms.uTime.value = A.time; }
    if (a >= R.thrust && a < R.tip + .1 && Math.random() < .9) { const p = hand.clone().lerp(aimPt, rnd(0, 1)); const e = sprite(glowTex, Math.random() < .3 ? GOLD : 0xff2020, .9, true); e.position.copy(p); e.scale.setScalar(rnd(.3, .7)); fx(e, .35, (o, u) => { o.material.opacity = .9 * (1 - u); }); }
    // Hit, lift, seal.
    const t = c.target;
    if (a >= R.tip && !c.flags.tip) {
      c.flags.tip = true;
      if (t && alive(t)) {
        A.hit(t, R.d1, '#ffcf6a'); sfx.impact(); A.hitstop(90); shake(.18); A.flash('#ffd8a0', .35);
        glowAt(aimPt, 0xffffff, 2.5, .3, 2, 1); glowAt(aimPt, GOLD, 4, .5, 1.5, .8); ring(aimPt, c.dir, 4, 0xff3020, .5, .1, .95);
        binds.set(t, { until: A.time + 3, kind: 'seal' }); t.locked = true; t.vel = null; t.g.userData.cannonUntil = Infinity; c.sealFrom = t.g.position.clone(); c.home = t.g.position.clone().setY(0);
        say('토츠카의 검 적중 · ' + R.d1 + ' · 봉인', 1);
      } else { c.missed = true; c.target = null; A.toast('토츠카의 검 빗나감 · 봉인 없음'); A.cooldowns.susanoo = Math.max(A.cooldowns.susanoo, A.time + 90 - (A.time - c.start)); sfx.whoosh(); }
    }
    if (t && c.flags.tip) {
      if (t.hp <= 0) { if (!c.flags.lost) { c.flags.lost = true; releaseBind(t); t.g.scale.setScalar(1); c.target = null; } }
      else {
        // 3.9-4.15 pinned on the tip; 4.15-4.6 drawn up the blade, feet off the ground; 4.6-5.35 shrinking into it.
        const tipPt = hand.clone().addScaledVector(aimPt.clone().sub(hand).normalize(), full);
        const into = hand.clone().lerp(tipPt, .55);
        const lift = ease(seg(a, R.tip, R.strikeEnd)), draw = ease(seg(a, R.strikeEnd, R.seal)), suck = inP(seg(a, R.seal, R.sealEnd), 1.6);
        const pos = c.sealFrom.clone().add(V(0, 1.4 * lift, 0)).lerp(into.clone().setY(into.y - 1.2), draw * .45).lerp(into.clone().setY(into.y - 1.2), suck);
        if (a < R.sealEnd + .02) { t.g.position.copy(pos); t.g.rotation.y += dt * (2 + 14 * suck); t.g.rotation.x = .3 * lift; t.g.scale.setScalar(Math.max(.02, 1 - suck)); const [la, ra] = limbs(t); la.rotation.z = -.8 * lift; ra.rotation.z = .8 * lift; }
        c.sealPoint = a >= R.strikeEnd ? into : null;
        if (a >= R.strikeEnd && !c.flags.sealStart) { c.flags.sealStart = true; sfx.seal(); vortexRings(c, t); }
        if (a >= R.sealHit && !c.flags.d2) { c.flags.d2 = true; A.hit(t, R.d2, '#ff7a5a'); }
        if (a >= R.sealEnd && !c.flags.gone) { c.flags.gone = true; t.g.visible = false; sfx.sealed(); glowAt(into, 0xff3020, 2, .4, 1, 1); say('봉인 공간 · 1.8초', 1.2); }
      }
    }
    // Camera: first person, a rear shot of Susanoo rising, over the shoulder for the mirror, a side shot of the blade,
    // first person to aim and thrust, then a shot holding both the blade and the target, and back to first person.
    const dir = c.dir, side = V().crossVectors(dir, UP).normalize(), me = basePos.clone();
    const shots = [
      [R.upper, R.mirror, me.clone().addScaledVector(dir, -9).add(V(0, 5.5, 0)).addScaledVector(side, 1.5), me.clone().add(V(0, 4.5, 0)).addScaledVector(dir, 2)],
      [R.mirror, R.s1w, me.clone().addScaledVector(dir, -8).addScaledVector(side, 3.5).add(V(0, 4.5, 0)), me.clone().addScaledVector(dir, 8).add(V(0, 1.5, 0))],
      // The three smashes from the striking-arm flank, ahead of Susanoo: the arm, the fist and the targets in one frame.
      [R.s1w, R.blade, me.clone().addScaledVector(side, -13).addScaledVector(dir, 5).add(V(0, 5, 0)), me.clone().addScaledVector(dir, 6).add(V(0, 3.2, 0))],
      [R.blade, R.aim, me.clone().addScaledVector(side, 10).addScaledVector(dir, 1.5).add(V(0, 2.4, 0)), hand.clone().addScaledVector(dir, 2).setY(4)],
    ];
    if (c.target && c.flags.tip) { const mid = basePos.clone().lerp(c.home || basePos, .55).setY(3); shots.push([R.strikeEnd, R.sealEnd + .2, mid.clone().addScaledVector(side, 11).add(V(0, 3, 0)), mid]); }
    let w = 0, pos = null, look = null;
    for (const [from, to, p, l] of shots) { const k = ease(seg(a, from - .05, from + .2)) * (1 - ease(seg(a, to - .2, to + .05))); if (k > w) { w = k; pos = p; look = l; } }
    c.cine = w; c.shotPos = pos; c.shotLook = look;
    // First-person arms lower slowly and stay low; the head bows at the start and nods at the end.
    const low = ease(seg(a, 0, .6)) * (1 - ease(seg(a, R.end - .4, R.end)));
    poseArm(arms.r, lerpPose(REST, LOW, low)); poseArm(arms.l, lerpPose(L_REST, mirror(LOW), low));
    camera.rotation.x += -.16 * ease(seg(a, 0, .6)) * (1 - ease(seg(a, .6, 1.1))) - .1 * bump(a, R.end - .4, R.end);
    camera.position.y -= .2 * ease(seg(a, 0, .6)) * (1 - ease(seg(a, R.end - .6, R.end - .1)));
    camera.fov = 66 - 6 * ease(seg(a, R.aim, R.thrust)) * (1 - ease(seg(a, R.thrust, R.tip))) + 10 * bump(a, R.thrust, R.strikeEnd);
    vign = Math.max(vign, .6 * ease(seg(a, 0, .6)) * (1 - ease(seg(a, R.end - .8, R.end - .1))));
    red = Math.max(red, .35 * ease(seg(a, .1, .6)) * (1 - ease(seg(a, 1, 1.4))) + .25 * bump(a, R.aim, R.strikeEnd));
    glow = Math.max(glow, 1 - ease(seg(a, R.end - .6, R.end - .1)));
    eyeFlash = Math.max(eyeFlash, .45 * bump(a, .3, .75));
    vortex = c.target && c.flags.tip ? ease(seg(a, R.strikeEnd, R.seal)) * (1 - ease(seg(a, R.sealEnd - .1, R.sealEnd + .3))) : 0;
  }
  function firstWall(from, dir, max) { for (let s = .3; s <= max; s += .25) { if (inObstacle(from.clone().addScaledVector(dir, s), 0)) return s; } return max; }
  function vortexRings(c, t) {
    for (let i = 0; i < 7; i++) {
      const m = new T.Mesh(new T.TorusGeometry(1, .05, 6, 40), new T.MeshBasicMaterial({ color: i % 2 ? 0xff2a1a : GOLD, transparent: true, depthWrite: false, opacity: .9 }));
      fx(m, 1.25, (o, u) => { const p = t.g.position.clone().setY(t.g.position.y + 1.2 * t.g.scale.x); o.position.copy(p).add(V(0, Math.sin(u * 10 + i) * .3, 0)); o.rotation.set(Math.PI / 2 + Math.sin(u * 6 + i) * .6, u * 12 + i, 0); const r = (1.6 - u * 1.4) * (.7 + i * .08); o.scale.setScalar(Math.max(.05, r)); o.material.opacity = .9 * Math.sin(u * Math.PI); });
    }
  }
  function endSusanoo(c) {
    const t = c.target;
    if (t && t.hp > 0 && c.flags.gone) {
      // Out of the seal: back on safe ground where it was struck, staggered for what is left of the 1.8 s.
      const left = Math.max(.2, CFG.r.seal + CFG.r.sealFor - (A.time - c.start));
      const p = safeGround(c.home || t.home, c.dir); binds.set(t, { until: A.time + left, kind: 'sealed' });
      t.g.position.copy(p); t.g.scale.setScalar(1); t.g.rotation.set(0, 0, 0); t.g.visible = false;
      A.later(Math.min(left, .05), () => { if (t.hp <= 0) return; t.g.visible = true; t.g.rotation.x = .25; for (let i = 0; i < 12; i++) { const e = sprite(glowTex, 0xff3020, 1, true); e.position.copy(p).setY(rnd(.2, 2.4)); e.scale.setScalar(rnd(.12, .3)); fx(e, .6, (o, u) => { o.material.opacity = 1 - u; }); } });
      A.later(left, () => { releaseBind(t); });
    } else if (t) { releaseBind(t); t.g.scale.setScalar(1); if (t.hp > 0) t.g.visible = true; }
    disposeSusanoo();
  }
  function disposeSusanoo() { if (!su) return; kill(su.g); kill(su.blade); for (const b of su.blobs) kill(b.b); su = null; }

  // ---------- views ----------
  function victimView(c) {
    if (viewMode === 'caster') return false;
    if (!c?.itachi) return false;
    const a = A.time - c.start;
    if (c.type === 'tsukuyomi') return !c.fail && c.target && a >= CFG.q.eye - .05 && a < CFG.q.end && (viewMode === 'victim' || viewMode === 'auto');
    if (c.type === 'susanoo') return !!c.target && c.flags.tip && a >= CFG.r.tip && a < CFG.r.sealEnd + .1 && (viewMode === 'victim' || (viewMode === 'auto' && a >= CFG.r.strikeEnd + .15 && a < CFG.r.sealEnd - .2));
    return false;
  }
  const _q2 = new T.Quaternion(), _m2 = new T.Matrix4();
  function placeCamera(pos, look, w = 1, roll = 0) {
    // Pull the shot in front of any pillar between the caster and the camera.
    // If a pillar or the arena edge is in the way, swing the shot around the caster to the clearest angle.
    const me = basePos.clone(), off = pos.clone().sub(me), len = off.length();
    const clear = d => { for (let s = .3; s <= len; s += .2) { const p = me.clone().addScaledVector(d, s); if (inObstacle(p, .3) || Math.hypot(p.x, p.z) > A.arenaR - .4 || p.y < .3) return Math.max(.6, s - .4); } return len; };
    let best = null, ok = -1;
    for (const ang of [0, .45, -.45, .9, -.9, 1.4, -1.4, 2, -2]) { const d = off.clone().applyAxisAngle(UP, ang).normalize(), r = clear(d); if (r > ok + .01) { ok = r; best = d; } if (r >= len * .85) break; }
    const at = me.clone().addScaledVector(best, ok);
    _m2.lookAt(at, look, UP); _q2.setFromRotationMatrix(_m2);
    camera.position.lerp(at, w); camera.quaternion.slerp(_q2, w); if (roll) camera.rotateZ(roll);
  }

  // ---------- app hooks ----------
  function begin(c) {
    c.itachi = true; c.flags = c.flags || {};
    if (passive) { passive = null; arms.r.k = arms.l.k = 1; }
    if (c.type === 'tsukuyomi') beginTsukuyomi(c);
    if (c.type === 'amaterasu') beginAmaterasu(c);
    if (c.type === 'susanoo') beginSusanoo(c);
  }
  function update(c, a, dt) {
    c.age = a;
    if (c.type === 'tsukuyomi') updateTsukuyomi(c, a, dt);
    else if (c.type === 'amaterasu') updateAmaterasu(c, a, dt);
    else if (c.type === 'susanoo') updateSusanoo(c, a, dt);
  }
  function end(c) {
    if (c.type === 'tsukuyomi') endTsukuyomi(c);
    if (c.type === 'susanoo') endSusanoo(c);
    lid = 0;
  }
  function frame(dt, moving) {
    const c = A.cast, now = A.time;
    if (!active) { arms.r.g.visible = arms.l.g.visible = arms.r.up.visible = arms.l.up.visible = false; body.visible = false; for (const t of extras) t.g.visible = false; return; }
    // Patrol dummy: walks back and forth across the field; fire slows it, a bind stops it.
    {
      const w = walker, P = w.patrol;
      if (alive(w) && !w.locked && !w.vel) {
        const bound = (binds.get(w)?.until || 0) > now, slow = (w.itBurnUntil || 0) > now ? CFG.e.slow : 1;
        P.u += P.dir * dt * (bound ? 0 : .11 * slow); if (P.u > 1) { P.u = 1; P.dir = -1; } if (P.u < 0) { P.u = 0; P.dir = 1; }
        w.g.position.lerpVectors(P.a, P.b, P.u); w.g.userData.cannonUntil = Infinity; w.g.rotation.y = P.dir > 0 ? -Math.PI / 2 : Math.PI / 2;
        const [la, ra] = limbs(w), sw = Math.sin(now * 6) * .4 * slow; la.rotation.x = sw; ra.rotation.x = -sw;
      }
    }
    if (passive) updateCrow(dt);
    updateAttacker(dt);
    for (let i = fields.length - 1; i >= 0; i--) if (!updateField(fields[i], dt)) fields.splice(i, 1);
    if (!fields.length) stopBurn();
    for (const [t, b] of [...binds]) if (t.hp <= 0) { binds.delete(t); calm(t); t.locked = false; t.g.scale.setScalar(1); }
    // Idle and running arms: calm, hands low, a light step; basic attacks are quick knife-hand jabs.
    if (!c?.itachi) {
      const m = A.melee, sw = moving ? Math.sin(now * 11) : 0, idle = Math.sin(now * 1.5) * .006;
      const Rp = { ...REST, pos: REST.pos.clone().add(V(0, idle + .02 * sw - (moving ? .03 : 0), -.05 * sw)) };
      const Lp = { ...L_REST, pos: L_REST.pos.clone().add(V(0, idle - .02 * sw - (moving ? .03 : 0), .05 * sw)) };
      if (m) {
        const a = now - m.start, wind = ease(a / m.windup), strike = outP((a - m.windup) / m.swing, 3), back = ease((a - m.windup - m.swing) / Math.max(.05, m.duration - m.windup - m.swing));
        const right = m.combo % 2 === 1, rest = right ? Rp : Lp, K = right ? KNIFE : mirror(KNIFE);
        const cock = { ...rest, pos: rest.pos.clone().add(V(0, .06, .12)) };
        const P = lerpPose(lerpPose(lerpPose(rest, cock, wind), K, strike), rest, back);
        if (right) { poseArm(arms.r, P); poseArm(arms.l, Lp); } else { poseArm(arms.l, P); poseArm(arms.r, Rp); }
      } else if (passive) { poseArm(arms.r, Rp); poseArm(arms.l, Lp); }
      else { const seal = ease(seg(now - (sealAt || -9), 0, .2)) * (1 - ease(seg(now - (sealAt || -9), .5, .8))); poseArm(arms.r, lerpPose(Rp, SEAL, seal)); poseArm(arms.l, lerpPose(Lp, L_SEAL, seal)); }
      if (moving) { camera.position.y -= .03; camera.rotation.z += sw * .004; }
    }
    // Camera: cinematic shots and victim views replace first person; the body shows whenever we are outside it.
    const vic = victimView(c);
    fp = true; label = '';
    if (vic) {
      const t = c.target, eye = t.g.position.clone().setY(t.g.position.y + 2.3 * Math.max(.3, t.g.scale.x)), look = c.type === 'susanoo' && su ? su.head.getWorldPosition(V()).lerp(basePos, .35) : basePos.clone().setY(1.7);
      eye.addScaledVector(look.clone().sub(eye).normalize(), .75 * Math.max(.3, t.g.scale.x));   // just in front of the victim's own head
      camera.position.copy(eye); camera.lookAt(look); camera.fov = c.type === 'susanoo' ? 78 : 58; fp = false; label = '피격자 시점 · ' + (c.type === 'tsukuyomi' ? '츠쿠요미 환술 세계' : '토츠카의 검 봉인');
      if (c.type === 'tsukuyomi') { const a = now - c.start; camera.rotateZ(Math.sin(now * 2) * .03 * c.world); camera.fov = 58 - 10 * ease(seg(a, CFG.q.eye, CFG.q.world)) + 6 * bump(a, 1.3, 1.5); }
    } else if (passive && viewMode !== 'caster' && passive.attacker && attacker.lunge) {
      // Attacker's eyes: the body in front breaks into crows and reforms twelve studs back.
      const eye = attacker.g.position.clone().setY(2.3); eye.addScaledVector(passive.from.clone().sub(eye).setY(0).normalize(), .75); camera.position.copy(eye); camera.lookAt(passive.from.clone().lerp(passive.to, ease(seg(now - passive.start, .25, .6))).setY(1.4)); camera.fov = 70; fp = false; label = '공격자 시점 · 까마귀 분신';
    } else if (c?.itachi && c.type === 'susanoo' && c.cine > .01) {
      placeCamera(c.shotPos, c.shotLook, c.cine); if (c.cine > .5) fp = false; camera.fov = mix(camera.fov, 62, c.cine);
    }
    // Body: hidden in first person; dissolves into crows and rebuilds feet first in the crow clone.
    let rise = 1, bodyVis = !fp || (c?.itachi && c.type === 'susanoo' && c.cine > .3);
    if (passive) { const a = now - passive.start; rise = a < .12 ? 1 : a < .45 ? 0 : seg(a, .45, .65); }
    const reach = c?.itachi && c.type === 'tsukuyomi' ? bump(now - c.start, 1.1, 1.75) : 0;
    poseBody(reach, c?.itachi && c.type === 'susanoo' ? ease(seg(now - c.start, 0, .6)) * (1 - ease(seg(now - c.start, 1, 1.4))) : 0, rise);
    body.visible = !!(bodyVis && rise > .01);
    for (const e of eyes) { e.material.color.setScalar(.6 + .4 * glow); e.scale.setScalar(.045 + .03 * glow); }
    if (!fp) { arms.r.g.visible = arms.l.g.visible = arms.r.up.visible = arms.l.up.visible = false; }
    if (moon) { /* visibility handled in Tsukuyomi */ }
    // Shake.
    if (shakeAmp > .001) { camera.position.x += rnd() * shakeAmp; camera.position.y += rnd() * shakeAmp; shakeAmp *= Math.exp(-10 * dt); }
    // Screen layers.
    const world = vic && c.type === 'tsukuyomi' ? c.world : 0;
    if (world > .01) { $('scene').style.filter = `grayscale(${world.toFixed(2)}) sepia(${(world * .3).toFixed(2)}) hue-rotate(${(-50 * world).toFixed(0)}deg) saturate(${(1 + world * 3).toFixed(2)}) brightness(${(1 - .5 * world).toFixed(2)}) contrast(${(1 + .6 * world).toFixed(2)})`; filterOn = true; }
    else if (filterOn) { filterOn = false; $('scene').style.filter = ''; }
    ovV.style.opacity = Math.min(1, vign).toFixed(3); vign *= Math.exp(-4 * dt);
    ovR.style.opacity = Math.min(1, red).toFixed(3); red = Math.max(0, red - dt * 1.8);
    ovW.style.opacity = (vic && c.type === 'susanoo' ? Math.max(vortex, .35) : vortex * .5).toFixed(3); ovW.style.transform = `rotate(${(now * 140) % 360}deg) scale(${1.15 - .15 * vortex})`;
    lidT.style.transform = `translateY(${(-100 + lid * 100).toFixed(1)}%)`; lidB.style.transform = `translateY(${(100 - lid * 100).toFixed(1)}%)`;
    ovS.style.opacity = Math.min(1, eyeFlash).toFixed(3); ovS.style.transform = `translate(-50%,-50%) rotate(${(now * 420) % 360}deg) scale(${(1.25 - .25 * eyeFlash).toFixed(3)})`; eyeFlash = Math.max(0, eyeFlash - dt * 1.6);
    ovC.style.opacity = (vic ? crack : 0).toFixed(3);
    ovL.textContent = label; ovL.style.opacity = label ? 1 : 0;
    ovT.textContent = now < talkUntil ? talk : ''; ovT.style.opacity = now < talkUntil ? Math.min(1, (talkUntil - now) * 3) : 0;
    glow = Math.max(0, glow - dt * .8);
    // Effects.
    for (let i = fxs.length - 1; i >= 0; i--) { const e = fxs[i], u = (now - e.born) / e.life; if (u >= 1) { fxs.splice(i, 1); e.done?.(); kill(e.obj); } else e.update?.(e.obj, u, dt); }
  }
  let sealAt = -9;
  function speed() {
    const c = A.cast, now = A.time;
    if (passive) return 0;
    if (c?.itachi) { const a = now - c.start; if (c.type === 'susanoo') return 0; if (c.type === 'tsukuyomi') return a < CFG.q.eye ? .35 : .6; if (c.type === 'amaterasu') return .5; }
    return now < playerSlowUntil ? .7 : 1.08;
  }
  function hud() {
    const now = A.time, c = A.cast;
    const crowLeft = Math.max(0, crowReady - now);
    $('qBtn').querySelector('.skill-type').textContent = c?.type === 'tsukuyomi' ? (c.fail ? '대상 없음' : c.flags.bind ? '환술 · 구속 ' + Math.max(0, CFG.q.end - (now - c.start)).toFixed(1) + '초' : '사륜안 활성화') : '35스터드 · 12° · 12 + 구속 1.4초';
    const F = fields[fields.length - 1];
    $('eBtn').querySelector('.skill-type').textContent = F ? '흑염 ' + Math.max(0, CFG.e.gone - (now - F.start)).toFixed(1) + '초 남음' : '바라본 지면 · 반경 20 흑염';
    $('rBtn').querySelector('.skill-type').textContent = c?.type === 'susanoo' ? ({ Casting: '만화경 사륜안', SusanooForming: '스사노오 형성', Shielding: '야타의 거울', Smashing: '전방 3연타', BladeCharging: '토츠카의 검', Striking: '찌르기', Sealing: '봉인', Recovering: c.missed ? '빗나감 · 소멸' : '소멸' }[c.state] || '') : '전방 3연타 → 토츠카 봉인 · 103';
    $('qBtn').classList.toggle('combo', !!F && !c);
    const d = $('debuff'); d.classList.add('on');
    d.textContent = passive ? '까마귀 분신 · 공격 무효 · 후방 이동'
      : c?.type === 'susanoo' ? '스사노오 · 강한 경직 저항' + (c.age >= CFG.r.mirror && c.age < CFG.r.sealEnd ? ' · 야타의 거울 전방 피해 60% 감소' : '')
      : '패시브 까마귀 분신 ' + (crowLeft > 0 ? '재사용 ' + crowLeft.toFixed(1) + '초' : '준비 · 피격 시 ' + (forcePassive ? '100% (테스트)' : '20%')) + (F ? ' · 흑염 ' + Math.max(0, CFG.e.gone - (now - F.start)).toFixed(1) + '초' : '');
  }
  function killTarget() {
    const c = A.cast; const t = c?.target && c.target.hp > 0 ? c.target : targets.find(o => alive(o) && o !== attacker);
    if (!t) return; A.hit(t, 9999, '#ffffff'); A.toast('대상 처치 · 걸려 있던 환술·봉인·화염 상태를 정리했습니다');
  }
  function casterDies() {
    const c = A.cast;
    if (c?.itachi) { c.duration = 0; c.killed = true; }
    passive = null; arms.r.k = arms.l.k = 1;
    for (const [t] of [...binds]) { releaseBind(t); t.g.scale.setScalar(1); if (t.hp > 0) t.g.visible = true; }
    clearWorld(); disposeSusanoo(); for (const F of fields.splice(0)) { kill(F.core); kill(F.halo); kill(F.scorch); kill(F.glowDisc); kill(F.sheets); } stopBurn();
    A.toast('시전자 사망 테스트 · 스킬·구속·화염을 모두 해제하고 체력을 되돌렸습니다'); A.flash('#000000', .5); A.hp = 200;
  }
  function reset() {
    for (const e of fxs.splice(0)) kill(e.obj); crows.length = 0;
    clearWorld(); disposeSusanoo();
    for (const F of fields.splice(0)) { kill(F.core); kill(F.halo); kill(F.scorch); kill(F.glowDisc); kill(F.sheets); }
    for (const o of [...live]) kill(o);
    stopBurn();
    for (const [t] of binds) { t.locked = false; t.g.userData.cannonUntil = 0; } binds.clear();
    for (const t of [...targets, ...extras]) { calm(t); delete t.itBurnUntil; }
    passive = null; crowReady = 0; arms.r.k = arms.l.k = 1; attacker.lunge = null; attacker.g.visible = false; attacker.locked = false;
    walker.patrol.u = 0; walker.patrol.dir = 1;
    vign = red = vortex = lid = eyeFlash = crack = shakeAmp = glow = 0; label = ''; talkUntil = 0;
    if (filterOn) { filterOn = false; $('scene').style.filter = ''; }
    body.visible = false; fp = true;
    for (const el of [ovV, ovR, ovW, ovS, ovC, ovL, ovT]) el.style.opacity = 0;
  }
  function activate(on) {
    active = on; document.body.classList.toggle('itachi', on); panel.hidden = !on; refreshPanel();
    for (const t of extras) {
      const i = targets.indexOf(t);
      if (t === walker) { if (on && i < 0) targets.push(t); if (!on && i >= 0) targets.splice(i, 1); }
      t.hp = t.max; t.g.position.copy(t === walker ? walker.patrol.a.clone().lerp(walker.patrol.b, .1) : t.home); t.bar.scale.x = 1; t.bar.position.x = 0; t.locked = false; t.respawn = 0; t.vel = null; calm(t);
      t.g.visible = on && t === walker;
    }
    if (!on) { arms.r.g.visible = arms.l.g.visible = arms.r.up.visible = arms.l.up.visible = false; body.visible = false; $('debuff').textContent = ''; $('debuff').classList.remove('on'); if (filterOn) { filterOn = false; $('scene').style.filter = ''; } }
  }
  function state() {
    const c = A.cast;
    return { active, view: viewMode, force: forcePassive, crowReady: +Math.max(0, crowReady - A.time).toFixed(2), passive: passive ? +(A.time - passive.start).toFixed(2) : null, hp: A.hp,
      cast: c?.itachi ? { type: c.type, age: +(A.time - c.start).toFixed(2), state: c.state || null, target: c.target?.index ?? null, fail: !!c.fail, missed: !!c.missed, cine: +(c.cine || 0).toFixed(2), victim: victimView(c) } : null,
      fields: fields.map(F => ({ age: +(A.time - F.start).toFixed(2), flames: F.list.length, hits: [...F.hits].map(([t, h]) => t.index + ':' + (1 + h.ticks) + (h.inside ? '*' : '')) })),
      binds: [...binds].map(([t, b]) => t.index + ':' + b.kind), pos: basePos.toArray().map(v => +v.toFixed(2)), fx: fxs.length, live: live.size,
      targets: targets.map(t => ({ i: t.index, hp: t.hp, pos: t.g.position.toArray().map(v => +v.toFixed(1)), vis: t.g.visible, s: +t.g.scale.x.toFixed(2) })) };
  }
  // Hand seal flourish after a cast ends (a small touch of the ninja's restraint).
  function seal() { sealAt = A.time; }
  return { begin, update, end, frame, speed, hud, reset, activate, state, enemyAttack, incomingHit, seal, setView: m => { viewMode = m; refreshPanel(); }, setForce: on => { forcePassive = on; refreshPanel(); }, skills: new Set(['tsukuyomi', 'amaterasu', 'susanoo']) };
};

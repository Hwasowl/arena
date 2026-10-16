// Tendo Pain for the browser preview. Timings match roblox/src/ReplicatedStorage/PainAbilityConfig.luau; distances
// are Roblox studs times S (the preview body is about 0.6 of a Roblox character). Loaded as a classic script before
// app.js, which calls window.PainPreview(api) once its scene, targets and helpers exist.
window.PainPreview = function (A) {
  'use strict';
  const T = A.T, scene = A.scene, camera = A.camera, targets = A.targets, basePos = A.basePos;
  const $ = id => document.getElementById(id);
  const clamp = T.MathUtils.clamp, mix = T.MathUtils.lerp;
  const ease = x => { x = clamp(x, 0, 1); return x * x * (3 - 2 * x); };
  const out = x => 1 - Math.pow(1 - clamp(x, 0, 1), 3);
  const seg = (a, from, to) => clamp((a - from) / (to - from), 0, 1);
  const rnd = (a = -1, b = 1) => a + Math.random() * (b - a);
  const V = (x = 0, y = 0, z = 0) => new T.Vector3(x, y, z);
  const S = 0.6;
  const CFG = {
    shinra: { windup: .45, wave: .25, radius: 25 * S, damage: 30, knockMin: 18 * S, knockMax: 35 * S, liftMin: 3 * S, liftMax: 7 * S,
      flight: .6, wallDamage: 5, castSpeed: .25, recovery: .7, slow: 1.5, slowFactor: .75 },
    bansho: { missCd: 1.5, range: 55 * S, angle: 12, windup: .35, pullMax: .8, pullMin: .38, stop: 4 * S, lift: 1.6 * S,
      strikeDelay: .14, damage: 25, knock: 6 * S, knockTime: .2, stun: .5, missRecovery: .35, recovery: .4 },
    chibaku: { duration: 6.5, gather: .8, launch: 1.5, forward: 20 * S, height: 45 * S, radius: 45 * S, field: 1.5, lift: 2,
      debris: 2.5, formed: 4.5, compressEnd: 5.5, burst: 5.6, captureMax: 4, ticks: [2.5, 3.5], tick: 10, final: 55,
      sphere: 13 * S, seal: 5.5 * S, castSpeed: .4, slow: 1, slowFactor: .6, down: .8, rocks: 64, crater: 7 },
  };
  const COMBO_WINDOW = 2.5;
  const PURPLE = 0xb084ff;

  // ---------- shared assets ----------
  function canvasTex(size, draw) {
    const c = document.createElement('canvas'); c.width = c.height = size; draw(c.getContext('2d'), size);
    const t = new T.CanvasTexture(c); t.colorSpace = T.SRGBColorSpace; return t;
  }
  const rinTex = canvasTex(256, (g, s) => {
    g.translate(s / 2, s / 2);
    for (let i = 5; i >= 0; i--) { g.beginPath(); g.arc(0, 0, 18 + i * 20, 0, Math.PI * 2); g.lineWidth = i % 2 ? 4 : 8; g.strokeStyle = i % 2 ? 'rgba(96,58,180,.95)' : 'rgba(214,190,255,.95)'; g.stroke(); }
    g.beginPath(); g.arc(0, 0, 10, 0, Math.PI * 2); g.fillStyle = '#1b0b33'; g.fill();
  });
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
  function seeded(seed) { return () => { seed |= 0; seed = seed + 0x6D2B79F5 | 0; let t = Math.imul(seed ^ seed >>> 15, 1 | seed); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
  // Irregular rocks: an icosphere whose shared corners are pushed in or out by the same amount, so faces stay closed.
  function rockGeo(seed, detail = 1) {
    const g = new T.IcosahedronGeometry(1, detail), p = g.attributes.position, r = seeded(seed), cache = new Map();
    for (let i = 0; i < p.count; i++) {
      const k = Math.round(p.getX(i) * 997) + ',' + Math.round(p.getY(i) * 997) + ',' + Math.round(p.getZ(i) * 997);
      if (!cache.has(k)) cache.set(k, .7 + r() * .5);
      const s = cache.get(k); p.setXYZ(i, p.getX(i) * s, p.getY(i) * s * .8, p.getZ(i) * s);
    }
    g.computeVertexNormals(); return g;
  }
  const ROCKS = Array.from({ length: 7 }, (_, i) => rockGeo(11 + i * 7));
  const rockMat = c => new T.MeshStandardMaterial({ color: c, roughness: .95, metalness: 0, flatShading: true });
  const groundRock = [0x857b70, 0x9a9083, 0x6e665d].map(rockMat);
  const sealRock = [0x7d7369, 0x91877b, 0x645d55].map(rockMat);   // their own set: they glow purple while compressing
  const SHARED = new Set([...ROCKS, ...groundRock, ...sealRock]);

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
  function rock(size, mats = groundRock) { const m = new T.Mesh(ROCKS[Math.floor(Math.random() * ROCKS.length)], mats[Math.floor(Math.random() * mats.length)]); m.scale.setScalar(size); m.rotation.set(rnd(0, 6), rnd(0, 6), rnd(0, 6)); m.castShadow = true; return m; }
  // A rock thrown with gravity: bounces once or twice on the floor, then shrinks away.
  function throwRock(pos, vel, size, life = 1.8, mesh = null) {
    const m = mesh || rock(size); if (!m.parent) scene.add(m); m.position.copy(pos);
    const v = vel.clone(), spin = V(rnd(), rnd(), rnd()).multiplyScalar(9), floor = size * .55;
    let rest = false;
    return fx(m, life, (o, u, dt) => {
      if (!rest) {
        v.y -= 24 * dt; o.position.addScaledVector(v, dt); o.rotation.x += spin.x * dt; o.rotation.y += spin.y * dt; o.rotation.z += spin.z * dt;
        if (o.position.y < floor) { o.position.y = floor; if (v.y < -4) { v.y *= -.32; v.x *= .55; v.z *= .55; spin.multiplyScalar(.5); } else rest = true; }
      }
      if (u > .7) o.scale.setScalar(size * (1 - (u - .7) / .3));
    });
  }
  function dust(pos, size, life, vel = null, color = 0xe2dbd0, opacity = .75) {
    const s = sprite(dustTex, color, opacity); s.position.copy(pos); s.scale.setScalar(size * .5);
    const v = vel ? vel.clone() : V(0, .4, 0);
    return fx(s, life, (o, u, dt) => { o.position.addScaledVector(v, dt); v.multiplyScalar(Math.pow(.2, dt)); o.scale.setScalar(size * (.5 + u * 1.1)); o.material.opacity = opacity * (1 - u) * Math.min(1, .25 + u * 8); });
  }
  function glowAt(pos, color, size, life, grow = 2, opacity = 1) {
    const s = sprite(glowTex, color, opacity, true); s.position.copy(pos); s.scale.setScalar(size);
    return fx(s, life, (o, u) => { o.scale.setScalar(size * (1 + u * grow)); o.material.opacity = opacity * (1 - u); });
  }
  function floorRing(center, radius, color, life, thickness = .1, opacity = .85, from = .4) {
    const m = new T.Mesh(new T.TorusGeometry(1, thickness, 6, 96), new T.MeshBasicMaterial({ color, transparent: true, opacity, depthWrite: false }));
    m.rotation.x = Math.PI / 2; m.position.copy(center);
    return fx(m, life, (o, u) => { const r = mix(from, radius, out(u * 1.4)); o.scale.set(r, r, 1 + u * 2); o.material.opacity = opacity * (1 - u); });
  }

  // ---------- sound: synthesised with WebAudio, follows the preview's sound toggle ----------
  let master = null, noiseBuffer = null; const loops = new Map();
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
  let lastClack = 0;
  const sfx = {
    resonance() { tone({ f0: 55, f1: 49, dur: .7, vol: .55, attack: .25 }); tone({ f0: 110, f1: 98, dur: .6, vol: .18, attack: .3 }); tone({ type: 'triangle', f0: 330, f1: 290, dur: .5, vol: .04, attack: .3 }); noise({ f0: 300, f1: 120, dur: .5, vol: .06, attack: .3 }); },
    boom() { noise({ f0: 1400, f1: 90, dur: .9, vol: .85 }); tone({ f0: 95, f1: 36, dur: .7, vol: .9 }); tone({ type: 'triangle', f0: 220, f1: 80, dur: .25, vol: .25 }); noise({ filter: 'highpass', f0: 3000, dur: .12, vol: .12 }); },
    thud() { tone({ f0: 130, f1: 48, dur: .22, vol: .6 }); noise({ f0: 700, f1: 200, dur: .2, vol: .4 }); noise({ filter: 'bandpass', f0: 2600, dur: .16, vol: .18, q: 2, at: .01 }); },
    suck() { noise({ filter: 'bandpass', f0: 2600, f1: 260, dur: .5, vol: .35, q: 1.4, attack: .2 }); tone({ type: 'sawtooth', f0: 60, f1: 140, dur: .45, vol: .06, attack: .2 }); },
    pull() { noise({ filter: 'bandpass', f0: 400, f1: 1600, dur: .6, vol: .3, q: 1, attack: .05 }); },
    stab() { noise({ filter: 'highpass', f0: 2800, dur: .07, vol: .3 }); tone({ type: 'square', f0: 190, f1: 55, dur: .12, vol: .12 }); tone({ f0: 70, f1: 40, dur: .3, vol: .7 }); noise({ f0: 600, f1: 150, dur: .2, vol: .35 }); },
    fail() { noise({ filter: 'bandpass', f0: 900, f1: 500, dur: .2, vol: .15, q: 1 }); },
    heartbeat() { for (const at of [0, .26]) { tone({ f0: 52, f1: 38, dur: .2, vol: .7, at }); noise({ f0: 160, dur: .12, vol: .2, at }); } },
    launch() { tone({ f0: 40, f1: 160, dur: .7, vol: .35, attack: .05 }); noise({ filter: 'bandpass', f0: 300, f1: 2400, dur: .7, vol: .25, q: .7 }); },
    gravity() { tone({ f0: 70, f1: 30, dur: 1.1, vol: .8, attack: .02 }); noise({ f0: 400, f1: 60, dur: 1, vol: .5 }); },
    clack() { const t = performance.now(); if (t - lastClack < 45) return; lastClack = t; noise({ filter: 'bandpass', f0: rnd(900, 1800), dur: .06, vol: .22, q: 3 }); tone({ type: 'triangle', f0: rnd(140, 260), f1: 80, dur: .07, vol: .1 }); },
    crack() { noise({ filter: 'highpass', f0: rnd(1500, 2600), dur: .18, vol: .2 }); noise({ f0: 500, f1: 120, dur: .3, vol: .2 }); },
    explosion() { noise({ f0: 2400, f1: 70, dur: 2.2, vol: 1 }); tone({ f0: 75, f1: 24, dur: 1.8, vol: 1 }); noise({ filter: 'highpass', f0: 2500, dur: .3, vol: .3 }); for (let i = 0; i < 6; i++) noise({ filter: 'bandpass', f0: rnd(500, 1500), dur: .1, vol: .2, q: 2, at: .3 + i * .12 }); },
  };
  function startDrone() {
    const c = ac(); if (!c || loops.has('drone')) return; const t = c.currentTime;
    const g = c.createGain(), f = c.createBiquadFilter(), o1 = c.createOscillator(), o2 = c.createOscillator(), lfo = c.createOscillator(), lg = c.createGain();
    g.gain.setValueAtTime(.0001, t); g.gain.exponentialRampToValueAtTime(.32, t + .8); f.type = 'lowpass'; f.frequency.value = 200;
    o1.type = 'sawtooth'; o1.frequency.value = 41; o2.frequency.value = 61.5; lfo.frequency.value = 3.1; lg.gain.value = 70;
    lfo.connect(lg).connect(f.frequency); o1.connect(f); o2.connect(f); f.connect(g).connect(master); for (const o of [o1, o2, lfo]) o.start();
    loops.set('drone', { c, g, o: [o1, o2, lfo] });
  }
  function bendDrone(k) { const l = loops.get('drone'); if (!l) return; const t = l.c.currentTime; l.o[0].frequency.setTargetAtTime(41 + 40 * k, t, .1); l.o[2].frequency.setTargetAtTime(3.1 + 12 * k, t, .1); }
  function stopLoops(fade = .25) {
    for (const [name, l] of loops) {
      loops.delete(name); const t = l.c.currentTime;
      try { l.g.gain.cancelScheduledValues(t); l.g.gain.setValueAtTime(Math.max(.0001, l.g.gain.value), t); l.g.gain.exponentialRampToValueAtTime(.0001, t + fade); for (const o of l.o) o.stop(t + fade + .05); } catch (e) { /* already stopped */ }
    }
  }

  // ---------- screen overlay: Rinnegan rings, vignette, flash ----------
  const overlay = document.createElement('div'); overlay.id = 'painOverlay';
  overlay.innerHTML = '<i class="pv"></i><i class="pr"></i><i class="pf"></i>'; document.body.append(overlay);
  const [ovV, ovR, ovF] = overlay.children;

  // ---------- first-person arms: Akatsuki sleeve with red clouds, fingers with black nails ----------
  const armMat = (color, roughness = .7, extra = {}) => new T.MeshStandardMaterial({ color, roughness, metalness: 0, ...extra });
  const mSkin = armMat(0xe9c6b0, .6), mSleeve = armMat(0x111116, .88), mLining = armMat(0xa3121f, .75), mCloud = armMat(0xcf1f2c, .55), mRim = armMat(0xf4f1ea, .6), mNail = armMat(0x0b0b12, .22, { metalness: .25 });
  const mRod = armMat(0x0c0b10, .3, { metalness: .65, emissive: 0x2a1450, emissiveIntensity: 0 });
  function part(geo, material, parent, pos, rot) {
    const m = new T.Mesh(geo, material); parent.add(m); if (pos) m.position.set(...pos); if (rot) m.rotation.set(...rot);
    m.renderOrder = 102; m.frustumCulled = false; return m;
  }
  function cloud(parent, pos, rotY, scale) {
    const c = new T.Group(); parent.add(c); c.position.set(...pos); c.rotation.y = rotY; c.scale.setScalar(scale);
    const puffs = [[-.032, 0, .022], [-.008, .014, .026], [.02, .006, .024], [.04, -.006, .018], [.004, -.012, .02]];
    for (const [x, y, r] of puffs) {
      const red = part(new T.SphereGeometry(r, 10, 8), mCloud, c, [x, y, .004]); red.scale.z = .3;
      const rim = part(new T.SphereGeometry(r * 1.22, 10, 8), mRim, c, [x, y, 0]); rim.scale.z = .25;
    }
    return c;
  }
  function makeArm(side) {
    const g = new T.Group(); camera.add(g); g.visible = false;
    part(new T.CylinderGeometry(.09, .125, .78, 16), mSleeve, g, [0, -.47, -.004]);
    part(new T.CylinderGeometry(.086, .09, .05, 16), mSleeve, g, [0, -.065, 0]);
    part(new T.TorusGeometry(.083, .009, 6, 24), mLining, g, [0, -.088, 0], [Math.PI / 2, 0, 0]);
    part(new T.CylinderGeometry(.052, .06, .14, 10), mSkin, g, [0, -.03, 0]);
    cloud(g, [0, -.3, .1], 0, 1);
    cloud(g, [-side * .108, -.56, 0], -side * Math.PI / 2, 1.15);
    const palm = part(new T.BoxGeometry(.155, .165, .056), mSkin, g, [0, .08, 0]);
    part(new T.BoxGeometry(.14, .05, .02), mSkin, g, [0, .14, .03]);     // knuckle ridge on the back of the hand
    const fingers = [];
    const xs = [.058, .019, -.02, -.057], lens = [[.066, .05], [.074, .054], [.069, .05], [.054, .04]];
    for (let i = 0; i < 4; i++) {
      const j1 = new T.Group(); g.add(j1); j1.position.set(-side * xs[i], .16, 0);
      part(new T.BoxGeometry(.034, lens[i][0], .036), mSkin, j1, [0, lens[i][0] / 2, 0]);
      const j2 = new T.Group(); j1.add(j2); j2.position.y = lens[i][0];
      part(new T.BoxGeometry(.03, lens[i][1], .032), mSkin, j2, [0, lens[i][1] / 2, 0]);
      part(new T.BoxGeometry(.026, .024, .008), mNail, j2, [0, lens[i][1] - .013, .017]);
      fingers.push({ j1, j2 });
    }
    const thumb = new T.Group(); g.add(thumb); thumb.position.set(-side * .07, .035, -.012);
    part(new T.BoxGeometry(.036, .056, .036), mSkin, thumb, [0, .028, 0]);
    const t2 = new T.Group(); thumb.add(t2); t2.position.y = .056;
    part(new T.BoxGeometry(.032, .046, .032), mSkin, t2, [0, .023, 0]);
    part(new T.BoxGeometry(.028, .022, .008), mNail, t2, [0, .034, .017]);
    // Chakra receiver for the left hand: a ridged black rod that grows forward out of the fist (hand -X is forward).
    let rod = null;
    if (side < 0) {
      rod = new T.Group(); g.add(rod); rod.position.set(0, .12, -.05); rod.visible = false;
      const len = 1.5;
      part(new T.CylinderGeometry(.012, .015, len, 8), mRod, rod, [-len / 2 + .1, 0, 0], [0, 0, Math.PI / 2]);
      for (let k = 0; k < 7; k++) part(new T.TorusGeometry(.017, .005, 5, 12), mRod, rod, [.06 - k * .2, 0, 0], [0, Math.PI / 2, 0]);
      part(new T.ConeGeometry(.014, .12, 8), mRod, rod, [-len + .04, 0, 0], [0, 0, Math.PI / 2]);
      part(new T.SphereGeometry(.022, 8, 6), mRod, rod, [.12, 0, 0]);
    }
    g.traverse(o => { o.castShadow = false; o.receiveShadow = false; });
    return { g, side, fingers, thumb, t2, rod, palm };
  }
  const arms = { r: makeArm(1), l: makeArm(-1) };
  // Poses are in camera space: wrist position, finger direction, palm normal, curls (index..pinky, thumb), claw, spread.
  const pose = (pos, fin, palm, curl, claw = 0, spread = 0) => ({ pos: V(...pos), fin: V(...fin), palm: V(...palm), curl: curl.slice(), claw, spread });
  const mirror = p => ({ pos: V(-p.pos.x, p.pos.y, p.pos.z), fin: V(-p.fin.x, p.fin.y, p.fin.z), palm: V(-p.palm.x, p.palm.y, p.palm.z), curl: p.curl.slice(), claw: p.claw, spread: p.spread });
  function lerpPose(a, b, k) {
    return { pos: a.pos.clone().lerp(b.pos, k), fin: a.fin.clone().lerp(b.fin, k), palm: a.palm.clone().lerp(b.palm, k),
      curl: a.curl.map((c, i) => mix(c, b.curl[i], k)), claw: mix(a.claw, b.claw, k), spread: mix(a.spread, b.spread, k) };
  }
  const REST = pose([.36, -.45, -.78], [-.1, .38, -1], [-1, -.35, .05], [.38, .42, .48, .55, .3]);
  const Q_CHEST = pose([.13, -.27, -.55], [-.05, 1, -.12], [0, .05, -1], [1, 1, 1, 1, .9]);
  const Q_PUSH = pose([.1, -.18, -.8], [0, 1, .08], [0, .06, -1], [0, 0, 0, 0, 0], 0, 1);
  const E_REACH = pose([.24, -.17, -.86], [0, 1, .1], [0, 0, -1], [.25, .2, .22, .28, .2], .9, .8);
  const E_PULL = pose([.24, -.25, -.58], [.05, 1, .15], [-.1, 0, -1], [.5, .45, .5, .55, .4], 1, .3);
  const E_FAIL = pose([.2, -.2, -.82], [0, 1, .1], [0, 0, -1], [1, 1, 1, 1, .9]);
  const L_REST = mirror(REST);
  const L_ROD = pose([-.26, -.46, -.5], [0, 1, .15], [1, 0, 0], [1, 1, 1, 1, .8]);
  const L_STAB = pose([-.08, -.21, -.74], [0, 1, .05], [1, 0, 0], [1, 1, 1, 1, .8]);
  const R_CUP = pose([.11, -.15, -.62], [-.55, .55, -.7], [-.75, .55, .1], [.45, .45, .5, .55, .3]);
  const R_LAUNCH = pose([.15, -.02, -.6], [-.1, 1, -.25], [0, .35, -1], [0, 0, .05, .1, 0], 0, .6);
  const R_HOLD = pose([.2, -.08, -.72], [0, 1, -.35], [0, .45, -1], [.2, .2, .25, .3, .15], .35, .7);
  const R_FIST = pose([.18, -.12, -.66], [0, 1, -.25], [0, .4, -1], [1, 1, 1, 1, 1]);
  const R_COVER = pose([.15, -.24, -.64], [-.3, 1, 0], [0, 0, 1], [.5, .5, .5, .5, .4]);
  const _m = new T.Matrix4(), _x = V(), _y = V(), _z = V();
  function poseArm(arm, P, show = true) {
    arm.g.visible = show && active; if (!arm.g.visible) return;
    const ratio = clamp(camera.aspect, .55, 1);
    arm.g.position.copy(P.pos); arm.g.position.x *= ratio;
    _y.copy(P.fin).normalize(); _z.copy(P.palm).normalize().negate(); _z.addScaledVector(_y, -_z.dot(_y)).normalize(); _x.crossVectors(_y, _z);
    _m.makeBasis(_x, _y, _z); arm.g.quaternion.setFromRotationMatrix(_m); arm.g.scale.setScalar(.82 * mix(.8, 1, ratio));
    for (let i = 0; i < 4; i++) {
      const f = arm.fingers[i], c = P.curl[i];
      f.j1.rotation.set(-c * 1.35 - P.claw * .25, 0, arm.side * (1.5 - i) * P.spread * .13);
      f.j2.rotation.x = -c * 1.55 - P.claw * 1.1;
    }
    arm.thumb.rotation.set(-P.curl[4] * .7, 0, arm.side * (.85 - P.curl[4] * .5 + P.spread * .2));
    arm.t2.rotation.x = -P.curl[4] * .9;
  }

  // ---------- training dummies: Pain-only extras, movers, reactions ----------
  const extras = [[-4, -3], [4, -3], [11, -8], [-12, -6], [2, -30]].map(([x, z], i) => { const t = A.makeTarget(x, z, 4 + i); t.painOnly = true; return t; });
  for (const t of extras) { targets.splice(targets.indexOf(t), 1); t.g.visible = false; }
  const movers = new Map();
  const limbs = t => [t.g.children[3], t.g.children[4]];
  function setTilt(t, dir, phi) { t.g.rotation.x = phi * dir.z; t.g.rotation.z = -phi * dir.x; }
  function flail(t, k) {
    const [l, r] = limbs(t), w = Math.sin(A.time * 22 + t.index) * .55;
    l.rotation.z = -(1.3 + w) * k; r.rotation.z = (1.3 - w) * k; l.rotation.x = Math.cos(A.time * 17) * .5 * k; r.rotation.x = -Math.cos(A.time * 19) * .5 * k;
  }
  function calm(t) { for (const l of limbs(t)) l.rotation.set(0, 0, 0); t.g.rotation.x = 0; t.g.rotation.z = 0; }
  function take(t) { const old = movers.get(t); if (old?.drop) old.drop(); t.vel = null; t.locked = true; t.g.userData.cannonUntil = Infinity; }
  function release(t) { movers.delete(t); calm(t); t.locked = false; t.landed = A.time; t.g.userData.cannonUntil = 0; }
  function move(t, m) { take(t); m.born = A.time; movers.set(t, m); return m; }
  function handoff(t, m) { movers.delete(t); return move(t, m); }   // our own next stage: no interruption callback
  const edge = () => A.arenaR - 1.2;
  function clampArena(p) { const r = Math.hypot(p.x, p.z), lim = edge(); if (r > lim) { p.x *= lim / r; p.z *= lim / r; } }
  // First obstacle the body (half width .45) touches when sliding from `from` along a flat direction.
  function wallAlong(from, dir, dist) {
    const m = .45, p = V();
    for (let s = .12; s <= dist; s += .12) {
      p.copy(from).addScaledVector(dir, s); p.y = 1.2;
      const o = A.obstacles.find(o => p.x > o.x0 - m && p.x < o.x1 + m && p.z > o.z0 - m && p.z < o.z1 + m && p.y < o.h);
      if (o) {
        const prev = from.clone().addScaledVector(dir, s - .12), n = V(), hit = prev.clone();
        if (prev.x <= o.x0 - m) { n.set(-1, 0, 0); hit.x = o.x0 - .02; } else if (prev.x >= o.x1 + m) { n.set(1, 0, 0); hit.x = o.x1 + .02; }
        else if (prev.z <= o.z0 - m) { n.set(0, 0, -1); hit.z = o.z0 - .02; } else { n.set(0, 0, 1); hit.z = o.z1 + .02; }
        return { d: Math.max(0, s - .12), normal: n, point: hit.setY(1.3) };
      }
    }
    return null;
  }
  // Knocked down: lies on the back along `dir` for `hold`, then stands up; the app walks it home afterwards.
  function knockDown(t, dir, hold) {
    const from = Math.hypot(t.g.rotation.x, t.g.rotation.z);
    move(t, { kind: 'down', update(age) {
      const lie = age < .16 ? mix(from, Math.PI / 2, ease(age / .16)) : age < .16 + hold ? Math.PI / 2 : mix(Math.PI / 2, 0, ease((age - .16 - hold) / .4));
      setTilt(t, dir, lie); flail(t, Math.max(0, .4 - age));
      if (age > .56 + hold) release(t);
    } });
    dust(t.g.position.clone().setY(.2), 1.6, .8, V(0, .5, 0));
  }
  // Free fall from where the body is now (wall stops, the end of the rock sphere): no fall damage, then knocked down.
  function fall(t, dir, vel = V(), hold = .45) {
    const v = vel.clone();
    move(t, { kind: 'fall', update(age, dt) {
      v.y -= 26 * dt; t.g.position.addScaledVector(v, dt); clampArena(t.g.position);
      const wall = wallAlong(t.g.position, v.clone().setY(0).normalize(), v.clone().setY(0).length() * dt + .05);
      if (wall) { v.x = 0; v.z = 0; }
      setTilt(t, dir, Math.min(Math.PI / 2, age * 2.4)); flail(t, 1);
      if (t.g.position.y <= 0) { t.g.position.y = 0; floorRing(t.g.position.clone().setY(.06), 1.6, 0x8d8275, .4, .05, .6); sfx.thud(); knockDown(t, dir, hold); }
    } });
  }
  function alive(t) { return t.hp > 0 && t.g.visible !== false; }

  // ---------- camera feel ----------
  let shakeAmp = 0, shakeDecay = 10, fovKick = 0, eye = 0, eyeTarget = 0, vign = 0, flashV = 0, flashColor = '255,255,255', pushBack = 0;
  function shake(amp, decay = 10) { shakeAmp = Math.max(shakeAmp, amp * (A.comfort ? .3 : 1)); shakeDecay = decay; }
  function screenFlash(power, rgb = '255,255,255') { flashV = Math.max(flashV, power * (A.comfort ? .5 : 1)); flashColor = rgb; }
  const lookPitch = (p, from = basePos) => Math.atan2(p.y - from.y, Math.hypot(p.x - from.x, p.z - from.z));

  // ---------- state ----------
  let active = false, afterUntil = 0, afterFactor = 1, blurUntil = 0, blurLen = 1, comboUntil = 0, comboFrom = null, blurShown = false;
  function aimRing(t) {
    const s = sprite(rinTex, 0xffffff, .95); s.renderOrder = 6; s.material.depthTest = false;
    return keep(s);
  }

  // ---------- Q: Shinra Tensei ----------
  function shinraWave(center) {
    const Q = CFG.shinra, g = new T.Group(); g.position.copy(center);
    const glass = new T.Mesh(new T.SphereGeometry(1, 56, 36), new T.MeshPhysicalMaterial({ color: 0xffffff, transmission: 1, thickness: 3, roughness: .03, ior: 1.45, metalness: 0, transparent: true, side: T.DoubleSide, specularIntensity: 1 }));
    const rim = new T.Mesh(new T.SphereGeometry(1, 56, 36), new T.ShaderMaterial({ uniforms: { o: { value: 1 } }, transparent: true, depthWrite: false, blending: T.AdditiveBlending, side: T.DoubleSide,
      vertexShader: 'varying vec3 n;varying vec3 v;void main(){vec4 mv=modelViewMatrix*vec4(position,1.);n=normalize(normalMatrix*normal);v=normalize(-mv.xyz);gl_Position=projectionMatrix*mv;}',
      fragmentShader: 'uniform float o;varying vec3 n;varying vec3 v;void main(){float f=pow(1.-abs(dot(normalize(n),normalize(v))),2.);gl_FragColor=vec4(vec3(1.,.97,1.),min(1.,f*1.8)*o);}' }));
    g.add(glass, rim);
    const grow = Q.wave / .75;
    fx(g, .75, (o, u) => {
      const r = mix(1.1, Q.radius, out(u / grow)); o.scale.set(r, r * .82, r);
      const fade = seg(u, grow, 1); glass.material.opacity = 1 - fade; glass.material.thickness = 3 * (1 - fade); rim.material.uniforms.o.value = 1.15 * (1 - fade);
    });
    const feet = center.clone().setY(.05);
    floorRing(feet, Q.radius, 0xffffff, .55, .09, .9, .6);
    floorRing(feet, Q.radius * .82, 0xb9b0a4, .8, .22, .55, .4);
    for (let i = 0; i < 34; i++) { const a = i / 34 * Math.PI * 2 + rnd(0, .15), d = V(Math.cos(a), 0, Math.sin(a)); dust(feet.clone().addScaledVector(d, 1.4).setY(.35), rnd(1.6, 2.6), rnd(.9, 1.3), d.clone().multiplyScalar(rnd(22, 30)).setY(rnd(.5, 1.5)), 0xc9c1b5, .8); }
    for (let i = 0; i < 18; i++) { const a = rnd(0, Math.PI * 2), d = V(Math.cos(a), 0, Math.sin(a)); throwRock(feet.clone().addScaledVector(d, rnd(1, 2.5)).setY(.2), d.multiplyScalar(rnd(10, 18)).setY(rnd(3, 7)), rnd(.08, .22), rnd(1.2, 1.8)); }
    // Scorched scuff where the push left the floor.
    const scuff = new T.Mesh(new T.RingGeometry(.6, 3.2, 40), new T.MeshBasicMaterial({ color: 0x2c2724, transparent: true, opacity: .35, depthWrite: false }));
    scuff.rotation.x = -Math.PI / 2; scuff.position.copy(feet).setY(.02); fx(scuff, 3, (o, u) => o.material.opacity = .35 * (1 - u));
  }
  function shinraHit(t, feet) {
    const Q = CFG.shinra, dir = t.g.position.clone().sub(feet).setY(0);
    if (dir.lengthSq() < .01) dir.copy(A.flatForward()); dir.normalize();
    const near = 1 - clamp(t.g.position.distanceTo(feet) / Q.radius, 0, 1), dist = mix(Q.knockMin, Q.knockMax, near), lift = mix(Q.liftMin, Q.liftMax, near);
    A.hit(t, Q.damage, '#e6dcff');
    const from = t.g.position.clone(); from.y = 0;
    let travel = dist; const end = from.clone().addScaledVector(dir, dist), r = Math.hypot(end.x, end.z);
    if (r > edge()) { for (let s = dist; s > 0; s -= .2) { const p = from.clone().addScaledVector(dir, s); if (Math.hypot(p.x, p.z) <= edge()) { travel = s; break; } } }
    const wall = wallAlong(from, dir, travel);
    if (wall) travel = wall.d;
    const uEnd = 1 - Math.cbrt(1 - clamp(travel / dist, 0, .999));   // flight time where out(u)*dist reaches the stop
    dust(from.clone().setY(.4), 1.8, .6, dir.clone().multiplyScalar(-3));
    move(t, { kind: 'knock', update(age) {
      const u = Math.min(age / Q.flight, uEnd);
      t.g.position.copy(from).addScaledVector(dir, dist * out(u)); t.g.position.y = 4 * lift * u * (1 - u);
      setTilt(t, dir, 1.3 * Math.min(1, u * 2.2)); flail(t, 1);
      if (Math.random() < .5) dust(t.g.position.clone().setY(t.g.position.y + 1), .9, .4, dir.clone().multiplyScalar(-2), 0xe8e2d8, .45);
      if (u >= uEnd) {
        if (wall) {
          A.hit(t, Q.wallDamage, '#ffc4c4'); wallImpact(wall, dir); t.g.position.addScaledVector(dir, -.15);
          fall(t, dir.clone().negate(), dir.clone().multiplyScalar(-1.5));
        } else { t.g.position.y = 0; dust(t.g.position.clone().setY(.2), 2.2, .9, dir.clone().multiplyScalar(4)); sfx.thud(); knockDown(t, dir, .45); }
      }
    } });
  }
  // Crater on the wall face: a dark dent with radiating cracks, chips and dust thrown back along the face normal.
  function wallImpact(w, dir) {
    sfx.thud(); sfx.crack(); if (w.point.distanceTo(basePos) < 14) shake(.07, 14);
    const g = new T.Group(); g.position.copy(w.point); g.lookAt(w.point.clone().add(w.normal));
    const dent = new T.Mesh(new T.CircleGeometry(.42, 18), new T.MeshBasicMaterial({ color: 0x1c1a1c, transparent: true, opacity: .75, depthWrite: false })); g.add(dent);
    for (let i = 0; i < 9; i++) {
      const a = i / 9 * Math.PI * 2 + rnd(0, .4), len = rnd(.5, 1.3);
      const c = new T.Mesh(new T.PlaneGeometry(len, .045), new T.MeshBasicMaterial({ color: 0x141214, transparent: true, opacity: .85, depthWrite: false }));
      c.position.set(Math.cos(a) * len / 2, Math.sin(a) * len / 2, .005); c.rotation.z = a; g.add(c);
    }
    fx(g, 3.2, (o, u) => o.traverse(x => { if (x.material) x.material.opacity = (x === dent ? .75 : .85) * (1 - seg(u, .6, 1)); }));
    for (let i = 0; i < 12; i++) throwRock(w.point.clone().addScaledVector(w.normal, .2), w.normal.clone().multiplyScalar(rnd(3, 8)).add(V(rnd(-3, 3), rnd(1, 5), rnd(-3, 3))), rnd(.06, .16), rnd(1, 1.6));
    for (let i = 0; i < 6; i++) dust(w.point.clone().addScaledVector(w.normal, .3), rnd(1.4, 2.2), rnd(.8, 1.2), w.normal.clone().multiplyScalar(rnd(2, 4)).add(V(rnd(-1, 1), rnd(0, 1), rnd(-1, 1))), 0xcfc7bb, .7);
  }
  function updateShinra(c, a) {
    const Q = CFG.shinra, w = Q.windup, push = seg(a, w, w + .08), back = seg(a, w + .45, c.duration);
    const bow = ease(a / w) * (1 - ease(seg(a, w, w + .3)));
    camera.position.y -= .2 * bow; camera.rotation.x -= .13 * bow;
    camera.fov = 66 - 6 * ease(a / w) * (1 - push) + (a >= w ? 13 * Math.exp(-(a - w) * 5) : 0);
    vign = .6 * ease(a / w) * (1 - push); eyeTarget = .45;
    // The palm rises to the chest and the fingers open one by one, then the palm drives forward.
    let R = lerpPose(REST, Q_CHEST, ease(a / .26));
    R.curl = R.curl.map((v, i) => i < 4 ? v * (1 - ease(seg(a, .14 + i * .065, .22 + i * .065))) : v * (1 - ease(seg(a, .36, .43))));
    if (a >= w) R = lerpPose(R, Q_PUSH, out(seg(a, w, w + .09)));
    if (back > 0) R = lerpPose(R, REST, ease(back));
    poseArm(arms.r, R); poseArm(arms.l, lerpPose(L_REST, pose([-.36, -.58, -.56], [.1, .3, -1], [1, -.35, .05], [.5, .55, .6, .65, .4]), ease(a / w) * (1 - back)));
    if (a >= w && !c.flags.push) {
      c.flags.push = true; const feet = basePos.clone().setY(0);
      shinraWave(basePos.clone().setY(1.25)); sfx.boom(); shake(.22, 18); screenFlash(.22); pushBack = 1;
      for (const t of targets) {
        if (!alive(t)) continue; const d = t.g.position.distanceTo(feet);
        if (d <= Q.radius) A.later(d / Q.radius * Q.wave, () => { if (alive(t) && !c.flags['hit' + t.index]) { c.flags['hit' + t.index] = true; shinraHit(t, feet); } });
      }
    }
  }

  // ---------- E: Bansho Ten'in ----------
  function pickTarget() {
    const B = CFG.bansho, dir = A.aimDir(); let best = null, bestAngle = B.angle;
    for (const t of targets) {
      if (!alive(t) || movers.get(t)?.kind === 'seal') continue;
      const d = t.g.position.clone().add(V(0, 1.5, 0)).sub(basePos), dist = d.length(); if (dist > B.range) continue;
      d.normalize(); const ang = T.MathUtils.radToDeg(Math.acos(clamp(d.dot(dir), -1, 1)));
      if (ang < bestAngle && !A.wallOnRay(basePos, d, dist - .7)) { best = t; bestAngle = ang; }
    }
    return best;
  }
  function updateBansho(c, a, dt) {
    const B = CFG.bansho, t = c.target;
    if (c.miss) {
      const k = out(a / .16), back = seg(a, .3, c.duration);
      poseArm(arms.r, lerpPose(lerpPose(REST, E_REACH, k), E_FAIL, seg(a, .14, .26)), true); if (back > 0) poseArm(arms.r, lerpPose(E_FAIL, REST, ease(back)));
      poseArm(arms.l, L_REST); camera.fov = 66 - 3 * k * (1 - back); eyeTarget = .3;
      if (a > .16 && !c.flags.puff) { c.flags.puff = true; const at = camera.localToWorld(V(.16, -.1, -1)); for (let i = 0; i < 4; i++) dust(at, .5, .4, V(rnd(), rnd(), rnd()), 0xd9d0ff, .35); }
      return;
    }
    const chest = t.g.position.clone().add(V(0, 1.4, 0)), toward = t.g.position.clone().sub(basePos).setY(0).normalize();
    eyeTarget = .5;
    if (c.ring) { c.ring.position.copy(chest); c.ring.scale.setScalar(1.3 + Math.sin(A.time * 14) * .08); c.ring.material.rotation += dt * 2; }
    if (c.lens) { c.lens.position.copy(chest); c.lens.scale.setScalar(1.7 + Math.sin(A.time * 20) * .08); }
    if (a < B.windup) {
      const k = out(a / .22);
      poseArm(arms.r, lerpPose(REST, E_REACH, k)); poseArm(arms.l, L_REST);
      camera.position.addScaledVector(A.aimDir(), .14 * k); camera.fov = 66 - 7 * k;
      if (Math.random() < dt * 40) { const off = V(rnd(), rnd(-.3, 1), rnd()).normalize().multiplyScalar(rnd(2.2, 3.4)); dust(chest.clone().add(off), .6, .35, off.clone().multiplyScalar(-6), 0xd8d0c4, .5); }
      setTilt(t, toward.clone().negate(), .15 * k); flail(t, .3 * k);
      return;
    }
    if (!c.flags.pull) {
      c.flags.pull = true; c.from = t.g.position.clone(); c.from.y = 0;
      c.to = basePos.clone().setY(0).addScaledVector(toward.clone().negate(), -B.stop);
      const dist = c.from.distanceTo(c.to); c.pullDur = mix(B.pullMin, B.pullMax, clamp(dist / B.range, 0, 1)); c.toward = toward.clone();
      sfx.pull(); handoff(t, { kind: 'pull', drop: () => { c.cancel = true; } });
    }
    const pd = c.pullDur, ps = B.windup;
    if (!c.arrive && !c.cancel) {
      const u = clamp((a - ps) / pd, 0, 1), k = out(u), prev = t.g.position.clone();
      const next = c.from.clone().lerp(c.to, k); next.y = B.lift * Math.sin(Math.min(1, u * 2.5) * Math.PI / 2) * (1 - seg(u, .85, 1) * .7);
      const step = next.clone().sub(prev), len = step.length();
      if (len > .001 && A.wallOnRay(prev.clone().setY(1.3), step.clone().normalize(), len + .45)) {
        c.cancel = true; c.duration = a + .45; release(t); fall(t, c.toward, V()); A.toast('장애물에 막혀 만상천인이 끊겼습니다'); sfx.fail();
        for (const o of [c.ring, c.lens]) if (o) kill(o); c.ring = c.lens = null;
      } else {
        t.g.position.copy(next); setTilt(t, c.toward.clone().negate(), .55 * (1 - u * .5)); flail(t, 1);
        if (Math.random() < .8) { const p = t.g.position.clone().add(V(rnd(-.4, .4), rnd(.6, 2.2), rnd(-.4, .4))); glowAt(p, PURPLE, rnd(.25, .5), .45, .5, .8); dust(p, .5, .45, c.toward.clone().multiplyScalar(rnd(3, 6)), 0xcbbcff, .35); }
        if (Math.random() < dt * 14) { const at = t.g.position.clone().lerp(basePos, rnd(.2, .8)).setY(rnd(1, 2)); const r = new T.Mesh(new T.TorusGeometry(.9, .02, 4, 32), new T.MeshBasicMaterial({ color: 0xe8e0ff, transparent: true, opacity: .45, depthWrite: false })); r.position.copy(at); r.lookAt(basePos); fx(r, .3, (o, uu) => { o.scale.setScalar(1.6 - uu * 1.4); o.material.opacity = .45 * (1 - uu); }); }
        poseArm(arms.r, lerpPose(E_REACH, E_PULL, ease(u))); poseArm(arms.l, lerpPose(L_REST, L_ROD, ease(seg(u, .5, 1))));
        if (arms.l.rod) { arms.l.rod.visible = u > .55; arms.l.rod.scale.set(ease(seg(u, .55, 1)), 1, 1); }
        camera.fov = 59 + 13 * Math.sin(u * Math.PI * .5) * (1 - seg(u, .9, 1) * .6); camera.position.addScaledVector(A.aimDir(), .14 * (1 - u));
        if (u >= 1) { c.arrive = a; t.g.position.y = .25; }
      }
      return;
    }
    if (c.cancel) { poseArm(arms.r, lerpPose(E_PULL, REST, ease(seg(a, c.duration - .45, c.duration)))); poseArm(arms.l, L_REST); if (arms.l.rod) arms.l.rod.visible = false; return; }
    // Arrived: the left hand drives the chakra receiver in, then everything returns to rest.
    const s = a - c.arrive, stab = out(seg(s, B.strikeDelay - .06, B.strikeDelay)), back = seg(s, B.strikeDelay + .2, B.strikeDelay + .2 + B.recovery);
    poseArm(arms.r, lerpPose(E_PULL, REST, ease(seg(s, 0, .3))));
    poseArm(arms.l, lerpPose(lerpPose(L_ROD, L_STAB, stab), L_REST, ease(back)));
    if (arms.l.rod) { arms.l.rod.visible = back < .6; arms.l.rod.scale.set(1 - ease(seg(back, 0, .6)), 1, 1); mRod.emissiveIntensity = stab * (1 - back) * 1.5; }
    if (!c.flags.stab && s >= B.strikeDelay) {
      c.flags.stab = true; A.hit(t, B.damage, '#c9a6ff'); sfx.stab(); shake(.12, 16); pushBack = -1; screenFlash(.12, '200,170,255');
      const p = chest.clone(); glowAt(p, 0x5c2fb0, 1.2, .3, 2.5, .9); glowAt(p, 0xffffff, .6, .15, 3, 1);
      for (let i = 0; i < 10; i++) throwRock(p, c.toward.clone().multiplyScalar(rnd(4, 9)).add(V(rnd(-2, 2), rnd(0, 3), rnd(-2, 2))), rnd(.03, .07), .8);
      for (const o of [c.ring, c.lens]) if (o) kill(o); c.ring = c.lens = null;
      const from = t.g.position.clone().setY(0), wall = wallAlong(from, c.toward, B.knock), dist = wall ? wall.d : B.knock;
      handoff(t, { kind: 'strike', update(age) {
        const u = Math.min(1, age / B.knockTime); t.g.position.copy(from).addScaledVector(c.toward, dist * out(u)); t.g.position.y = .25 * (1 - u);
        setTilt(t, c.toward, .5 + Math.sin(age * 30) * .12 * (1 - age / (B.knockTime + B.stun))); flail(t, .6);
        if (age > B.knockTime + B.stun) release(t);
      } });
      c.duration = a + .2 + B.recovery + .05;
    }
    camera.fov = 66 - 6 * stab * (1 - back);
  }

  // ---------- R: Chibaku Tensei ----------
  function fib(i, n) { const y = 1 - (i + .5) / n * 2, r = Math.sqrt(1 - y * y), th = i * Math.PI * (3 - Math.sqrt(5)); return V(Math.cos(th) * r, y, Math.sin(th) * r); }
  function makeCore(radius) {
    const g = new T.Group();
    g.add(new T.Mesh(new T.SphereGeometry(radius, 24, 16), new T.MeshStandardMaterial({ color: 0x050407, roughness: .25, metalness: .7 })));
    for (let i = 0; i < 3; i++) { const r = new T.Mesh(new T.TorusGeometry(radius * (1.35 + i * .28), radius * .05, 6, 48), new T.MeshBasicMaterial({ color: i % 2 ? 0x6a3fd0 : 0xc6a8ff, transparent: true, opacity: .9 })); r.rotation.set(rnd(0, 3), rnd(0, 3), 0); r.userData.spin = (i + 1) * (i % 2 ? -1 : 1); g.add(r); }
    const aura = sprite(glowTex, 0x8a5cff, .9, true); aura.scale.setScalar(radius * 9); g.add(aura); g.userData.aura = aura;
    return g;
  }
  function spinCore(g, dt) { for (const r of g.children) if (r.userData.spin) { r.rotation.x += dt * r.userData.spin; r.rotation.y += dt * r.userData.spin * .6; } }
  const handOrb = makeCore(.05); camera.add(handOrb); handOrb.position.set(0, -.08, -.64); handOrb.visible = false;
  handOrb.traverse(o => { o.renderOrder = 103; o.frustumCulled = false; if (o.material) o.material.depthTest = false; });
  function beginChibaku(c) {
    const R = CFG.chibaku, ch = c.ch = { rocks: [], captured: [], pebbles: [], cracks: [] };
    ch.center = basePos.clone().addScaledVector(A.flatForward(), R.forward).setY(0);
    ch.core = ch.center.clone().setY(R.height); ch.pitch0 = A.pitch;
    for (let i = 0; i < 10; i++) { const a = rnd(0, Math.PI * 2), d = rnd(1, 3.2), m = keep(rock(rnd(.04, .1))); m.position.set(basePos.x + Math.cos(a) * d, .05, basePos.z + Math.sin(a) * d); ch.pebbles.push({ m, y: rnd(.4, 1.6), s: rnd(.5, 1.5) }); }
  }
  function updateChibaku(c, a, dt) {
    const R = CFG.chibaku, ch = c.ch;
    eyeTarget = a < R.burst ? mix(.55, .95, seg(a, 0, R.formed)) : .5;
    // --- camera: look up at the hands, follow the core, watch the sphere, return after the burst ---
    const coreNow = ch.coreObj ? ch.coreObj.position : ch.core, lookCore = lookPitch(ch.core), drag = A.pitch - ch.pitch0;
    let want;
    if (a < R.gather) want = ch.pitch0 + .14 * ease(a / .5);
    else if (a < R.launch) want = mix(ch.pitch0 + .14, lookPitch(coreNow), ease(seg(a, R.gather, R.gather + .3)));
    else if (a < R.burst + .3) want = mix(lookCore, lookCore - .2, ease(seg(a, R.launch, R.launch + .5)));
    else want = mix(lookCore - .2, ch.pitch0, ease(seg(a, R.burst + .3, R.duration)));
    camera.rotation.x = Math.min(1.35, want + drag); if (a < R.gather) camera.position.y -= .08 * ease(a / .4);
    camera.fov = 66 - 4 * ease(a / R.gather) * (1 - seg(a, R.gather, R.gather + .2)) + 4 * seg(a, R.gather, R.launch) * (1 - seg(a, R.launch, R.launch + .6));
    vign = a < R.launch ? .35 * ease(a / .5) : a < R.burst ? .25 + .25 * seg(a, R.formed, R.compressEnd) : .25 * (1 - seg(a, R.burst, R.duration));
    // --- arms ---
    let Rp, Lp;
    if (a < R.gather) { const k = ease(a / .35); Rp = lerpPose(REST, R_CUP, k); Lp = lerpPose(L_REST, mirror(R_CUP), k); }
    else if (a < R.launch) { const k = out(seg(a, R.gather, R.gather + .2)), back = ease(seg(a, R.gather + .35, R.launch)); Rp = lerpPose(lerpPose(R_CUP, R_LAUNCH, k), R_HOLD, back); Lp = lerpPose(lerpPose(mirror(R_CUP), mirror(R_LAUNCH), k), L_REST, back); }
    else if (a < R.formed) { Rp = R_HOLD; Lp = L_REST; }
    else if (a < R.burst) { const k = ease(seg(a, R.formed, R.compressEnd)); Rp = lerpPose(R_HOLD, R_FIST, k); Rp.pos.x += Math.sin(A.time * 47) * .006 * k; Rp.pos.y += Math.cos(A.time * 53) * .006 * k; Lp = L_REST; }
    else { const k = out(seg(a, R.burst, R.burst + .12)), back = ease(seg(a, R.burst + .4, R.duration)); Rp = lerpPose(lerpPose(R_FIST, R_COVER, k), REST, back); Lp = lerpPose(lerpPose(L_REST, mirror(R_COVER), k), L_REST, back); }
    poseArm(arms.r, Rp); poseArm(arms.l, Lp);
    // --- gather: orb between the palms, pebbles lift around the feet ---
    handOrb.visible = a < R.gather;
    if (handOrb.visible) { handOrb.scale.setScalar(.3 + 1.2 * ease(a / R.gather) + Math.sin(A.time * 30) * .05); spinCore(handOrb, dt); }
    if (!c.flags.beat2 && a > .45) { c.flags.beat2 = true; sfx.heartbeat(); }
    for (const p of ch.pebbles) { if (!p.m.parent) continue; if (a < R.gather + .1) { p.m.position.y = .05 + p.y * ease(a / R.gather) + Math.sin(A.time * 3 + p.s) * .05; p.m.rotation.y += dt * p.s; } }
    // --- launch: the core leaves the hands and climbs to its point in the sky ---
    if (a >= R.gather && !c.flags.launch) {
      c.flags.launch = true; sfx.launch(); shake(.05, 8);
      ch.from = camera.localToWorld(handOrb.position.clone()); ch.coreObj = keep(makeCore(.75)); ch.coreObj.position.copy(ch.from);
      ch.light = new T.PointLight(0x9a6bff, 0, 90, 1.4); ch.coreObj.add(ch.light);
      for (const p of ch.pebbles) { throwRock(p.m.position.clone(), V(rnd(-1, 1), rnd(1, 3), rnd(-1, 1)), p.m.scale.x, 1.2, p.m); live.delete(p.m); }
    }
    if (ch.coreObj) {
      spinCore(ch.coreObj, dt); ch.coreObj.userData.aura.material.opacity = .7 + Math.sin(A.time * 9) * .15;
      if (a < R.launch) { const k = out(seg(a, R.gather, R.launch)); ch.coreObj.position.lerpVectors(ch.from, ch.core, k); ch.coreObj.scale.setScalar(.15 + .85 * k); glowAt(ch.coreObj.position.clone(), PURPLE, .8, .4, .3, .5); }
      else ch.coreObj.position.copy(ch.core);
      ch.light.intensity = 60 * seg(a, R.gather, R.launch);
    }
    // --- arrival: gravity wave, the field starts pulling ---
    if (a >= R.launch && !c.flags.field) {
      c.flags.field = true; sfx.gravity(); startDrone(); shake(.1, 6); screenFlash(.1, '170,130,255');
      floorRing(ch.center.clone().setY(.08), R.radius, 0x9c6cff, 1.1, .16, .9, 1); floorRing(ch.center.clone().setY(.1), R.radius * .7, 0xffffff, .8, .06, .6, 1);
      glowAt(ch.core.clone(), 0xb48cff, 6, .7, 2, .8);
      const disc = new T.Mesh(new T.CircleGeometry(R.radius, 64), new T.MeshBasicMaterial({ color: 0x6b3fd0, transparent: true, opacity: .0, depthWrite: false }));
      disc.rotation.x = -Math.PI / 2; disc.position.copy(ch.center).setY(.03); ch.disc = keep(disc);
    }
    if (ch.disc) ch.disc.material.opacity = .12 * seg(a, R.launch, R.launch + .3) * (1 - seg(a, R.burst, R.burst + .4));
    const inField = t => Math.hypot(t.g.position.x - ch.center.x, t.g.position.z - ch.center.z) <= R.radius;
    if (a >= R.field && a < R.formed) {
      bendDrone(seg(a, R.field, R.compressEnd) * .4);
      if (Math.random() < dt * 30) { const ang = rnd(0, Math.PI * 2), d = Math.sqrt(Math.random()) * R.radius; dust(ch.center.clone().add(V(Math.cos(ang) * d, .3, Math.sin(ang) * d)), rnd(1.2, 2.4), rnd(1, 1.6), V(0, rnd(2, 5), 0), 0xd9d1c4, .55); }
      for (const t of targets) if (alive(t) && !movers.has(t) && inField(t) && a < R.lift) { setTilt(t, ch.center.clone().sub(t.g.position).setY(0).normalize(), .12 * seg(a, R.field, R.lift)); flail(t, .3); }
    }
    // --- capture: the nearest bodies in the field are lifted on a spiral toward the core ---
    if (a >= R.lift && !c.flags.capture) {
      c.flags.capture = true;
      const pool = targets.filter(t => alive(t) && inField(t)).sort((x, y) => x.g.position.distanceTo(ch.center) - y.g.position.distanceTo(ch.center)).slice(0, R.captureMax);
      pool.forEach((t, i) => {
        const rel = t.g.position.clone().sub(ch.center), slot = fib(i * 3 + 1, R.captureMax * 3).multiplyScalar(R.seal);
        const v = { t, r0: Math.hypot(rel.x, rel.z), a0: Math.atan2(rel.z, rel.x), y0: t.g.position.y, slot };
        ch.captured.push(v); move(t, { kind: 'seal', drop: () => { v.lost = true; } });
      });
    }
    for (const v of ch.captured) {
      const t = v.t; if (v.lost || !movers.has(t)) continue;
      if (t.hp <= 0) { v.lost = true; release(t); continue; }
      if (a < R.formed) {
        const u = seg(a, R.lift, R.formed - .15), k = ease(Math.pow(u, .85)), lift = ease(seg(a, R.lift, R.lift + .4));
        const target = ch.core.clone().add(v.slot), rel = target.clone().sub(ch.center);
        const r = mix(v.r0, Math.hypot(rel.x, rel.z), k), ang = v.a0 + 2.4 * Math.PI * k, y = mix(v.y0 + .6 * lift, target.y - 1.2, ease(Math.pow(u, 1.2)));
        t.g.position.set(ch.center.x + Math.cos(ang) * r, y, ch.center.z + Math.sin(ang) * r);
        t.g.rotation.x = Math.sin(A.time * 3 + t.index) * .9 * lift; t.g.rotation.z = Math.cos(A.time * 2.4 + t.index) * .9 * lift; flail(t, 1);
        if (Math.random() < dt * 8) dust(t.g.position.clone().add(V(0, 1, 0)), .8, .5, V(0, -2, 0), 0xd9d1c4, .4);
      } else if (!v.sealed) { v.sealed = true; t.g.visible = false; t.g.position.copy(ch.core).add(v.slot).setY(ch.core.y + v.slot.y - 1.2); }
    }
    for (const at of R.ticks) if (a >= at && !c.flags['tick' + at]) { c.flags['tick' + at] = true; for (const v of ch.captured) if (!v.lost && v.t.hp > 0) { const vis = v.t.g.visible; A.hit(v.t, R.tick, '#bfa0ff'); if (v.t.hp > 0) v.t.g.visible = vis; } }
    // --- debris: rocks torn from the floor rise on spirals and pack onto the core; the floor caves in ---
    if (a >= R.debris && !c.flags.debris) {
      c.flags.debris = true; sfx.crack();
      ch.sphere = keep(new T.Group()); ch.sphere.position.copy(ch.core);
      ch.inner = new T.Mesh(rockGeo(5, 3), sealRock[2]); ch.inner.scale.setScalar(.01); ch.sphere.add(ch.inner);
      for (let i = 0; i < R.rocks; i++) {
        const big = i % 5 < 2, size = big ? rnd(.75, 1.5) : rnd(.28, .6), dur = big ? rnd(1.3, 1.65) : rnd(.6, .85);
        const startAt = R.debris + Math.random() * Math.max(.05, R.formed - .08 - dur - R.debris);
        const ang = rnd(0, Math.PI * 2), d = rnd(3, R.radius * .95), slot = fib(i, R.rocks).multiplyScalar(R.sphere * rnd(.72, 1));
        const m = rock(size, sealRock); m.visible = false; scene.add(m);
        ch.rocks.push({ m, size, dur, startAt, a0: ang, r0: d, slot, spin: V(rnd(), rnd(), rnd()).multiplyScalar(big ? 2 : 6), turns: rnd(1, 1.8) * (Math.random() < .5 ? -1 : 1), stuck: false });
      }
      crater(ch.center, R);
    }
    if (ch.sphere) {
      ch.sphere.rotation.y += dt * .35; ch.sphere.rotation.x += dt * .12;
      const fill = ease(seg(a, R.debris + .4, R.formed)); ch.inner.scale.setScalar(.01 + R.sphere * .78 * fill);
      for (const r of ch.rocks) {
        if (r.stuck || a < r.startAt) continue;
        const u = (a - r.startAt) / r.dur;
        if (!r.m.visible) { r.m.visible = true; dust(ch.center.clone().add(V(Math.cos(r.a0) * r.r0, .3, Math.sin(r.a0) * r.r0)), r.size * 2.6, .9, V(0, 2, 0)); }
        const end = ch.sphere.localToWorld(r.slot.clone()), rel = end.clone().sub(ch.center), k = ease(Math.pow(Math.min(u, 1), .8));
        const ang = mix(r.a0, Math.atan2(rel.z, rel.x) + r.turns * Math.PI * 2, k), rad = mix(r.r0, Math.hypot(rel.x, rel.z), k);
        r.m.position.set(ch.center.x + Math.cos(ang) * rad, mix(r.size * .5, end.y, ease(Math.min(u, 1))), ch.center.z + Math.sin(ang) * rad);
        r.m.rotation.x += r.spin.x * dt; r.m.rotation.y += r.spin.y * dt; r.m.rotation.z += r.spin.z * dt;
        if (u >= 1) { r.stuck = true; ch.sphere.attach(r.m); sfx.clack(); if (Math.random() < .5) dust(end, r.size * 2, .4, V(), 0xcfc6b8, .5); }
      }
    }
    // --- compression: the sphere squeezes, cracks fill with purple light ---
    if (a >= R.formed && a < R.burst) {
      const k = ease(seg(a, R.formed, R.compressEnd)), shiver = Math.sin(A.time * 60) * .012 * k;
      if (ch.sphere) ch.sphere.scale.setScalar(1 - .14 * k + shiver);
      for (const m of sealRock) { m.emissive.setHex(0x7a3cff); m.emissiveIntensity = .04 + .22 * k * (.7 + Math.random() * .3); }
      if (!c.flags.cracks) {
        c.flags.cracks = true;
        for (let i = 0; i < 16; i++) {
          const dir = fib(i * 4 + 2, 64), crack = new T.Mesh(new T.PlaneGeometry(rnd(3, 6), .32), new T.MeshBasicMaterial({ color: 0xc9a6ff, transparent: true, opacity: 0, depthWrite: false, blending: T.AdditiveBlending, side: T.DoubleSide }));
          crack.position.copy(dir.clone().multiplyScalar(R.sphere * 1.02)); crack.lookAt(dir.clone().multiplyScalar(R.sphere * 3)); crack.rotation.z = rnd(0, Math.PI);
          ch.sphere.add(crack); ch.cracks.push(crack);
        }
      }
      for (const cr of ch.cracks) cr.material.opacity = Math.min(1, k * 1.6) * (.7 + Math.random() * .3);
      if (ch.coreObj) ch.coreObj.visible = false;
      bendDrone(.4 + .6 * k); if (Math.random() < dt * 6) sfx.crack(); if (k > .2) shake(.025 * k, 30);
      if (ch.light) { ch.light.intensity = 60 + 140 * k; ch.sphere?.add(ch.light); ch.light.position.set(0, 0, 0); }
    }
    // --- burst: rocks scatter, sealed bodies fall out ---
    if (a >= R.burst && !c.flags.burst) { c.flags.burst = true; burstChibaku(c); }
    if (a >= R.burst) for (const m of sealRock) m.emissiveIntensity = .5 * (1 - seg(a, R.burst, R.duration));
  }
  function crater(center, R) {
    const g = new T.Group(); g.position.copy(center).setY(.02);
    const pit = new T.Mesh(new T.CircleGeometry(7, 48), new T.MeshBasicMaterial({ color: 0x2b2622, transparent: true, opacity: .85, depthWrite: false })); pit.rotation.x = -Math.PI / 2; g.add(pit);
    const ringM = new T.Mesh(new T.RingGeometry(6.6, 8.4, 48), new T.MeshBasicMaterial({ color: 0x4a423b, transparent: true, opacity: .7, depthWrite: false })); ringM.rotation.x = -Math.PI / 2; ringM.position.y = .01; g.add(ringM);
    for (let i = 0; i < 26; i++) { const a = i / 26 * Math.PI * 2 + rnd(0, .2), m = rock(rnd(.3, .8)); m.position.set(Math.cos(a) * rnd(6.4, 8.2), rnd(0, .2), Math.sin(a) * rnd(6.4, 8.2)); g.add(m); }
    for (let i = 0; i < 18; i++) dust(center.clone().add(V(rnd(-6, 6), .4, rnd(-6, 6))), rnd(2, 3.5), rnd(1, 1.6), V(0, rnd(1, 3), 0), 0xcfc6b8, .7);
    fx(g, R.crater, (o, u) => { const f = 1 - seg(u, .75, 1); pit.material.opacity = .85 * f; ringM.material.opacity = .7 * f; for (const r of o.children) if (r.isMesh && r !== pit && r !== ringM) r.scale.setScalar(Math.max(.001, r.userData.s ??= r.scale.x) * f); });
  }
  function burstChibaku(c) {
    const R = CFG.chibaku, ch = c.ch, core = ch.core.clone();
    stopLoops(.15); sfx.explosion(); shake(.32, 4); screenFlash(.6, '235,220,255'); A.flash('#d9c6ff', .35);
    glowAt(core, 0xffffff, 14, .5, 1.5, 1); glowAt(core, 0x9a6bff, 22, 1.1, 1.2, .9);
    const blast = new T.Mesh(new T.SphereGeometry(1, 32, 20), new T.MeshBasicMaterial({ color: 0xe6dcff, transparent: true, opacity: .3, depthWrite: false, side: T.DoubleSide }));
    blast.position.copy(core); fx(blast, .6, (o, u) => { o.scale.setScalar(R.sphere * (1 + 2.2 * out(u))); o.material.opacity = .3 * (1 - u); });
    floorRing(ch.center.clone().setY(.1), R.radius * 1.1, 0xd8ccff, 1.2, .2, .8, 3);
    for (let i = 0; i < 40; i++) { const a = i / 40 * Math.PI * 2, d = V(Math.cos(a), 0, Math.sin(a)); dust(ch.center.clone().addScaledVector(d, 5).setY(.5), rnd(3, 5), rnd(1.4, 2), d.multiplyScalar(rnd(16, 24)).setY(rnd(.5, 2)), 0xd6cdc0, .8); }
    for (const m of sealRock) { m.emissiveIntensity = .5; }
    if (ch.sphere) {
      for (const r of ch.rocks) {
        const m = r.m; if (!m.parent) continue; if (!m.visible) { kill(m); continue; } scene.attach(m);
        const dir = m.position.clone().sub(core).normalize(); if (!r.stuck) dir.set(rnd(), rnd(0, 1), rnd()).normalize();
        throwRock(m.position.clone(), dir.multiplyScalar(rnd(10, 24)).add(V(0, rnd(2, 8), 0)), r.size, rnd(2, 3), m);
      }
      for (let i = 0; i < 30; i++) { const d = V(rnd(), rnd(), rnd()).normalize(); throwRock(core.clone().addScaledVector(d, R.sphere * .6), d.multiplyScalar(rnd(14, 28)), rnd(.3, .8), rnd(1.8, 2.6)); }
      kill(ch.sphere); ch.sphere = null;
    }
    if (ch.coreObj) { kill(ch.coreObj); ch.coreObj = null; }
    for (const v of ch.captured) {
      if (v.lost || !movers.has(v.t)) continue; const t = v.t;
      t.g.visible = true; A.hit(t, R.final, '#d3b8ff');
      if (t.hp <= 0) { movers.delete(t); calm(t); continue; }
      const out2 = v.slot.clone().setY(0).normalize(); t.g.position.copy(core).add(v.slot);
      fall(t, out2, out2.clone().multiplyScalar(rnd(3, 5)).setY(4), R.down);
    }
    blurUntil = A.time + 1.5; blurLen = 1.5;
  }
  function endChibaku(c) {
    const ch = c.ch; if (!ch) return; handOrb.visible = false;
    for (const p of ch.pebbles) kill(p.m);
    for (const o of [ch.sphere, ch.coreObj, ch.disc]) if (o) kill(o);
    for (const r of ch.rocks) if (r.m.parent && !fxs.some(e => e.obj === r.m)) kill(r.m);
    for (const v of ch.captured) if (!v.lost && movers.get(v.t)?.kind === 'seal') { v.t.g.visible = v.t.hp > 0; fall(v.t, V(1, 0, 0), V(0, 2, 0), R0.down); }
    for (const m of sealRock) { m.emissive.setHex(0); m.emissiveIntensity = 0; }
    stopLoops(.3);
  }
  const R0 = CFG.chibaku;

  // ---------- app hooks ----------
  function begin(c) {
    c.pain = true; c.flags = c.flags || {};
    if (c.type === 'shinra') {
      c.duration = CFG.shinra.windup + CFG.shinra.wave + CFG.shinra.recovery;
      A.title('神羅天征', '신라천정', '손바닥을 열고 0.45초 뒤 밀어낸다 · 반경 25 · 30 피해 · 벽 충돌 +5', '#d4c2ff'); sfx.resonance();
    }
    if (c.type === 'bansho') {
      const t = pickTarget(); c.target = t;
      if (!t) {
        c.miss = true; c.duration = .16 + CFG.bansho.missRecovery + .1; A.cooldowns.bansho = A.time + CFG.bansho.missCd;
        A.title('万象天引', '만상천인 · 대상 없음', '화면 중앙 12° · 55 안에 보이는 대상이 없어 1.5초 뒤 재사용', '#b084ff'); sfx.fail();
      } else {
        c.duration = 9;   // replaced when the pull ends
        c.ring = aimRing(t); const lens = new T.Mesh(new T.SphereGeometry(1, 32, 20), new T.MeshPhysicalMaterial({ transmission: 1, thickness: .5, roughness: .02, ior: 1.1, transparent: true }));
        c.lens = keep(lens); c.lens.scale.setScalar(1.7);
        A.title('万象天引', '만상천인', '끌어당겨 4칸 앞에 세운 뒤 흑봉으로 찌른다 · 25 피해 · 0.5초 경직', '#b084ff'); sfx.suck();
        take(t); movers.set(t, { kind: 'aim', drop: () => { c.cancel = true; } });
      }
    }
    if (c.type === 'chibaku') {
      c.duration = CFG.chibaku.duration; beginChibaku(c);
      A.title('地爆天星', '지폭천성', '핵을 쏘아 올려 암석 구체로 봉인 · 최대 75 피해 · 시전 중 받는 피해 -30%', '#a678ff'); sfx.heartbeat();
    }
  }
  function update(c, a, dt) {
    if (c.type === 'shinra') updateShinra(c, a, dt);
    else if (c.type === 'bansho') updateBansho(c, a, dt);
    else if (c.type === 'chibaku') updateChibaku(c, a, dt);
  }
  function end(c) {
    if (c.type === 'shinra') { afterUntil = A.time + CFG.shinra.slow; afterFactor = CFG.shinra.slowFactor; comboFrom = 'shinra'; comboUntil = A.time + COMBO_WINDOW; }
    if (c.type === 'bansho') {
      for (const o of [c.ring, c.lens]) if (o) kill(o);
      if (c.target && movers.get(c.target)?.kind === 'aim') release(c.target);
      if (arms.l.rod) arms.l.rod.visible = false; mRod.emissiveIntensity = 0;
      if (!c.miss && !c.cancel) { comboFrom = 'bansho'; comboUntil = A.time + COMBO_WINDOW; }
    }
    if (c.type === 'chibaku') { endChibaku(c); afterUntil = A.time + CFG.chibaku.slow; afterFactor = CFG.chibaku.slowFactor; comboUntil = 0; }
  }
  function frame(dt, moving) {
    const c = A.cast, now = A.time;
    // Arms rest low and sway with the walk unless a skill is posing them.
    if (active && !c?.pain) {
      const m = A.melee, sw = moving ? Math.sin(now * 10) : 0, idle = Math.sin(now * 1.9) * .006;
      const R = lerpPose(REST, REST, 0), L = lerpPose(L_REST, L_REST, 0);
      R.pos.y += moving ? sw * .02 : idle; R.pos.x += moving ? Math.sin(now * 5) * .012 : 0; L.pos.y += moving ? -sw * .02 : idle; L.pos.x += moving ? Math.sin(now * 5) * .012 : 0;
      if (m) {
        const k = Math.sin(clamp((now - m.start) / m.duration, 0, 1) * Math.PI), P = m.combo % 2 ? R : L, side = m.combo % 2 ? 1 : -1;
        const punch = pose([side * .1, -.3, -1.0], [0, 1, -.2], [-side * .2, 0, -1], [1, 1, 1, 1, .9]);
        Object.assign(P, lerpPose(P, side > 0 ? punch : punch, k));
      }
      if (A.sliding) { R.pos.y -= .1; L.pos.y -= .1; R.pos.x += .08; L.pos.x -= .08; }
      poseArm(arms.r, R); poseArm(arms.l, L); if (arms.l.rod) arms.l.rod.visible = false;
      eyeTarget = 0.06;
    }
    if (!active) { arms.r.g.visible = arms.l.g.visible = false; }
    // Victims driven by Pain.
    for (const [t, m] of [...movers]) { if (t.hp <= 0) { release(t); continue; } m.update?.(now - m.born, dt); }
    // Camera shake, push-back and the after-slow blur.
    if (shakeAmp > .001) { camera.position.x += rnd() * shakeAmp; camera.position.y += rnd() * shakeAmp; camera.rotation.z += rnd() * shakeAmp * .25; shakeAmp *= Math.exp(-shakeDecay * dt); }
    if (pushBack) { camera.position.addScaledVector(A.aimDir(), -.12 * pushBack); pushBack *= Math.exp(-10 * dt); if (Math.abs(pushBack) < .01) pushBack = 0; }
    const blur = blurUntil > now && !A.comfort ? 3 * (blurUntil - now) / blurLen : 0;
    if (blur > 0) { $('scene').style.filter = `blur(${blur.toFixed(2)}px)`; blurShown = true; } else if (blurShown) { blurShown = false; $('scene').style.filter = ''; }
    // Screen layers.
    eye = mix(eye, active ? eyeTarget : 0, Math.min(1, dt * 6)); vign = active ? vign * Math.exp(-2 * dt * (c?.pain ? 0 : 1)) : 0;
    ovR.style.opacity = (eye * .55).toFixed(3); ovR.style.transform = `scale(${1 + eye * .08}) rotate(${(now * 6) % 360}deg)`;
    ovV.style.opacity = Math.min(1, vign + eye * .25).toFixed(3);
    ovF.style.background = `radial-gradient(circle at 50% 55%,rgba(${flashColor},.0),rgba(${flashColor},.85))`; ovF.style.opacity = flashV.toFixed(3); flashV *= Math.exp(-9 * dt);
    if (A.muted && loops.size) stopLoops(.05);
    // Effects.
    for (let i = fxs.length - 1; i >= 0; i--) { const e = fxs[i], u = (now - e.born) / e.life; if (u >= 1) { fxs.splice(i, 1); e.done?.(); kill(e.obj); } else e.update?.(e.obj, u, dt); }
  }
  function speed() {
    const c = A.cast, now = A.time;
    if (c?.pain) {
      const a = now - c.start;
      if (c.type === 'shinra') return CFG.shinra.castSpeed;
      if (c.type === 'bansho') return .3;
      if (c.type === 'chibaku') return a < CFG.chibaku.gather ? 0 : CFG.chibaku.castSpeed;
    }
    return now < afterUntil ? afterFactor : 1;
  }
  function hud() {
    const now = A.time, combo = comboUntil > now && !A.cast, c = A.cast;
    $('qBtn').classList.toggle('combo', combo && comboFrom === 'bansho');
    $('rBtn').classList.toggle('combo', combo);
    const prompt = $('comboPrompt'); prompt.classList.toggle('on', combo);
    if (combo) { $('comboKey').textContent = comboFrom === 'bansho' ? 'Q · R' : 'R'; $('comboText').textContent = (comboFrom === 'bansho' ? ' 신라천정 · 지폭천성 연계 ' : ' 지폭천성 연계 ') + (comboUntil - now).toFixed(1) + '초'; prompt.style.setProperty('--left', (comboUntil - now) / COMBO_WINDOW * 100 + '%'); }
    $('eBtn').querySelector('.skill-type').textContent = c?.type === 'bansho' && !c.miss ? (c.arrive ? '흑봉 찌르기' : c.cancel ? '끊김' : '끌어당기는 중') : '중앙 12° · 55 · 끌어오기 → 찌르기';
    const d = $('debuff'); d.classList.add('on');
    d.textContent = c?.type === 'chibaku' ? '지폭천성 시전 중 · 받는 피해 -30% · 경직 저항' : c?.type === 'shinra' && now - c.start > CFG.shinra.windup ? '신라천정 반동 · 무방비' : now < afterUntil ? '반동 · 이동 속도 -' + Math.round((1 - afterFactor) * 100) + '% ' + (afterUntil - now).toFixed(1) + '초' : '윤회안 · E → Q / E → R / Q → R 연계';
  }
  function reset() {
    for (const e of fxs.splice(0)) kill(e.obj);
    for (const o of [...live]) kill(o);
    for (const [t] of movers) { calm(t); t.locked = false; t.g.userData.cannonUntil = 0; }
    movers.clear(); for (const t of targets) calm(t); for (const t of extras) calm(t);
    for (const m of sealRock) { m.emissive.setHex(0); m.emissiveIntensity = 0; }
    handOrb.visible = false; if (arms.l.rod) arms.l.rod.visible = false; mRod.emissiveIntensity = 0;
    stopLoops(.05); afterUntil = 0; blurUntil = 0; comboUntil = 0; comboFrom = null; shakeAmp = 0; pushBack = 0; flashV = 0; vign = 0; eye = 0;
    if (blurShown) { blurShown = false; $('scene').style.filter = ''; }
    ovR.style.opacity = ovV.style.opacity = ovF.style.opacity = 0;
  }
  // Extra dummies only exist while Pain is selected, so the other characters keep their original three targets.
  function activate(on) {
    active = on; document.body.classList.toggle('pain', on);
    for (const t of extras) {
      const i = targets.indexOf(t);
      if (on && i < 0) targets.push(t); if (!on && i >= 0) targets.splice(i, 1);
      t.hp = t.max; t.g.visible = on; t.g.position.copy(t.home); t.bar.scale.x = 1; t.bar.position.x = 0; t.locked = false; t.respawn = 0; t.vel = null; t.landed = 0; calm(t);
    }
    arms.r.g.visible = arms.l.g.visible = on;
    if (!on) { $('debuff').textContent = ''; $('debuff').classList.remove('on'); $('eBtn').querySelector('.skill-type').textContent = ''; }
  }
  function state() {
    const c = A.cast;
    return { active, cast: c?.pain ? { type: c.type, age: +(A.time - c.start).toFixed(2), target: c.target?.index ?? null, miss: !!c.miss, cancel: !!c.cancel, arrived: !!c.arrive, captured: c.ch?.captured.map(v => v.t.index) ?? null } : null,
      movers: [...movers].map(([t, m]) => t.index + ':' + m.kind), combo: comboUntil > A.time ? comboFrom : null, speed: +speed().toFixed(2), fx: fxs.length, live: live.size,
      targets: targets.map(t => ({ i: t.index, hp: t.hp, pos: t.g.position.toArray().map(v => +v.toFixed(1)), vis: t.g.visible })) };
  }
  return { begin, update, end, frame, speed, hud, reset, activate, state, skills: new Set(['shinra', 'bansho', 'chibaku']) };
};

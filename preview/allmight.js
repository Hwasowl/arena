// All Might for the browser preview. Timings match roblox/src/ReplicatedStorage/AllMightConfig.luau; distances are
// Roblox studs times S (the preview body is about 0.6 of a Roblox character). Loaded as a classic script before app.js,
// which calls window.AllMightPreview(api) once its scene, targets and helpers exist.
// Everything here is wind pressure, shockwaves, dust, cracks and bodies flying: nothing is drawn as a beam.
window.AllMightPreview = function (A) {
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
    q: { prep: .85, open: .45, dur: 10, prepSpeed: .12, speed: 1.35, basic: 1.25, smash: 1.2, knock: 1.2, taken: .85, fatigue: .85, fatigueDur: 1.2 },
    e: { whiffCd: 9, bumpCd: 6, crouch: .4, dashEnd: .75, windEnd: 1.05, impact: 1.18, punchEnd: 1.35, hold: .35, ret: .3, slow: .7, slowDur: .8,
      dash: 22 * S, reach: 5 * S, width: 3.6 * S, stop: 4.4 * S, damage: 55, knock: 30 * S, lift: 6 * S, knockTime: .55, wall: 8,
      shockR: 12 * S, shock: 18, shockKnock: 9 * S, rCancel: .12 },
    r: { failCd: 30, windup: .65, dashTime: .5, dash: 35 * S, width: 4.2 * S, reach: 4.5 * S, stop: 4.6 * S, fail: .6, windupSpeed: .15,
      punch1: .08, lift: .4, chaseEnd: 1.35, punch2: 1.15, windEnd: 2.05, upper: 2.12, apex: 3.62, settle: 3.85, end: 5.05,
      d1: 20, d2: 15, d3: 75, shockR: 18 * S, shock: 25, liftH: 9 * S, chaseH: 22 * S, casterH: 17 * S, apexH: 140 * S, landAt: 2.95, down: .6 },
  };
  const GOLD = 0xffce40, WIND = 0xeef4ff, SPEED = 0x96c4ff;

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
    heartbeat() { for (const at of [0, .28]) { tone({ f0: 54, f1: 38, dur: .2, vol: .75, at }); noise({ f0: 150, dur: .12, vol: .25, at }); } },
    steam() { noise({ filter: 'highpass', f0: 3200, f1: 5200, dur: .6, vol: .12, attack: .05 }); },
    roar() { tone({ type: 'sawtooth', f0: 92, f1: 70, dur: .9, vol: .3, attack: .05 }); tone({ type: 'sawtooth', f0: 138, f1: 104, dur: .85, vol: .18, attack: .05 }); noise({ filter: 'bandpass', f0: 700, f1: 420, q: 1.5, dur: .9, vol: .35, attack: .05 }); noise({ f0: 1200, f1: 80, dur: .7, vol: .6 }); tone({ f0: 70, f1: 30, dur: .6, vol: .8 }); },
    exhale() { noise({ filter: 'bandpass', f0: 1400, f1: 500, q: .9, dur: .9, vol: .22, attack: .1 }); },
    rumble() { tone({ f0: 42, f1: 36, dur: .5, vol: .55, attack: .12 }); noise({ f0: 160, f1: 90, dur: .5, vol: .25, attack: .12 }); },
    dash() { noise({ filter: 'bandpass', f0: 500, f1: 2200, q: .7, dur: .4, vol: .5 }); tone({ f0: 80, f1: 46, dur: .25, vol: .5 }); },
    suck() { noise({ filter: 'bandpass', f0: 3000, f1: 300, q: 1.2, dur: .3, vol: .3, attack: .15 }); },
    impact() { noise({ f0: 2600, f1: 70, dur: 1.2, vol: 1 }); tone({ f0: 90, f1: 28, dur: 1, vol: 1 }); tone({ type: 'triangle', f0: 240, f1: 60, dur: .3, vol: .3 }); noise({ filter: 'highpass', f0: 3200, dur: .15, vol: .25 }); },
    wind() { noise({ filter: 'bandpass', f0: 1800, f1: 400, q: .6, dur: 1.2, vol: .45, attack: .02 }); },
    thud() { tone({ f0: 120, f1: 44, dur: .25, vol: .6 }); noise({ f0: 700, f1: 200, dur: .2, vol: .4 }); },
    crack() { noise({ filter: 'highpass', f0: rnd(1500, 2600), dur: .18, vol: .25 }); noise({ f0: 500, f1: 120, dur: .3, vol: .25 }); },
    bump() { tone({ f0: 150, f1: 60, dur: .18, vol: .5 }); noise({ f0: 900, f1: 200, dur: .15, vol: .35 }); },
    jab() { tone({ f0: 110, f1: 50, dur: .18, vol: .6 }); noise({ f0: 1600, f1: 300, dur: .2, vol: .45 }); },
    launch() { noise({ filter: 'bandpass', f0: 300, f1: 3200, q: .7, dur: 1.4, vol: .5, attack: .02 }); tone({ f0: 60, f1: 220, dur: 1.2, vol: .3 }); },
    smashLead() { shoutTone(170, 150, .22, .3); shoutTone(190, 160, .2, .3, .25); shoutTone(150, 120, .38, .3, .5); },
    smash() { shoutTone(260, 140, .55, .5); },
    plus() { shoutTone(180, 230, .5, .35); },
    ultra() { shoutTone(300, 150, .8, .55); shoutTone(220, 110, .7, .3, .05); },
  };
  // Optional spoken lines on top (browser speech, only when sound is on); the on-screen text carries the timing.
  function say(text, rate = 1.1, pitch = .55) {
    try { if (A.muted || !window.speechSynthesis) return; const u = new SpeechSynthesisUtterance(text); u.lang = 'en-US'; u.rate = rate; u.pitch = pitch; u.volume = 1; speechSynthesis.cancel(); speechSynthesis.speak(u); } catch (e) { /* no speech */ }
  }

  // ---------- screen overlay: vignette, speed lines, flash, shouts ----------
  const overlay = document.createElement('div'); overlay.id = 'amOverlay';
  overlay.innerHTML = '<i class="av"></i><i class="al"></i><i class="af"></i><b class="at"></b><b class="as"></b><em class="ab"></em>'; document.body.append(overlay);
  const [ovV, ovL, ovF, ovT, ovS, ovB] = overlay.children;
  let shoutText = '', shoutSub = '', shoutAt = -9, shoutLife = 0, shoutColor = '#ffce40';
  function shout(text, life, sub = '', color = '#ffce40') { shoutText = text; shoutSub = sub; shoutAt = A.time; shoutLife = life; shoutColor = color; }

  // ---------- first-person arms: blue suit with white/red bands, muscled forearms, yellow gloves ----------
  const mat = (color, roughness = .55, extra = {}) => new T.MeshStandardMaterial({ color, roughness, metalness: 0, ...extra });
  const mGlove = mat(0xf7c624, .42, { emissive: 0xffb000, emissiveIntensity: 0 }), mGloveDark = mat(0xd9a412, .5);
  const mSuit = mat(0x2d52c4, .5, { emissive: GOLD, emissiveIntensity: 0 }), mMuscle = mat(0x3a63d8, .42, { emissive: GOLD, emissiveIntensity: 0 });
  const mRed = mat(0xc91f2b, .5), mWhite = mat(0xf2f2ec, .5), mSkin = mat(0xf0c39e, .6), mHair = mat(0xffd84a, .45, { emissive: 0x6a4a00, emissiveIntensity: .2 });
  function part(geo, material, parent, pos, rot, scale) {
    const m = new T.Mesh(geo, material); parent.add(m); if (pos) m.position.set(...pos); if (rot) m.rotation.set(...rot); if (scale) m.scale.set(...scale);
    m.renderOrder = 102; m.frustumCulled = false; return m;
  }
  const FING = [[.07, .074, .056, .046], [.024, .082, .06, .05], [-.022, .078, .058, .046], [-.066, .062, .048, .04]];
  function makeArm(side) {
    const g = new T.Group(); camera.add(g); g.visible = false;
    // Glove: a flared gauntlet cuff, a broad padded palm and a knuckle ridge.
    part(new T.CylinderGeometry(.1, .118, .15, 20), mGlove, g, [0, -.05, 0]);
    part(new T.TorusGeometry(.115, .016, 8, 24), mGloveDark, g, [0, -.12, 0], [Math.PI / 2, 0, 0]);
    part(new T.BoxGeometry(.205, .2, .115), mGlove, g, [0, .1, 0]);
    part(new T.SphereGeometry(.1, 14, 10), mGlove, g, [0, .1, .02], null, [1.02, .95, .62]);
    part(new T.CapsuleGeometry(.03, .16, 4, 10), mGloveDark, g, [0, .2, .04], [0, 0, Math.PI / 2]);
    const fingers = [];
    for (let i = 0; i < 4; i++) {
      const [x, a, b, c] = FING[i];
      const j1 = new T.Group(); g.add(j1); j1.position.set(-side * x, .2, 0);
      part(new T.CapsuleGeometry(.029, a - .02, 4, 10), mGlove, j1, [0, a / 2, 0]);
      const j2 = new T.Group(); j1.add(j2); j2.position.y = a;
      part(new T.CapsuleGeometry(.027, b - .02, 4, 10), mGlove, j2, [0, b / 2, 0]);
      const j3 = new T.Group(); j2.add(j3); j3.position.y = b;
      part(new T.CapsuleGeometry(.025, c - .02, 4, 10), mGlove, j3, [0, c / 2, 0]);
      fingers.push({ j1, j2, j3 });
    }
    const thumb = new T.Group(); g.add(thumb); thumb.position.set(-side * .1, .04, -.03);
    part(new T.CapsuleGeometry(.033, .06, 4, 10), mGlove, thumb, [0, .045, 0]);
    const t2 = new T.Group(); thumb.add(t2); t2.position.y = .09;
    part(new T.CapsuleGeometry(.03, .05, 4, 10), mGlove, t2, [0, .035, 0]);
    // Forearm in the tight suit: white and red bands at the wrist, then thick muscle bellies toward the elbow.
    part(new T.CylinderGeometry(.112, .15, .86, 22), mSuit, g, [0, -.55, -.005]);
    part(new T.CylinderGeometry(.118, .118, .05, 22), mWhite, g, [0, -.15, 0]);
    part(new T.CylinderGeometry(.121, .121, .045, 22), mRed, g, [0, -.2, 0]);
    const muscles = [];
    for (const [x, y, z, sx, sy, sz] of [[.075, -.6, .06, .085, .27, .08], [-.005, -.45, .085, .075, .22, .07], [-.08, -.58, -.055, .085, .25, .075], [.02, -.76, -.03, .1, .18, .1]]) {
      const m = part(new T.SphereGeometry(1, 18, 12), mMuscle, g, [side * x, y, z], null, [sx, sy, sz]);
      muscles.push({ m, base: V(sx, sy, sz) });
    }
    part(new T.SphereGeometry(.16, 18, 12), mSuit, g, [0, -.98, -.01]);
    // Upper arm and shoulder live in camera space: they join the elbow to a fixed point near the screen corner.
    const up = new T.Group(); camera.add(up); up.visible = false;
    const upper = part(new T.CylinderGeometry(.2, .17, 1, 22), mSuit, up);
    const bicep = part(new T.SphereGeometry(1, 18, 12), mMuscle, up);
    const stripe = part(new T.CylinderGeometry(.205, .205, .07, 22), mRed, up);
    const deltoid = part(new T.SphereGeometry(.3, 20, 14), mSuit, up);
    g.traverse(o => { o.castShadow = false; o.receiveShadow = false; }); up.traverse(o => { o.castShadow = false; });
    return { g, up, upper, bicep, stripe, deltoid, side, fingers, thumb, t2, muscles };
  }
  const arms = { r: makeArm(1), l: makeArm(-1) };
  // Poses are in camera space: wrist, finger direction, palm normal, curls (index..little, thumb), flex 0..1, shoulder.
  const pose = (pos, fin, palm, curl, flex = 0, sh = [1.0, -1.15, .1]) => ({ pos: V(...pos), fin: V(...fin), palm: V(...palm), curl: typeof curl === 'number' ? [curl, curl, curl, curl, curl] : curl.slice(), flex, sh: V(...sh) });
  const mirror = p => ({ pos: V(-p.pos.x, p.pos.y, p.pos.z), fin: V(-p.fin.x, p.fin.y, p.fin.z), palm: V(-p.palm.x, p.palm.y, p.palm.z), curl: p.curl.slice(), flex: p.flex, sh: V(-p.sh.x, p.sh.y, p.sh.z) });
  function lerpPose(a, b, k) {
    if (k <= 0) return a; if (k >= 1) return b;
    return { pos: a.pos.clone().lerp(b.pos, k), fin: a.fin.clone().lerp(b.fin, k), palm: a.palm.clone().lerp(b.palm, k), curl: a.curl.map((c, i) => mix(c, b.curl[i], k)), flex: mix(a.flex, b.flex, k), sh: a.sh.clone().lerp(b.sh, k) };
  }
  // Fingers close one after another: index first, then middle, ring, little, thumb last.
  const rolling = (k, from = .7, to = 1) => [0, 1, 2, 3, 4].map(i => mix(from, to, ease((k - i * .12) / .5)));
  // Idle: loosely closed fists low at both sides, knuckles forward.
  const REST = pose([.48, -.52, -.98], [-.14, .42, -1], [-1, -.25, 0], [.72, .72, .74, .78, .55], .15, [1.0, -1.2, .1]);
  const L_REST = mirror(REST);
  const Q_CHEST = pose([.17, -.42, -.68], [-.65, .5, -.45], [-.4, -.15, -1], 1, 1, [.85, -1.1, 0]);
  const Q_WAIST = pose([-.46, -.86, -.74], [.2, .65, -.7], [.9, -.2, 0], 1, 1, [-.9, -1.22, .05]);
  const Q_WIDE = pose([1.08, -.42, -.9], [.6, .55, -.55], [0, -.6, -1], 1, 1, [1.12, -1.05, .2]);
  const E_COCK = pose([.78, -.46, -.66], [-.25, .35, -1], [-.3, -1, 0], 1, .8, [1.12, -1.08, .32]);
  const E_DRAW = pose([.96, -.36, -.46], [-.42, .4, -.9], [-.2, -1, 0], 1, 1, [1.18, -1.02, .45]);
  const E_THROW = pose([.04, -.24, -1.5], [0, .06, -1], [0, -1, 0], 1, 1, [.62, -.92, -.42]);
  const E_GUARD = pose([-.38, -.52, -1.0], [.25, .5, -1], [.8, -.4, 0], .9, .5, [-.98, -1.12, .05]);
  const E_TUCK = pose([-.66, -.78, -.62], [.2, .6, -.7], [.9, -.2, 0], 1, .6, [-1.02, -1.1, .3]);
  const E_BUMP = pose([.34, -.4, -.88], [-.1, .3, -1], [0, -1, 0], 1, .6, [.9, -1.05, .05]);
  const R_RAISE = pose([.44, -.08, -.82], [-.15, .8, -.6], [-.8, -.1, -.5], 1, 1, [.98, -1.0, 0]);
  const R_BACK = pose([.88, -.46, -.44], [-.4, .35, -.9], [-.2, -1, 0], 1, 1, [1.16, -1.05, .42]);
  const R_FIRST = pose([.05, -.22, -1.48], [0, .08, -1], [0, -1, 0], 1, 1, [.62, -.9, -.42]);
  const R_UNDER = pose([.66, -1.02, -.66], [-.2, .9, -.3], [-.9, 0, -.3], 1, .8, [1.04, -1.25, .2]);
  const R_JAB = pose([.24, -.16, -1.3], [-.05, .55, -.8], [-.2, -.6, -.6], 1, 1, [.72, -.95, -.3]);
  const R_COIL = pose([.9, -.76, -.4], [-.3, .7, -.6], [-.6, -.5, 0], 1, 1, [1.2, -1.1, .45]);
  const R_SKY = pose([.26, .3, -.88], [-.05, 1, -.15], [-.6, 0, -.8], 1, 1, [.72, -.7, -.1]);
  const R_STUMBLE = pose([.32, -.74, -.74], [0, .2, -1], [0, -1, 0], .8, .3, [.9, -1.2, .05]);
  const L_BRACE = pose([-.62, -.8, -.7], [.2, .6, -.7], [.9, -.2, 0], 1, .8, [-1.06, -1.12, .3]);
  const _m = new T.Matrix4(), _x = V(), _y = V(), _z = V(), _q = new T.Quaternion();
  let glowK = 0, fovBoost = 0, fovOwned = false, meleeFov = 0;
  function poseArm(arm, P, show = true) {
    const vis = show && active; arm.g.visible = arm.up.visible = vis; if (!vis) return;
    const ratio = clamp(camera.aspect, .55, 1), sc = mix(.82, 1, ratio);
    arm.g.position.copy(P.pos); arm.g.position.x *= ratio;
    _y.copy(P.fin).normalize(); _z.copy(P.palm).normalize().negate(); _z.addScaledVector(_y, -_z.dot(_y)).normalize(); _x.crossVectors(_y, _z);
    _m.makeBasis(_x, _y, _z); arm.g.quaternion.setFromRotationMatrix(_m); arm.g.scale.setScalar(sc);
    for (let i = 0; i < 4; i++) {
      const f = arm.fingers[i], c = P.curl[i];
      f.j1.rotation.set(-c * 1.5, 0, 0); f.j2.rotation.x = -c * 1.7; f.j3.rotation.x = -c * 1.15;
    }
    arm.thumb.rotation.set(-.3 - P.curl[4] * .75, 0, arm.side * (.85 - P.curl[4] * .7)); arm.t2.rotation.set(-P.curl[4] * .9, 0, -arm.side * P.curl[4] * .5);
    for (const mu of arm.muscles) mu.m.scale.copy(mu.base).multiplyScalar(1 + .22 * P.flex);
    // Elbow in camera space, then the upper arm stretched to the shoulder; the shoulder lifts as the fist clenches.
    const elbow = arm.g.position.clone().addScaledVector(_y, -.98 * sc);
    const sh = P.sh.clone(); sh.x *= mix(.85, 1, ratio); sh.y += .05 * P.flex;
    const d = sh.clone().sub(elbow), len = d.length(); d.normalize();
    _q.setFromUnitVectors(UP, d);
    arm.upper.position.copy(elbow).addScaledVector(d, len / 2); arm.upper.quaternion.copy(_q); arm.upper.scale.set(1, len, 1);
    arm.stripe.position.copy(elbow).addScaledVector(d, len * .74); arm.stripe.quaternion.copy(_q);
    arm.bicep.position.copy(elbow).addScaledVector(d, len * .42).add(V(0, .07, 0)); arm.bicep.quaternion.copy(_q); arm.bicep.scale.set(.23 * (1 + .25 * P.flex), .3, .25 * (1 + .25 * P.flex));
    arm.deltoid.position.copy(sh).add(V(arm.side * .04, .08, 0)); arm.deltoid.scale.setScalar(1 + .08 * P.flex);
  }

  // ---------- third-person body (shown only in the cinematic): yellow hair with two upright tufts, huge torso ----------
  const body = new T.Group(); scene.add(body); body.visible = false;
  const bpart = (geo, m, parent, pos, rot, scale) => { const x = new T.Mesh(geo, m); parent.add(x); if (pos) x.position.set(...pos); if (rot) x.rotation.set(...rot); if (scale) x.scale.set(...scale); x.castShadow = true; return x; };
  const mPants = mat(0x2a3f9a, .6), mBoot = mat(0xc8a028, .5);
  for (const s of [-1, 1]) { bpart(new T.CylinderGeometry(.17, .13, 1.05, 14), mPants, body, [s * .2, .55, 0]); bpart(new T.BoxGeometry(.24, .16, .36), mBoot, body, [s * .2, .08, -.05]); }
  bpart(new T.CylinderGeometry(.34, .3, .2, 18), mWhite, body, [0, 1.12, 0]);
  const torso = new T.Group(); body.add(torso); torso.position.y = 1.2;
  bpart(new T.CylinderGeometry(.62, .34, .85, 20), mSuit, torso, [0, .45, 0], null, [1, 1, .62]);
  for (const s of [-1, 1]) bpart(new T.SphereGeometry(.3, 16, 12), mMuscle, torso, [s * .22, .62, -.2], null, [1, .7, .55]);
  bpart(new T.BoxGeometry(.5, .07, .05), mRed, torso, [0, .86, -.3]);
  bpart(new T.CylinderGeometry(.12, .14, .16, 12), mSkin, torso, [0, .95, 0]);
  const head = new T.Group(); torso.add(head); head.position.y = 1.12;
  bpart(new T.SphereGeometry(.18, 18, 14), mSkin, head, [0, 0, 0], null, [1, 1.12, 1]);
  bpart(new T.BoxGeometry(.3, .06, .05), mat(0x1a1410, .8), head, [0, .04, -.155]);                 // shadowed eyes
  bpart(new T.BoxGeometry(.2, .05, .03), mWhite, head, [0, -.08, -.165]);                          // the grin
  bpart(new T.SphereGeometry(.2, 16, 12), mHair, head, [0, .1, .03], null, [1.05, .72, 1.05]);
  for (const s of [-1, 1]) {
    // Each tuft: a thick base leaning out, a long thin blade standing almost straight up.
    const tuft = new T.Group(); head.add(tuft); tuft.position.set(s * .07, .2, -.07); tuft.rotation.set(-.12, 0, -s * .3);
    bpart(new T.ConeGeometry(.06, .34, 8), mHair, tuft, [0, .17, 0]);
    bpart(new T.ConeGeometry(.035, .5, 8), mHair, tuft, [s * .02, .5, 0], [0, 0, s * .1]);
  }
  const shoulders = [];
  for (const s of [-1, 1]) {
    const pivot = new T.Group(); torso.add(pivot); pivot.position.set(s * .62, .72, 0);
    bpart(new T.SphereGeometry(.26, 16, 12), mSuit, pivot);
    bpart(new T.CylinderGeometry(.17, .15, .6, 14), mSuit, pivot, [0, -.34, 0]);
    bpart(new T.CylinderGeometry(.15, .17, .07, 14), mRed, pivot, [0, -.5, 0]);
    const elbowG = new T.Group(); pivot.add(elbowG); elbowG.position.y = -.62;
    bpart(new T.CylinderGeometry(.13, .16, .55, 14), mSuit, elbowG, [0, -.27, 0]);
    bpart(new T.SphereGeometry(.15, 14, 10), mGlove, elbowG, [0, -.6, 0], null, [1, 1.1, 1]);
    shoulders.push({ pivot, elbowG, s });
  }
  function poseBody(dir, phase) {
    body.position.copy(basePos).setY(basePos.y - EYE); body.rotation.set(0, Math.atan2(-dir.x, -dir.z), 0);
    const [L, R] = shoulders;
    // phase: 0 neutral, 1 coiled (right fist drawn far back, torso twisted), 2 uppercut (right fist overhead).
    const coil = clamp(phase, 0, 1), up = clamp(phase - 1, 0, 1);
    torso.rotation.y = mix(.55 * coil, -.35, up); torso.rotation.x = mix(.12 * coil, -.12, up);
    R.pivot.rotation.set(mix(-1.2 * coil, -2.9, up), 0, mix(-.25 * coil, -.15, up)); R.elbowG.rotation.x = mix(-1.5 * coil, -.15, up);
    L.pivot.rotation.set(mix(-.9 * coil, .4, up), 0, .3); L.elbowG.rotation.x = mix(-1.2 * coil, -.9, up);
    for (const leg of body.children.slice(0, 4)) leg.rotation.x = 0;
  }

  // ---------- training dummies: extra ones for All Might, movers, reactions ----------
  const extras = [[-2.4, -11.2], [2.6, -11.6], [9, -9], [-9, -7], [-4, -28]].map(([x, z], i) => { const t = A.makeTarget(x, z, 4 + i); t.amOnly = true; return t; });
  for (const t of extras) { targets.splice(targets.indexOf(t), 1); t.g.visible = false; }
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

  // ---------- camera feel ----------
  let shakeAmp = 0, shakeDecay = 10, vign = 0, flashV = 0, flashColor = '255,255,255', lines = 0, linesColor = '255,255,255', contrast = 0;
  function shake(amp, decay = 10) { shakeAmp = Math.max(shakeAmp, amp * (A.comfort ? .3 : 1)); shakeDecay = decay; }
  function screenFlash(power, rgb = '255,255,255') { flashV = Math.max(flashV, power * (A.comfort ? .5 : 1)); flashColor = rgb; }
  function lookAtBlend(point, k, maxPitch = 1.35) {
    if (k <= 0) return;
    const d = point.clone().sub(camera.position), yaw = Math.atan2(-d.x, -d.z), pitch = clamp(Math.atan2(d.y, Math.hypot(d.x, d.z)), -maxPitch, maxPitch);
    let dy = yaw - camera.rotation.y; dy = Math.atan2(Math.sin(dy), Math.cos(dy));
    camera.rotation.y += dy * k; camera.rotation.x = mix(camera.rotation.x, pitch, k);
  }
  // A pulled-back side shot framing both bodies; pulled in front of any pillar between it and the caster.
  function cinematic(target, dir, w) {
    if (w <= 0) return 0;
    const side = V().crossVectors(dir, UP).normalize(), me = basePos.clone().setY(basePos.y - .4), them = target.g.position.clone().setY(target.g.position.y + 1.4);
    const mid = me.clone().lerp(them, .5);
    const want = me.clone().addScaledVector(side, 5.6).addScaledVector(dir, -4.4).add(V(0, .4, 0));
    const toWant = want.clone().sub(me), len = toWant.length(); toWant.normalize();
    let ok = len; for (let s = .3; s <= len; s += .2) { const p = me.clone().addScaledVector(toWant, s); if (inObstacle(p, .3) || Math.hypot(p.x, p.z) > A.arenaR - .5 || p.y < .3) { ok = Math.max(.8, s - .4); break; } }
    const pos = me.clone().addScaledVector(toWant, ok);
    const q = new T.Quaternion().setFromRotationMatrix(new T.Matrix4().lookAt(pos, mid, UP));
    camera.position.lerp(pos, w); camera.quaternion.slerp(q, w);
    return w;
  }

  // ---------- state ----------
  let active = false, buffStart = -9, buffUntil = 0, fatigueUntil = 0, afterUntil = 0, afterFactor = 1, comboUntil = 0, lastCast = null, nextTrail = 0, auraT = 0;
  const buffed = () => A.time < buffUntil;

  // ---------- Q: One For All: Full Power ----------
  function updatePower(c, a) {
    const Q = CFG.q;
    const gather = outP(a / Q.open, 2.2), open = outP((a - Q.open) / .18, 3), settle = ease((a - Q.prep) / .35);
    let R = lerpPose(lerpPose(lerpPose(REST, Q_CHEST, gather), Q_WIDE, open), REST, settle);
    let L = lerpPose(lerpPose(lerpPose(L_REST, Q_WAIST, gather), mirror(Q_WIDE), open), L_REST, settle);
    if (gather < 1 || open < .05) { R = { ...R, curl: rolling(gather, .72, 1) }; L = { ...L, curl: rolling(gather - .05, .72, 1) }; }
    const tremble = gather * (1 - open) * .007; R.pos = R.pos.clone().add(V(Math.sin(A.time * 57) * tremble, Math.cos(A.time * 49) * tremble, 0));
    poseArm(arms.r, R); poseArm(arms.l, L);
    const dip = gather * (1 - open), rise = open * (1 - settle);
    camera.position.y += -.32 * dip + .22 * rise; camera.rotation.x += -.09 * dip + .07 * rise;
    camera.fov = 66 - 6 * dip + 24 * open * (1 - seg(a, Q.open + .15, Q.open + .65)) + 7 * settle;
    vign = Math.max(vign, .55 * dip + .1 * rise); lines = Math.max(lines, .8 * rise); linesColor = '255,214,110';
    glowK = Math.max(glowK, .3 * gather + .7 * open);
    // Small yellow sparks and white steam off the arms while the fists close.
    if (a < Q.open && Math.random() < .5) {
      const at = camera.localToWorld(arms.r.g.position.clone().add(V(rnd(-.1, .1), rnd(-.15, .1), 0)));
      sparks(at, 1, 2.4, .35); if (Math.random() < .35) dust(at, .25, .6, V(rnd(-.2, .2), .8, rnd(-.2, .2)), 0xffffff, .45);
    }
    if (a >= Q.open && !c.flags.open) {
      c.flags.open = true; const feet = basePos.clone().setY(.08);
      ring(feet, UP, 16 * S, WIND, .6, .12, .95, .5); ring(feet.clone().setY(.2), UP, 11 * S, GOLD, .5, .06, .9, .4);
      pressure(basePos.clone().setY(1.2), 5, .45, WIND, .22);
      dustRing(feet, 7, 26, 1.1, 10);
      for (const side of [1, -1]) sparks(camera.localToWorld(V(side * .9, -.4, -.9)), 16, 9, .5);
      screenFlash(.35, '255,226,140'); shake(.12, 9); sfx.roar(); say('Full power!', 1.05, .5);
      shout('ONE FOR ALL — FULL POWER', 1.15, '10초 · 이동 +35% · 기본공격 +25% · E +20% · 받는 피해 -15%');
    }
    if (a >= Q.prep && !c.flags.on) { c.flags.on = true; buffStart = A.time; buffUntil = A.time + Q.dur; fatigueUntil = 0; }
  }

  // ---------- E: United States of Smash ----------
  function updateSmash(c, a, dt) {
    const E = CFG.e, dir = c.dir;
    const crouch = outP(a / E.crouch, 2), dash = seg(a, E.crouch, E.dashEnd);
    const draw = outP((a - E.dashEnd) / (E.windEnd - E.dashEnd), 2), punch = outP((a - E.windEnd) / (E.impact - E.windEnd), 3.2);
    const holdEnd = E.punchEnd + E.hold, back = ease((a - holdEnd) / E.ret);
    // Dash: real movement along the floor; the first body ahead stops it, a pillar bumps it.
    if (a >= E.crouch && !c.flags.dash) {
      c.flags.dash = true; c.from = basePos.clone(); c.wall = wallAlong(c.from.clone().setY(0), dir, E.dash, .55);
      sfx.dash(); dustRing(basePos.clone().setY(0), 3, 10, .6, 3, dir.clone().negate());
    }
    if (c.flags.dash && !c.contact && !c.bump && !c.whiff && a < E.dashEnd) {
      const along = E.dash * outP(dash, 1.7);
      if (c.wall && along >= c.wall.d) {
        c.bump = a; basePos.copy(c.from).addScaledVector(dir, c.wall.d); A.cooldowns.smash = A.time + E.bumpCd; c.duration = a + .45;
        sfx.bump(); shake(.06, 14); dustRing(c.wall.point.clone().setY(0), 2, 8, .6, 3); ring(c.wall.point, c.wall.normal, 1.6, WIND, .3, .05);
        A.toast('벽에 막혀 스매시가 끊겼습니다 · 재사용 6초');
      } else {
        basePos.copy(c.from).addScaledVector(dir, along);
        const t = firstAhead(basePos, dir, E.reach, E.width);
        if (t) {
          c.contact = a; c.target = t;
          const stop = t.g.position.clone().setY(basePos.y).addScaledVector(dir, -E.stop);
          if (stop.clone().sub(c.from).dot(dir) > along) basePos.copy(stop);
          handoff(t, { kind: 'hold', drop: () => { c.lost = true; } });
        }
        // White wind pressure around the body and dust kicked up behind; no camera shake while dashing.
        for (let i = 0; i < 3; i++) { const o = camera.localToWorld(V(rnd(-1.6, 1.6), rnd(-1, 1), rnd(-2.5, -1))); streak(o, dir.clone().negate(), rnd(1.2, 2.6), 26, .2, WIND, .03, .7); }
        if (Math.random() < .6) dust(basePos.clone().setY(.3).addScaledVector(dir, -.6), 1.2, .5, dir.clone().multiplyScalar(-3).setY(.8));
      }
    }
    if (!c.contact && !c.bump && !c.whiff && a >= E.dashEnd) { c.whiff = true; A.cooldowns.smash = c.start + E.whiffCd; }
    if (c.target && movers.get(c.target)?.kind === 'hold' && !c.flags.impact) { setTilt(c.target, dir, -.12); flail(c.target, .25); }
    // Poses: cocked right fist at the screen's right, left guard; the wind-up draws it further back, then the punch.
    let R = lerpPose(lerpPose(lerpPose(lerpPose(REST, E_COCK, crouch), E_DRAW, draw), E_THROW, punch), REST, back);
    let L = lerpPose(lerpPose(lerpPose(L_REST, E_GUARD, crouch), E_TUCK, punch), L_REST, back);
    if (c.bump) { const k = a - c.bump; R = lerpPose(R, E_BUMP, ease(k / .06) * (1 - ease((k - .12) / .3))); }
    poseArm(arms.r, R); poseArm(arms.l, L);
    const low = crouch * (1 - back), twist = .15 * draw * (1 - punch) - .11 * punch * (1 - back);
    camera.position.y -= .55 * low; camera.rotation.y += twist; camera.rotation.z += -.05 * draw * (1 - punch) + .04 * punch * (1 - back); camera.rotation.x -= .03 * low;
    camera.fov = (66 - 8 * crouch * (1 - dash) + 16 * dash * (1 - draw) - 6 * draw * (1 - punch) + 18 * punch * (1 - seg(a, E.impact, E.impact + .4))) * (1 - back) + 66 * back;
    vign = Math.max(vign, .6 * crouch * (1 - dash) + .4 * draw * (1 - punch));
    if (dash > 0 && dash < 1 && !c.bump) { lines = Math.max(lines, .9); linesColor = '255,255,255'; }
    glowK = Math.max(glowK, (c.buffed ? 1 : .55) * (.4 * crouch + .6 * draw) * (1 - back));
    // Gold energy gathering into the right fist while crouched; compressing (a tight bright knot) during the wind-up.
    const fist = camera.localToWorld(arms.r.g.position.clone().add(V(0, .12, 0)));
    if (a < E.windEnd && Math.random() < (c.buffed ? .9 : .5)) { const o = V(rnd(), rnd(), rnd()).normalize().multiplyScalar(rnd(.6, 1.2)); streak(fist.clone().add(o), o.clone().negate(), .25, 4, .22, GOLD, .03, 1); }
    if (a >= E.dashEnd && a < E.impact && !c.flags.compress) { c.flags.compress = true; glowAt(fist, GOLD, .5, E.impact - E.dashEnd, -.6, .9); sfx.suck(); }
    if (a >= E.dashEnd + .02 && !c.flags.call && !c.bump) { c.flags.call = true; shout('UNITED STATES OF...', E.impact - E.dashEnd + .12, '', '#ffce40'); sfx.smashLead(); say('United States of', 1.35, .5); }
    if (a >= E.impact && !c.flags.impact && !c.bump) { c.flags.impact = true; smashImpact(c); }
    if (c.flags.impact && c.hit) {
      const k = 1 - ease((a - E.impact - .05) / .3); flashV = Math.max(flashV, .35 * k * k * (A.comfort ? .5 : 1)); lines = Math.max(lines, k); contrast = Math.max(contrast, .4 * k);
    }
    // Steam off the extended arm while it is held out.
    if (c.flags.impact && a < holdEnd + .1 && Math.random() < .7) dust(camera.localToWorld(V(rnd(-.05, .1), rnd(-.2, -.05), -1.5)), .35, .7, V(rnd(-.2, .2), .9, rnd(-.2, .2)), 0xffffff, .5);
  }
  function smashImpact(c) {
    const E = CFG.e, dir = c.dir, t = c.target, factor = buffed() ? CFG.q.smash : 1, big = c.buffed ? 1.25 : 1;
    const point = t && alive(t) && !c.lost ? t.g.position.clone().setY(1.4) : basePos.clone().addScaledVector(dir, 2).setY(1.4);
    c.hit = !!(t && alive(t) && !c.lost && t.g.position.distanceTo(basePos.clone().setY(0)) <= E.reach + E.stop + 1.5);
    pressure(point, (c.hit ? 2.4 : 1.6) * big, .3, WIND, .22);
    ring(point, dir, 5.5 * big, WIND, .42, .1, .95); ring(point.clone().addScaledVector(dir, 1.2), dir, 8 * big, c.buffed ? GOLD : WIND, .5, .06, .85);
    for (let i = 0; i < (c.hit ? 26 : 14); i++) { const d = dir.clone().add(V(rnd(-.35, .35), rnd(-.2, .25), rnd(-.35, .35))).normalize(); streak(point.clone().addScaledVector(d, .6), d, rnd(2, 4.5), rnd(30, 48), .32, i % 3 || !c.buffed ? WIND : GOLD, .06, .9); }
    sfx.wind();
    if (!c.hit) { shake(.03, 12); A.toast('스매시가 빗나갔습니다 · 재사용 9초'); return; }
    // All at once: the shout, white flash, shockwave, cracks, the body bending, a strong shake, impact and wind.
    shout('SMASH!', 1, 'UNITED STATES OF SMASH', c.buffed ? '#ffce40' : '#ffffff'); sfx.smash(); say('Smash!', 1.2, .6);
    screenFlash(.5); A.flash(c.buffed ? '#ffe7a0' : '#ffffff', .22); shake(.32, 6); A.hitstop(80); sfx.impact();
    glowAt(point, 0xffffff, 3, .25, 3, 1);
    ring(t.g.position.clone().setY(.08), UP, E.shockR * big, WIND, .55, .1, .95, .8);
    cracks(t.g.position.clone().addScaledVector(dir, -.6), 4.2 * big, 13, 4.5, dir, 1.5);
    dustRing(t.g.position, 5 * big, 22, 1.2, c.buffed ? 18 : 12, dir);
    if (c.buffed) sparks(point, 26, 14, .5);
    hit(t, E.damage * (buffed() ? CFG.q.smash : 1), c.buffed ? '#ffd76a' : '#ffffff');
    if (t.hp > 0) knock(t, dir, E.knock, E.lift, E.knockTime, E.wall, true);
    for (const o of targets) {
      if (o === t || !alive(o)) continue;
      if (o.g.position.distanceTo(t.g.position) <= E.shockR) {
        hit(o, E.shock * factor, '#e6eeff');
        if (o.hp > 0) { const d = o.g.position.clone().sub(t.g.position).setY(0); if (d.lengthSq() < .01) d.copy(dir); knock(o, d.normalize(), E.shockKnock, .5, .35, 0, false); }
      }
    }
    comboUntil = A.time + (E.punchEnd + E.hold + E.ret - E.impact);
  }

  // ---------- R: Plus Ultra ----------
  function beginUltra(c) {
    const R = CFG.r;
    c.dir = A.flatForward(); c.duration = R.windup + R.dashTime + R.end + .3; c.buffed = buffed();
    A.title('PLUS ULTRA', 'PLUS ULTRA!', '돌진 → 띄우기 → 공중 추격 → 어퍼컷으로 하늘 끝까지 · 본체 110 · 주변 25', '#ffce40');
    sfx.rumble(); sfx.heartbeat(); shoutAt = -9;
  }
  function ultraPose(c, k) {
    const R = CFG.r, d = c.dir;
    const lift = outP((k - R.punch1) / (R.lift - R.punch1), 2), chase = outP((k - R.lift) / (R.chaseEnd - R.lift), 2.2), hang = seg(k, R.chaseEnd, R.upper);
    let up = R.casterH * chase + .5 * hang;
    if (k >= R.upper) { const rise = outP((k - R.upper) / .18, 2) * 1.3, f = seg(k, R.upper + .22, R.landAt); up = (R.casterH + .5 + rise) * (1 - f * f); }
    const me = c.base.clone().addScaledVector(d, 1.3 * chase).setY(EYE + up);
    let them = c.contactPoint.clone().addScaledVector(d, Math.min(c.drift, 1.6 * lift + 1 * chase)).setY(R.liftH * lift + (R.chaseH - R.liftH) * chase + .7 * hang);
    if (k >= R.upper) { const u = seg(k, R.upper, R.apex), from = c.launchFrom || them; them = from.clone().addScaledVector(d, Math.min(c.drift2, 4.2 * u)).setY(from.y + c.apexRise * u * u); }
    return { me, them };
  }
  function updateUltra(c, a, dt) {
    const R = CFG.r, dir = c.dir;
    const gather = outP(a / R.windup, 2);
    // Windup: big slowdown, right fist rises, head tilts down, gold sparks and white air gather, pebbles pushed out.
    if (!c.flags.dash) {
      poseArm(arms.r, { ...lerpPose(REST, R_RAISE, gather), curl: rolling(gather) }); poseArm(arms.l, lerpPose(L_REST, L_BRACE, gather));
      camera.rotation.x -= .12 * gather; camera.fov = 66 - 8 * gather; vign = Math.max(vign, .5 * gather); glowK = Math.max(glowK, gather * (c.buffed ? 1 : .7));
      const fist = camera.localToWorld(arms.r.g.position.clone().add(V(0, .14, 0)));
      if (Math.random() < .8) { const o = V(rnd(), rnd(), rnd()).normalize().multiplyScalar(rnd(.8, 1.5)); streak(fist.clone().add(o), o.clone().negate(), rnd(.3, .6), 5, .25, Math.random() < .5 ? GOLD : WIND, .03, 1); }
      if (!c.flags.pebbles) { c.flags.pebbles = true; dustRing(basePos.clone().setY(0), 2.2, 16, R.windup + .4, 12); say('Plus', .9, .5); }
      if (c.buffed && Math.random() < .5) sparks(basePos.clone().setY(rnd(.5, 1.5)).add(V(rnd(-1, 1), 0, rnd(-1, 1))), 1, 3, .4);
    }
    if (a >= R.windup && !c.flags.dash) {
      c.flags.dash = true; c.from = basePos.clone(); c.empty = !firstAhead(basePos, dir, R.dash + R.reach, R.width);
      c.limit = c.empty ? R.dash * R.fail : R.dash; const wall = wallAlong(c.from.clone().setY(0), dir, c.limit, .55); if (wall) c.limit = wall.d;
      const feet = basePos.clone().setY(0);
      cracks(feet, 2.6, 10, 4, dir.clone().negate(), .8); dustRing(feet, 4.5, 20, .9, 10, dir.clone().negate()); ring(feet.clone().setY(.08), UP, 5, WIND, .4, .08);
      sfx.dash(); sfx.impact(); shake(.05, 12);
    }
    if (!c.flags.dash) return;
    if (c.flags.dash && !c.contact && !c.fail) {
      const k = seg(a, R.windup, R.windup + R.dashTime);
      const along = c.limit * (c.empty ? outP(k, 2.4) : outP(k, 1.5));
      basePos.copy(c.from).addScaledVector(dir, along);
      const t = c.empty ? null : firstAhead(basePos, dir, R.reach, R.width);
      poseArm(arms.r, lerpPose(R_RAISE, R_BACK, outP(k / .4, 2))); poseArm(arms.l, L_BRACE);
      camera.fov = 58 + 26 * outP(k, 2); lines = Math.max(lines, 1); linesColor = '160,200,255'; glowK = Math.max(glowK, .8);
      for (let i = 0; i < 4; i++) { const o = camera.localToWorld(V(rnd(-1.8, 1.8), rnd(-1.1, 1.1), rnd(-3, -1))); streak(o, dir.clone().negate(), rnd(1.6, 3.4), 34, .2, Math.random() < .4 ? SPEED : WIND, .035, .8); }
      if (Math.random() < .7) dust(basePos.clone().setY(.3).addScaledVector(dir, -.8), 1.4, .6, dir.clone().multiplyScalar(-4).setY(1));
      if (t) startUltra(c, t, a);
      else if (k >= 1) failUltra(c, a);
      return;
    }
    if (c.fail) {
      const k = a - c.fail;
      poseArm(arms.r, lerpPose(R_BACK, R_STUMBLE, ease(k / .2))); poseArm(arms.l, lerpPose(L_BRACE, L_REST, ease(k / .4)));
      camera.rotation.x -= .08 * bump(k, 0, .5); camera.rotation.z += .05 * bump(k, 0, .5); camera.position.y -= .15 * bump(k, 0, .5);
      return;
    }
    // ---- after contact: everything is measured from the moment the dash connected ----
    const k = a - c.contact, t = c.target;
    if (!alive(t) && !c.lost) { c.lost = true; c.duration = a + .6; A.toast('대상이 쓰러졌습니다'); }
    const { me, them } = ultraPose(c, k);
    if (k < R.landAt) basePos.copy(me);
    else if (!c.flags.land) {
      c.flags.land = true; basePos.y = EYE;
      cracks(basePos.clone().setY(0), 4, 14, 5); dustRing(basePos, 6, 22, 1.6, 8); ring(basePos.clone().setY(.08), UP, 6, WIND, .5, .09); sfx.thud(); shake(.1, 9);
    }
    if (c.lost) { if (basePos.y > EYE) basePos.y = Math.max(EYE, basePos.y - dt * 14); poseArm(arms.r, REST); poseArm(arms.l, L_REST); return; }
    // Target: lifted, arched back, carried up ahead of the caster, then launched skyward (real accelerating motion).
    const m = movers.get(t);
    if (k < R.apex && m?.kind === 'ultra') {
      t.g.position.copy(them);
      const arch = k < R.upper ? -.9 * ease(seg(k, R.punch1, R.punch1 + .2)) : mix(.9, -.6, ease(seg(k, R.upper, R.upper + .3)));
      setTilt(t, dir, arch); flail(t, k >= R.punch1 ? 1 : .2); squash(t, Math.max(0, 1 - Math.abs(k - R.punch1) * 10) + Math.max(0, 1 - Math.abs(k - R.upper) * 8));
      if (k >= R.upper) { t.g.rotation.y += dt * 14; }
    }
    // Hits, once each.
    if (k >= R.punch1 && !c.flags.p1) {
      c.flags.p1 = true; const p = t.g.position.clone().setY(1.4);
      hit(t, R.d1, '#ffffff'); sfx.impact(); sfx.jab(); shake(.22, 8); A.hitstop(50); screenFlash(.4);
      pressure(p, 2.6, .35, WIND, .24); ring(p, dir, 7, WIND, .45, .1, .95); ring(p, dir, 4.2, WIND, .35, .06, .8, .2);
      cracks(t.g.position.clone(), 3.4, 11, 5, dir, 1); dustRing(t.g.position, 4.5, 18, 1.1, 10, dir);
      for (let i = 0; i < 18; i++) { const d = dir.clone().add(V(rnd(-.4, .4), rnd(-.1, .5), rnd(-.4, .4))).normalize(); streak(p, d, rnd(2, 4), 36, .3, WIND, .06, .9); }
      lightBurst();
    }
    if (k >= R.punch2 && !c.flags.p2) {
      c.flags.p2 = true; const p = t.g.position.clone().setY(t.g.position.y + 1.4);
      hit(t, R.d2, '#ffffff'); sfx.jab(); shake(.08, 12); screenFlash(.3);
      ring(p, dir.clone().add(V(0, 1.2, 0)).normalize(), 3.6, WIND, .3, .06, .9);
    }
    if (k >= R.upper && !c.flags.up) { c.flags.up = true; uppercut(c, t); }
    if (k >= R.apex && !c.flags.apex) {
      c.flags.apex = true;
      const p = t.g.position.clone().setY(t.g.position.y + 1.2);
      ring(p, UP, 16, WIND, .8, .2, .95, 2); ring(p, UP, 11, GOLD, .7, .12, .9, 1.5); ring(p, dir, 9, WIND, .6, .1, .8, 1);
      glowAt(p, 0xffffff, 8, .8, 2.5, 1); glowAt(p, 0xfff0c0, 18, 1, 1, .7); sfx.impact();
      if (c.star) { kill(c.star); c.star = null; }
      // From the apex the body falls back onto safe ground under its own weight, then lies down.
      release(t); fall(t, dir, V(0, 0, 0), R.down, 62);
    }
    // ---- caster arms ----
    const punch1 = outP(k / R.punch1, 3), wind = seg(k, R.chaseEnd, R.windEnd), upper = outP((k - R.windEnd) / (R.upper - R.windEnd), 3);
    const sky = seg(k, R.upper + .15, R.settle), lower = ease((k - R.settle - .35) / (R.end - R.settle - .35));
    let P = lerpPose(R_BACK, R_FIRST, punch1);
    P = lerpPose(P, R_UNDER, ease(seg(k, R.lift - .1, R.lift + .25)));
    P = lerpPose(P, R_JAB, bump(k, R.punch2 - .1, R.punch2 + .12));
    P = lerpPose(P, R_COIL, outP(wind / .6, 2));
    P = lerpPose(P, R_SKY, upper);
    P = lerpPose(P, REST, lower);
    const L = lerpPose(lerpPose(L_BRACE, L_BRACE, 0), L_REST, lower);
    // ---- camera: assist toward the target in the chase, a short cinematic for wind-up and uppercut, then look up ----
    const assist = ease(seg(k, R.lift - .1, R.lift + .3)) * (1 - ease(seg(k, R.upper + .15, R.upper + .45)));
    const chest = t.g.position.clone().setY(t.g.position.y + 1.3);
    if (assist > 0) lookAtBlend(chest, .6 * assist, 1.2);
    const skyLook = ease(seg(k, R.upper + .1, R.upper + .5)) * (1 - ease(seg(k, R.settle + .2, R.end)));
    if (skyLook > 0) lookAtBlend(c.flags.apex ? c.apexPoint : chest, skyLook, 1.38);
    const cineW = ease(seg(k, R.chaseEnd - .05, R.chaseEnd + .3)) * (1 - ease(seg(k, R.upper + .08, R.upper + .42)));
    cinematic(t, dir, cineW); c.cine = cineW;
    body.visible = cineW > .3; poseBody(dir, k < R.upper ? outP(wind / .6, 2) : 1 + upper);
    poseArm(arms.r, P, cineW <= .3); poseArm(arms.l, L, cineW <= .3);
    let fov = 84 - 12 * seg(k, R.lift, R.chaseEnd) - 12 * wind + 28 * upper;
    fov = fov * (1 - sky) + 72 * sky; camera.fov = fov * (1 - lower) + 66 * lower;
    if (cineW > .01) camera.fov = mix(camera.fov, 58, cineW);
    vign = Math.max(vign, .45 * wind * (1 - upper) + .15 * seg(k, R.lift, R.chaseEnd));
    lines = Math.max(lines, seg(k, R.lift, R.chaseEnd) * .7 * (1 - wind), upper * (1 - sky)); linesColor = k >= R.upper ? '255,214,110' : '255,255,255';
    glowK = Math.max(glowK, (1 - lower) * (c.buffed ? 1 : .8));
    if (k >= R.chaseEnd && !c.flags.plus) { c.flags.plus = true; shout('PLUS...', R.upper - R.chaseEnd + .06, '', '#ffce40'); sfx.heartbeat(); sfx.plus(); }
    // Wind and speed lines around both bodies while they rise.
    if (k > R.lift && k < R.upper && Math.random() < .8) { for (const p of [basePos.clone().setY(basePos.y - 1), t.g.position.clone().setY(t.g.position.y + 1)]) streak(p.add(V(rnd(-1.2, 1.2), rnd(-1, 1), rnd(-1.2, 1.2))), V(0, -1, 0), rnd(1.5, 3), 14, .25, WIND, .04, .7); }
    // Rising body: a white air trail and layered rings left behind, then a small light in the sky.
    if (k >= R.upper && k < R.apex) {
      const p = t.g.position.clone().setY(t.g.position.y + 1.2);
      if (c.lastTrail) { const step = p.clone().sub(c.lastTrail); if (step.length() > .05) streak(c.lastTrail.clone().lerp(p, .5), step, step.length() * 1.6 + 1.5, 0, .5, WIND, .5 + 1.8 * seg(k, R.upper, R.apex), .7); }
      c.lastTrail = p;
      if (A.time >= nextTrail) { nextTrail = A.time + .11; ring(p.clone().setY(p.y - 1.4), UP, 2.6 + 6 * seg(k, R.upper, R.apex), Math.random() < .3 ? GOLD : WIND, .5, .09, .85, 1.2); }
      if (c.star) { c.star.position.copy(p); c.star.material.opacity = seg(k, R.upper + .5, R.apex); c.star.scale.setScalar(3 + 3 * seg(k, R.upper + .5, R.apex)); }
      c.apexPoint = p.clone();
    }
    // Steam from the raised fist while it is held to the sky.
    if (k > R.upper && k < R.end && Math.random() < .5) dust(camera.localToWorld(V(rnd(.15, .35), rnd(.2, .45), -.9)), .3, .8, V(rnd(-.2, .2), 1, rnd(-.2, .2)), 0xffffff, .5);
    if (k >= R.end && !c.flags.done) { c.flags.done = true; c.duration = a + .05; }
  }
  // A burst of light lines from the screen centre (first punch).
  let burstK = 0;
  function lightBurst() { burstK = 1; }
  function startUltra(c, t, a) {
    const R = CFG.r, dir = c.dir;
    c.contact = a; c.target = t; c.contactPoint = t.g.position.clone().setY(0);
    const stop = c.contactPoint.clone().addScaledVector(dir, -R.stop).setY(EYE);
    if (stop.clone().sub(c.from).dot(dir) > basePos.clone().sub(c.from).dot(dir)) basePos.copy(stop);
    c.base = basePos.clone().setY(0);
    // Room to drift forward before a pillar, for the lift and for the launch.
    const w1 = wallAlong(c.contactPoint, dir, 3), w2 = wallAlong(c.contactPoint, dir, 9);
    c.drift = w1 ? Math.max(0, w1.d - .4) : 3; c.drift2 = w2 ? Math.max(0, w2.d - c.drift - .4) : 4.2;
    c.apexRise = R.apexH; c.duration = a + R.end + .1;
    A.cooldowns.ultra = c.start + 85;
    handoff(t, { kind: 'ultra', drop: () => { c.lost = true; } });
  }
  function failUltra(c, a) {
    c.fail = a; c.duration = a + .7; A.cooldowns.ultra = c.start + CFG.r.failCd;
    dustRing(basePos.clone().setY(0), 2.5, 12, .8, 4, c.dir); sfx.thud();
    A.toast('PLUS ULTRA · 돌진 경로에 적이 없음 · 재사용 30초');
  }
  function uppercut(c, t) {
    const R = CFG.r, dir = c.dir, p = t.g.position.clone().setY(t.g.position.y + 1.2);
    c.launchFrom = t.g.position.clone();
    hit(t, R.d3, '#ffe18a');
    // All at once: "PLUS ULTRA!!!", white/gold flash, ring, the body folding and flying up, a wind column, the ground
    // shockwave with dust, a strong shake, speed lines and high contrast, and a 0.12 s hitstop.
    shout('PLUS ULTRA!!!', 1.7, '', '#ffce40'); sfx.ultra(); say('Ultra!', 1.1, .65);
    screenFlash(1, '255,244,205'); A.flash('#fff1c4', .4); shake(.42, 5); A.hitstop(120); sfx.impact(); sfx.launch(); sfx.wind();
    pressure(p, 4, .45, WIND, .24); ring(p, UP, 12, WIND, .55, .16, .95, 1); ring(p, UP, 7.5, GOLD, .45, .1, .95, .8); ring(p, dir.clone().add(V(0, 2, 0)).normalize(), 9, WIND, .5, .1, .8);
    glowAt(p, 0xffffff, 6, .35, 3, 1); sparks(p, c.buffed ? 60 : 36, 16, .6);
    const ground = c.base.clone();
    ring(ground.clone().setY(.1), UP, R.shockR, WIND, .7, .14, .95, 1);
    cracks(ground, 6.5, 16, 6); dustRing(ground, 9, 30, 1.8, 16);
    // Wind column: stacked translucent cylinders spinning up along the punch.
    const col = new T.Group(); col.position.copy(p);
    for (let i = 0; i < 7; i++) { const m = new T.Mesh(new T.CylinderGeometry(1, 1, 5, 24, 1, true), new T.MeshBasicMaterial({ color: i % 2 ? GOLD : WIND, transparent: true, opacity: .32, depthWrite: false, side: T.DoubleSide, blending: T.AdditiveBlending })); m.userData.i = i; col.add(m); }
    fx(col, 1, (o, u) => { for (const m of o.children) { const i = m.userData.i; m.position.y = i * 5 + 26 * ease(u * 1.4); const r = (i % 2 ? 1 : 1.8) * (1 - u * .5); m.scale.set(r, 1, r); m.rotation.y = u * 9 * (i % 2 ? -1 : 1); m.material.opacity = .32 * (1 - u); } });
    for (const o of targets) {
      if (o === t || !alive(o)) continue; const d = o.g.position.clone().sub(ground).setY(0);
      if (d.length() <= R.shockR) { hit(o, R.shock, '#e6eeff'); if (o.hp > 0) knock(o, d.lengthSq() > .01 ? d.normalize() : dir.clone(), 4, 1.5, .45, 0, false); }
    }
    c.star = keep(sprite(glowTex, 0xffffff, 0, true)); c.star.scale.setScalar(3);
  }

  // ---------- app hooks ----------
  function begin(c) {
    c.allmight = true; c.flags = c.flags || {}; lastCast = c;
    if (c.type === 'ofa') {
      c.duration = CFG.q.prep + .45; sfx.heartbeat();
      A.title('ONE FOR ALL', '원 포 올 · 풀 파워', '0.85초 준비 → 10초 강화 · 이동 +35% · 기본공격 +25% · E +20% · 받는 피해 -15%', '#ffce40');
    }
    if (c.type === 'smash') {
      c.dir = A.flatForward(); c.buffed = buffed(); c.duration = CFG.e.punchEnd + CFG.e.hold + CFG.e.ret; sfx.rumble();
      A.title('UNITED STATES OF SMASH', 'UNITED STATES OF SMASH', '웅크림 → 22 돌진 → 회전 펀치 · 55 피해 · 충격파 반경 12 · 18' + (c.buffed ? ' · 풀 파워 +20%' : ''), '#ffce40');
    }
    if (c.type === 'ultra') beginUltra(c);
  }
  function update(c, a, dt) {
    const fov0 = camera.fov;
    if (c.type === 'ofa') updatePower(c, a, dt);
    else if (c.type === 'smash') updateSmash(c, a, dt);
    else if (c.type === 'ultra') updateUltra(c, a, dt);
    fovOwned = camera.fov !== fov0;
  }
  function end(c) {
    if (c.type === 'smash') {
      if (c.target && movers.get(c.target)?.kind === 'hold') release(c.target);
      if (!c.bump && !c.cancelled) { afterUntil = A.time + CFG.e.slowDur; afterFactor = CFG.e.slow; }
    }
    if (c.type === 'ultra') {
      const t = c.target;
      if (t && movers.get(t)?.kind === 'ultra') { release(t); if (t.hp > 0) fall(t, c.dir, V(), CFG.r.down, 40); }
      if (c.star) { kill(c.star); c.star = null; }
      body.visible = false; comboUntil = 0;
      if (basePos.y > EYE) landTo(EYE);
    }
    lastCast = null;
  }
  // Brings the caster down if a cast ended in the air.
  let landing = null;
  function landTo(y) { landing = { y }; }
  // E -> R: R may cancel the smash's follow-through once the fist has landed.
  function canCancel(type) {
    const c = A.cast; if (!c?.allmight || type !== 'ultra' || c.type !== 'smash' || !c.hit) return false;
    return A.time - c.start >= CFG.e.impact + CFG.e.rCancel && A.cooldowns.ultra <= A.time;
  }
  function cancel(c) { c.cancelled = true; end(c); }
  function frame(dt, moving) {
    const c = A.cast, now = A.time;
    if (landing) { basePos.y = Math.max(landing.y, basePos.y - dt * 16); if (basePos.y <= landing.y) landing = null; }
    // Idle and running arms: loose fists, a big pumping swing while running, the body lowered a little.
    if (active && !c?.allmight) {
      const m = A.melee, run = moving ? 1 : 0, sw = moving ? Math.sin(now * (buffed() ? 12 : 10)) : 0, idle = Math.sin(now * 1.7) * .01;
      const R = lerpPose(REST, REST, 0), L = lerpPose(L_REST, L_REST, 0);
      R.pos = R.pos.clone().add(V(0, idle + .07 * Math.max(0, sw) * run - .04 * run, -.26 * sw * run)); R.fin = R.fin.clone().add(V(0, .25 * sw * run, 0));
      L.pos = L.pos.clone().add(V(0, idle + .07 * Math.max(0, -sw) * run - .04 * run, .26 * sw * run)); L.fin = L.fin.clone().add(V(0, -.25 * sw * run, 0));
      R.sh = R.sh.clone().add(V(0, 0, .14 * sw * run)); L.sh = L.sh.clone().add(V(0, 0, -.14 * sw * run));
      if (moving) { camera.position.y -= .1; camera.rotation.x -= .03; camera.rotation.z += sw * .006; }
      if (m) {
        // Heavy straight punches, the shoulder driving through.
        const a = now - m.start, wind = ease(a / m.windup), strike = outP((a - m.windup) / m.swing, 3), back = ease((a - m.windup - m.swing) / Math.max(.05, m.duration - m.windup - m.swing));
        const side = m.combo % 2 ? 1 : -1, rest = side > 0 ? R : L;
        const cock = pose([side * .7, -.62, -.64], [-side * .15, .2, -1], [-side * .3, -1, 0], 1, .7, [side * 1.08, -1.1, .3]);
        const hitP = pose([side * .1, -.32, -1.45], [0, .05, -1], [0, -1, 0], 1, 1, [side * .78, -.95, -.25]);
        const P = lerpPose(lerpPose(lerpPose(rest, cock, wind), hitP, strike), rest, back);
        if (side > 0) poseArm(arms.r, P), poseArm(arms.l, L); else poseArm(arms.l, P), poseArm(arms.r, R);
        meleeFov = 4 * strike * (1 - back);
      } else {
        if (A.sliding) { R.pos.y -= .1; L.pos.y -= .1; }
        poseArm(arms.r, R); poseArm(arms.l, L);
      }
    }
    if (!active) { arms.r.g.visible = arms.l.g.visible = arms.r.up.visible = arms.l.up.visible = false; body.visible = false; }
    // One For All: gold glow on the gloves and suit, gold sparks and wind off the arms, afterimages while running.
    const on = buffed();
    // FOV additions are re-applied every frame on top of the app's own easing, so remove last frame's share first.
    let boost = meleeFov; meleeFov = 0;
    if (active && on && !(c?.allmight && c.cine)) boost += 7 * ease((now - buffStart) / .4) * ease((buffUntil - now) / .4);
    if (!fovOwned) camera.fov -= fovBoost * (1 - Math.min(1, dt * 7));
    camera.fov += boost; fovBoost = boost; fovOwned = false;
    if (active && on) {
      glowK = Math.max(glowK, .55 + .25 * Math.sin(now * 14));
      auraT += dt;
      if (auraT > .05) {
        auraT = 0;
        for (const arm of [arms.r, arms.l]) {
          if (!arm.g.visible) continue;
          const at = camera.localToWorld(arm.g.position.clone().add(V(rnd(-.12, .12), rnd(-.3, .15), rnd(-.1, .1))));
          streak(at, V(rnd(), rnd(.2, 1), rnd()).normalize(), rnd(.15, .35), rnd(1, 3), .3, GOLD, .025, 1);
          if (moving) glowAt(at, GOLD, .22, .28, -.5, .55);          // afterimage left behind as you run
        }
        if (moving) { dust(basePos.clone().setY(.25).add(V(rnd(-.4, .4), 0, rnd(-.4, .4))), 1, .5, V(rnd(-.5, .5), .4, rnd(-.5, .5)), 0xd8cfc2, .55); }
      }
      if (moving) { lines = Math.max(lines, .25); linesColor = '255,214,110'; }
    }
    if (!on && buffUntil > 0 && now >= buffUntil) {
      // Buff ends: the light fades, steam and an exhale, then a short fatigue slow.
      buffUntil = 0; fatigueUntil = now + CFG.q.fatigueDur; sfx.exhale(); sfx.steam(); A.toast('풀 파워 종료 · 피로 · 이동 속도 -15% 1.2초');
      for (const arm of [arms.r, arms.l]) for (let i = 0; i < 6; i++) dust(camera.localToWorld(arm.g.position.clone().add(V(rnd(-.1, .1), rnd(-.3, .1), 0))), .4, 1, V(rnd(-.2, .2), 1, rnd(-.2, .2)), 0xffffff, .5);
    }
    for (const m of [mGlove, mSuit, mMuscle]) m.emissiveIntensity = glowK * (m === mGlove ? .55 : .045);
    glowK = Math.max(0, glowK - dt * 4);
    // Victims.
    for (const [t, m] of [...movers]) { if (t.hp <= 0) { movers.delete(t); calm(t); t.locked = false; continue; } m.update?.(now - m.born, dt); }
    // Camera shake.
    if (shakeAmp > .001) { camera.position.x += rnd() * shakeAmp; camera.position.y += rnd() * shakeAmp; camera.rotation.z += rnd() * shakeAmp * .25; shakeAmp *= Math.exp(-shakeDecay * dt); }
    // Screen layers.
    vign = active ? vign * Math.exp(-3 * dt) : 0;
    ovV.style.opacity = Math.min(1, vign).toFixed(3);
    ovL.style.opacity = Math.min(1, lines + burstK).toFixed(3); ovL.style.setProperty('--lc', burstK > lines ? '255,255,255' : linesColor);
    ovL.style.transform = `rotate(${(Math.floor(now * 30) * 37) % 360}deg) scale(${1 + .15 * burstK})`;
    lines = Math.max(0, lines - dt * 6); burstK = Math.max(0, burstK - dt * 3);
    ovF.style.background = `radial-gradient(circle at 50% 50%,rgba(${flashColor},.65),rgba(${flashColor},.95))`; ovF.style.opacity = flashV.toFixed(3); flashV *= Math.exp(-8 * dt);
    $('scene').style.filter = contrast > .01 ? `contrast(${(1 + contrast).toFixed(2)}) saturate(${(1 + contrast * .5).toFixed(2)})` : (A.cast?.allmight ? '' : $('scene').style.filter);
    contrast = Math.max(0, contrast - dt * 2);
    const sa = now - shoutAt;
    if (sa >= 0 && sa < shoutLife) {
      const inK = outP(sa / .12, 3), fade = 1 - ease((sa - shoutLife + .35) / .35);
      ovT.textContent = shoutText; ovT.style.fontSize = shoutText.length > 14 ? 'clamp(22px,4.2vw,58px)' : ''; ovT.style.color = shoutColor; ovT.style.opacity = fade.toFixed(3); ovT.style.transform = `translate(-50%,-50%) scale(${(1.7 - .7 * inK).toFixed(3)})`;
      ovS.textContent = shoutSub; ovS.style.opacity = (shoutSub ? fade : 0).toFixed(3);
    } else { ovT.style.opacity = 0; ovS.style.opacity = 0; }
    // Effects.
    for (let i = fxs.length - 1; i >= 0; i--) { const e = fxs[i], u = (now - e.born) / e.life; if (u >= 1) { fxs.splice(i, 1); e.done?.(); kill(e.obj); } else e.update?.(e.obj, u, dt); }
  }
  // Walk speed factor: buffed, prep/recovery slows and fatigue. During E and R the module moves the body itself.
  function speed() {
    const c = A.cast, now = A.time;
    if (c?.allmight) {
      if (c.type === 'ofa') return now - c.start < CFG.q.prep ? CFG.q.prepSpeed : 1;
      if (c.type === 'smash' || c.type === 'ultra') return c.fail && now - c.start > c.fail + .3 ? .5 : 0;
    }
    let f = buffed() ? CFG.q.speed : 1;
    if (now < afterUntil) f *= afterFactor;
    if (now < fatigueUntil) f *= CFG.q.fatigue;
    return f;
  }
  const basicFactor = () => active && buffed() ? CFG.q.basic : 1;
  const knockFactor = () => active && buffed() ? CFG.q.knock : 1;
  function hud() {
    const now = A.time, c = A.cast, combo = comboUntil > now && c?.type === 'smash' && A.cooldowns.ultra <= now;
    $('rBtn').classList.toggle('combo', combo); $('qBtn').classList.toggle('combo', buffed());
    const prompt = $('comboPrompt'); prompt.classList.toggle('on', combo);
    if (combo) { $('comboKey').textContent = 'R'; $('comboText').textContent = ' SMASH 적중 · 지금 PLUS ULTRA 연계 ' + (comboUntil - now).toFixed(1) + '초'; prompt.style.setProperty('--left', (comboUntil - now) / .82 * 100 + '%'); }
    $('qBtn').querySelector('.skill-type').textContent = buffed() ? '풀 파워 ' + (buffUntil - now).toFixed(1) + '초 남음' : '0.85초 준비 · 10초 강화';
    $('eBtn').querySelector('.skill-type').textContent = c?.type === 'smash' ? (c.bump ? '벽 충돌' : c.whiff ? '빗나감' : c.contact ? (c.flags.impact ? 'SMASH!' : '붙잡음 · 회전 펀치') : '돌진 중') : '22 돌진 · 55 + 충격파 18' + (buffed() ? ' · +20%' : '');
    $('rBtn').querySelector('.skill-type').textContent = c?.type === 'ultra' ? (c.fail ? '실패 · 30초' : c.contact ? 'PLUS ULTRA!' : '돌진 중') : '35 돌진 → 하늘로 · 110';
    const d = $('debuff'); d.classList.add('on');
    d.textContent = c?.type === 'ultra' ? '시전 중 · 강한 경직 저항' + (buffed() ? ' · 풀 파워 (R 피해는 그대로)' : '')
      : buffed() ? 'ONE FOR ALL · FULL POWER ' + (buffUntil - now).toFixed(1) + '초 · 이동 +35% · 받는 피해 -15%'
      : now < fatigueUntil ? '피로 · 이동 속도 -15% ' + (fatigueUntil - now).toFixed(1) + '초'
      : now < afterUntil ? '스매시 반동 · 이동 속도 -30% ' + (afterUntil - now).toFixed(1) + '초'
      : '원 포 올 · Q→E 강화 · E 적중 직후 R 연계';
  }
  function reset() {
    for (const e of fxs.splice(0)) kill(e.obj);
    for (const o of [...live]) kill(o);
    for (const [t] of movers) { calm(t); t.locked = false; t.g.userData.cannonUntil = 0; }
    movers.clear(); for (const t of targets) calm(t); for (const t of extras) calm(t);
    buffUntil = 0; buffStart = -9; fatigueUntil = 0; afterUntil = 0; comboUntil = 0; shakeAmp = 0; flashV = 0; vign = 0; lines = 0; burstK = 0; contrast = 0; glowK = 0; fovBoost = 0; meleeFov = 0; landing = null; shoutAt = -9;
    body.visible = false; if (basePos.y > EYE) basePos.y = EYE;
    ovV.style.opacity = ovL.style.opacity = ovF.style.opacity = ovT.style.opacity = ovS.style.opacity = 0;
    try { window.speechSynthesis?.cancel(); } catch (e) { /* no speech */ }
  }
  // Extra dummies only exist while All Might is selected, so the other characters keep their original targets.
  function activate(on) {
    active = on; document.body.classList.toggle('allmight', on);
    for (const t of extras) {
      const i = targets.indexOf(t);
      if (on && i < 0) targets.push(t); if (!on && i >= 0) targets.splice(i, 1);
      t.hp = t.max; t.g.visible = on; t.g.position.copy(t.home); t.bar.scale.x = 1; t.bar.position.x = 0; t.locked = false; t.respawn = 0; t.vel = null; t.landed = 0; calm(t);
    }
    if (!on) { arms.r.g.visible = arms.l.g.visible = arms.r.up.visible = arms.l.up.visible = false; body.visible = false; $('debuff').textContent = ''; $('debuff').classList.remove('on'); }
  }
  function state() {
    const c = A.cast;
    return { active, buff: buffed() ? +(buffUntil - A.time).toFixed(2) : 0, fatigue: A.time < fatigueUntil, speed: +speed().toFixed(2),
      cast: c?.allmight ? { type: c.type, age: +(A.time - c.start).toFixed(2), target: c.target?.index ?? null, contact: c.contact ?? null, hit: !!c.hit, bump: !!c.bump, whiff: !!c.whiff, fail: !!c.fail, cine: +(c.cine || 0).toFixed(2) } : null,
      pos: basePos.toArray().map(v => +v.toFixed(2)), movers: [...movers].map(([t, m]) => t.index + ':' + m.kind), fx: fxs.length, live: live.size,
      targets: targets.map(t => ({ i: t.index, hp: t.hp, pos: t.g.position.toArray().map(v => +v.toFixed(1)), vis: t.g.visible })) };
  }
  return { begin, update, end, frame, speed, hud, reset, activate, state, canCancel, cancel, basicFactor, knockFactor, skills: new Set(['ofa', 'smash', 'ultra']) };
};

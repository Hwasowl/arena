// Replaces each script's CDATA source in the .rbxlx with its current src file (Rojo isn't installed).
const fs = require('fs'), path = require('path');
const root = process.argv[2];
const f = path.join(root, 'InfinityArena-Gojo.rbxlx');
let x = fs.readFileSync(f, 'utf8');
const scripts = {
  GojoConfig: 'roblox/src/ReplicatedStorage/GojoConfig.luau',
  Arena: 'roblox/src/ServerScriptService/Arena.server.luau',
  Combat: 'roblox/src/ServerScriptService/Combat.server.luau',
  StoreVFX: 'roblox/src/ServerScriptService/StoreVFX.server.luau',
  Gojo: 'roblox/src/StarterPlayer/StarterPlayerScripts/Gojo.client.luau',
};
for (const [name, rel] of Object.entries(scripts)) {
  const re = new RegExp('(<string name="Name">' + name + '</string>\\s*(?:<token name="RunContext">\\d+</token>\\s*)?<string name="Source"><!\\[CDATA\\[)([\\s\\S]*?)(\\]\\]></string>)');
  const m = x.match(re);
  if (!m) { console.log(name, 'NOT FOUND'); continue; }
  const src = fs.readFileSync(path.join(root, rel), 'utf8');
  if (src.includes(']]>')) throw new Error(name + ' contains ]]>');
  console.log(name, m[2] === src ? 'already in sync' : 'updated');
  x = x.replace(re, (_, a, _b, c) => a + src + c);
}
fs.writeFileSync(f, x);
console.log('Finger/Thumb left:', (x.match(/Finger|Thumb/g) || []).length);

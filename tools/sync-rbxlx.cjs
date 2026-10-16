// Replaces each script's CDATA source in the .rbxlx with its current src file (Rojo isn't installed).
const fs = require('fs'), path = require('path');
const root = process.argv[2];
const f = path.join(root, 'InfinityArena-Gojo.rbxlx');
let x = fs.readFileSync(f, 'utf8');
const newline = x.includes('\r\n') ? '\r\n' : '\n';
const scripts = {
  KizaruServer: 'roblox/src/ServerScriptService/KizaruServer.luau',
  KizaruClient: 'roblox/src/StarterPlayer/StarterPlayerScripts/KizaruClient.luau',
  OkkotsuConfig: 'roblox/src/ReplicatedStorage/OkkotsuConfig.luau',
  OkkotsuVFX: 'roblox/src/ReplicatedStorage/OkkotsuVFX.luau',
  OkkotsuServer: 'roblox/src/ServerScriptService/OkkotsuServer.luau',
  OkkotsuClient: 'roblox/src/StarterPlayer/StarterPlayerScripts/OkkotsuClient.luau',
  GojoConfig: 'roblox/src/ReplicatedStorage/GojoConfig.luau',
  Arena: 'roblox/src/ServerScriptService/Arena.server.luau',
  Combat: 'roblox/src/ServerScriptService/Combat.server.luau',
  StoreVFX: 'roblox/src/ServerScriptService/StoreVFX.server.luau',
  Gojo: 'roblox/src/StarterPlayer/StarterPlayerScripts/Gojo.client.luau',
  PainAbilityConfig: 'roblox/src/ReplicatedStorage/PainAbilityConfig.luau',
  PainVFX: 'roblox/src/ReplicatedStorage/PainVFX.luau',
  PainServer: 'roblox/src/ServerScriptService/PainServer.luau',
  PainClient: 'roblox/src/StarterPlayer/StarterPlayerScripts/PainClient.luau',
  AllMightConfig: 'roblox/src/ReplicatedStorage/AllMightConfig.luau',
  AllMightVFX: 'roblox/src/ReplicatedStorage/AllMightVFX.luau',
  AllMightServer: 'roblox/src/ServerScriptService/AllMightServer.luau',
  AllMightClient: 'roblox/src/StarterPlayer/StarterPlayerScripts/AllMightClient.luau',
};
// Studio saves Source as ProtectedString, sometimes before Name; Rojo uses string.
// New Okkotsu modules are inserted beside an existing module in the same service.
const siblings={KizaruServer:'PainServer',KizaruClient:'PainClient',OkkotsuConfig:'PainAbilityConfig',OkkotsuVFX:'OkkotsuConfig',OkkotsuServer:'PainServer',OkkotsuClient:'PainClient'};
for(const [name,sibling] of Object.entries(siblings)){
  if(x.includes('<string name="Name">'+name+'</string>'))continue;
  const re=/<Item class="ModuleScript"[^>]*>\s*<Properties>[\s\S]*?<\/Properties>/g;
  let at=-1;
  for(const match of x.matchAll(re)){
    const moduleName=match[0].match(/<string name="Name">([^<]+)<\/string>/)?.[1];
    if(moduleName===sibling){at=match.index;break;}
  }
  if(at<0)throw new Error('Cannot place '+name+': sibling missing');
  const item='<Item class="ModuleScript" referent="RBX_'+name+'"><Properties><string name="Name">'+name+'</string><ProtectedString name="Source"><![CDATA[]]></ProtectedString></Properties></Item>'+newline;
  x=x.slice(0,at)+item+x.slice(at);
}
// Locate each script's own Properties first so property order cannot mix sources between scripts.
const found = new Set();
x = x.replace(/(<Item class="(?:Script|LocalScript|ModuleScript)"[^>]*>\s*<Properties>)([\s\S]*?)(<\/Properties>)/g, (item, open, properties, close) => {
  const name = properties.match(/<string name="Name">([^<]+)<\/string>/)?.[1];
  if (!Object.hasOwn(scripts, name)) return item;
  if (found.has(name)) throw new Error('Duplicate script: ' + name);
  const source = /(<(ProtectedString|string) name="Source">)([\s\S]*?)(<\/\2>)/;
  const match = properties.match(source);
  if (!match) throw new Error('Source missing: ' + name);
  const src = fs.readFileSync(path.join(root, scripts[name]), 'utf8').replace(/\r?\n/g, newline);
  if (src.includes(']]>')) throw new Error(name + ' contains ]]>');
  const content = '<![CDATA[' + src + ']]>';
  console.log(name, match[3] === content ? 'already in sync' : 'updated');
  found.add(name);
  return open + properties.replace(source, (_, tag, _type, _old, end) => tag + content + end) + close;
});
for (const name of Object.keys(scripts)) if (!found.has(name)) throw new Error('Script not found: ' + name);
fs.writeFileSync(f, x);
console.log('Finger/Thumb left:', (x.match(/Finger|Thumb/g) || []).length);

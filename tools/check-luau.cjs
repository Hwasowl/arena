// Syntax-checks Luau files with a Lua 5.3 parser after rewriting Luau compound assignments (a+=b -> a=a+b).
const fs = require('fs'), luaparse = require('luaparse');
let failed = false;
for (const file of process.argv.slice(2)) {
  const src = fs.readFileSync(file, 'utf8')
    .replace(/([A-Za-z_][\w.]*(?:\[[^\]]*\])?)\s*([+\-*/])=(?!=)/g, '$1=$1$2');
  try {
    luaparse.parse(src, { luaVersion: '5.3' });
    console.log('OK  ', file.split(/[\\/]/).pop());
  } catch (e) {
    failed = true;
    const lines = src.split('\n');
    console.log('FAIL', file.split(/[\\/]/).pop(), e.message, '\n   ', (lines[e.line - 1] || '').slice(0, 160));
  }
}
process.exit(failed ? 1 : 0);

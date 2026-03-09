const fs = require('fs');
const schema = JSON.parse(fs.readFileSync('schema_summary.json', 'utf8'));

const rpcs = Object.keys(schema.paths)
    .filter(path => path.includes('rpc/'))
    .map(path => path.replace('/rpc/', ''));

fs.writeFileSync('all_rpcs.txt', rpcs.join('\n'));
console.log(`Saved ${rpcs.length} RPCs to all_rpcs.txt`);

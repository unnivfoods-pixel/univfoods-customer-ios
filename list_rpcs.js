const fs = require('fs');
const schema = JSON.parse(fs.readFileSync('schema_summary.json', 'utf8'));

Object.keys(schema.paths).forEach(path => {
    if (path.includes('rpc/')) {
        console.log(path);
    }
});

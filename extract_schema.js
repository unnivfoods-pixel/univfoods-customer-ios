const fs = require('fs');
const schema = JSON.parse(fs.readFileSync('schema_summary.json', 'utf8'));

const definitions = ['vendors', 'orders', 'products'];
const result = {};

definitions.forEach(def => {
    if (schema.definitions[def]) {
        result[def] = schema.definitions[def];
    }
});

console.log(JSON.stringify(result, null, 2));

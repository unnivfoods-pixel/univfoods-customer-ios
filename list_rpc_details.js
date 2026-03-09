const fs = require('fs');
const schema = JSON.parse(fs.readFileSync('schema_summary.json', 'utf8'));

Object.keys(schema.paths).forEach(path => {
    if (path.includes('rpc/')) {
        console.log(path);
        // Also log parameters
        const method = schema.paths[path].post || schema.paths[path].get;
        if (method && method.parameters) {
            method.parameters.forEach(param => {
                if (param.name === 'body') {
                    console.log('  Schema:', JSON.stringify(param.schema, null, 2));
                } else {
                    console.log('  Param:', param.name);
                }
            });
        }
    }
});

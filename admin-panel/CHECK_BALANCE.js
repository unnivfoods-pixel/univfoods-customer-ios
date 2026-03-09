
import fs from 'fs';

const content = fs.readFileSync('src/pages/Promotions.jsx', 'utf8');

let stack = [];
let lines = content.split('\n');

for (let i = 0; i < lines.length; i++) {
    let line = lines[i];
    for (let j = 0; j < line.length; j++) {
        let char = line[j];
        if (char === '{' || char === '(' || char === '[') {
            stack.push({ char, line: i + 1, col: j + 1 });
        } else if (char === '}' || char === ')' || char === ']') {
            if (stack.length === 0) {
                console.log(`Unmatched closing ${char} at line ${i + 1}, col ${j + 1}`);
            } else {
                let last = stack.pop();
                if ((char === '}' && last.char !== '{') ||
                    (char === ')' && last.char !== '(') ||
                    (char === ']' && last.char !== '[')) {
                    console.log(`Mismatched ${char} at line ${i + 1}, col ${j + 1} (expected closing for ${last.char} from line ${last.line}, col ${last.col})`);
                }
            }
        }
    }
}

if (stack.length > 0) {
    stack.forEach(s => console.log(`Unclosed ${s.char} from line ${s.line}, col ${s.col}`));
} else {
    console.log("All braces, parens, and brackets are balanced.");
}

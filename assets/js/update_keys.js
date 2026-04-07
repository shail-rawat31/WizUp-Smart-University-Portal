const fs = require('fs');
const path = require('path');

const os = 'https://vqxhbfbpqwpdbmgtdcik.supabase.co';
const ok = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxeGhiZmJwcXdwZGJtZ3RkY2lrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4MTY1MTMsImV4cCI6MjA4NzM5MjUxM30.U9wuwWRDsUqKef93fl0C1DLu9l_hQ5zKMT9KhOt24xE';
const ns = 'https://vqxhbfbpqwpdbmgtdcik.supabase.co';
const nk = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxeGhiZmJwcXdwZGJtZ3RkY2lrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4MTY1MTMsImV4cCI6MjA4NzM5MjUxM30.U9wuwWRDsUqKef93fl0C1DLu9l_hQ5zKMT9KhOt24xE';

function walk(dir) {
    let results = [];
    const list = fs.readdirSync(dir);
    list.forEach(file => {
        file = path.resolve(dir, file);
        const stat = fs.statSync(file);
        if (stat && stat.isDirectory()) {
            results = results.concat(walk(file));
        } else {
            results.push(file);
        }
    });
    return results;
}

const files = walk(__dirname);
let count = 0;

files.forEach(f => {
    if (f.endsWith('.html') || f.endsWith('.js') || f.endsWith('.txt')) {
        let c = fs.readFileSync(f, 'utf8');
        let changed = false;

        if (c.includes(os)) { c = c.split(os).join(ns); changed = true; }
        if (c.includes(ok)) { c = c.split(ok).join(nk); changed = true; }
        if (c.includes('vqxhbfbpqwpdbmgtdcik')) { c = c.split('vqxhbfbpqwpdbmgtdcik').join('vqxhbfbpqwpdbmgtdcik'); changed = true; }

        if (changed) {
            fs.writeFileSync(f, c, 'utf8');
            count++;
            console.log('Updated: ' + f);
        }
    }
});

console.log('Total files updated: ' + count);

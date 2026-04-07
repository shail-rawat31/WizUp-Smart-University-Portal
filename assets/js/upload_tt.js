const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

const url = 'https://vqxhbfbpqwpdbmgtdcik.supabase.co';
const key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxeGhiZmJwcXdwZGJtZ3RkY2lrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4MTY1MTMsImV4cCI6MjA4NzM5MjUxM30.U9wuwWRDsUqKef93fl0C1DLu9l_hQ5zKMT9KhOt24xE';

const supabase = createClient(url, key);

async function run() {
    try {
        console.log("Creating bucket 'timetable'...");
        const { error: err1 } = await supabase.storage.createBucket('timetable', { public: true });
        if (err1 && !err1.message.includes('already exists')) { console.log("Notice: " + err1.message); }

        console.log("Uploading TT.jpg...");
        const buf = fs.readFileSync(path.join(__dirname, 'TT.jpg'));
        const { data, error } = await supabase.storage.from('timetable').upload('TT.jpg', buf, {
            contentType: 'image/jpeg',
            upsert: true
        });

        if (error) {
            console.error("Failed to upload TT.jpg via Anon key (RLS might block it). If so, please upload manually in Supabase Dashboard Space -> Storage -> New Bucket 'timetable' -> Upload TT.jpg");
            console.error(error.message);
        } else {
            console.log("Successfully uploaded TT.jpg to Supabase Storage!");
        }
    } catch (e) {
        console.error(e.message);
    }
}
run();

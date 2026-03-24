const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

const supabaseUrl = 'https://djqgmowfjxsnjdffdohw.supabase.co';
const supabaseKey = 'sb_publishable__FkMcK1683czdRktkt7YsA_vYR4ZsOW';
const supabase = createClient(supabaseUrl, supabaseKey);

async function run() {
    try {
        const { data: buckets, error: bError } = await supabase.storage.listBuckets();
        console.log("Buckets:", buckets);
        if (bError) console.error("Bucket Error:", bError);
        
        const { data: songs, error: sError } = await supabase.from('songs').select('id, title').limit(5);
        console.log("Songs:", songs);
        if (sError) console.error("Song Error:", sError);
    } catch (e) {
        console.error("Exception:", e);
    }
}

run();

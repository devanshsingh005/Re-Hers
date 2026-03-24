const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://djqgmowfjxsnjdffdohw.supabase.co';
const supabaseKey = 'sb_publishable__FkMcK1683czdRktkt7YsA_vYR4ZsOW';
const supabase = createClient(supabaseUrl, supabaseKey);

async function run() {
    try {
        // Fetch all songs
        const { data: songs, error: sError } = await supabase.from('songs').select('id');
        if (sError) {
            console.error("Song fetch error:", sError);
            return;
        }

        console.log(`Found ${songs.length} songs. Updating with asset references...`);
        
        const numberOfTrackImages = 16;

        for (let i = 0; i < songs.length; i++) {
            const song = songs[i];
            // Assign a stable number from 1 to 16. Using index + 1 for now or random but we want it "same everytime".
            // It will be the same everytime because we are saving it to the database!
            // Let's just use (i % numberOfTrackImages) + 1
            const imageIndex = (i % numberOfTrackImages) + 1;
            const assetName = `trackimage_${imageIndex}`;
            
            const { error: updError } = await supabase.from('songs').update({ cover_image_url: assetName }).eq('id', song.id);
            if (updError) {
                console.error(`Failed to update song ${song.id}:`, updError);
            } else {
                console.log(`Updated song ${song.id} with ${assetName}`);
            }
        }
        
        console.log("Done updating songs with local asset references.");
    } catch (e) {
        console.error("Exception:", e);
    }
}

run();

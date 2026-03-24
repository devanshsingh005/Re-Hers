const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

const supabaseUrl = 'https://djqgmowfjxsnjdffdohw.supabase.co';
const supabaseKey = 'sb_publishable__FkMcK1683czdRktkt7YsA_vYR4ZsOW';
const supabase = createClient(supabaseUrl, supabaseKey);

async function run() {
    try {
        // Create bucket if not exists
        const { data: bData, error: bError } = await supabase.storage.createBucket('covers', { public: true });
        if (bError && !bError.message.includes('already exists')) {
            console.error("Bucket Error:", bError);
            // Ignore error, bucket might exist or we lack permissions. 
        } else {
            console.log("Bucket created or exists.");
        }

        const assetsPaths = [
            "/Users/user89/Desktop/Rehearse/Re-Hearse_v1/Assets.xcassets/imageAssets/track_images/trackimage_1.imageset/trackimage_1.png",
            "/Users/user89/Desktop/Rehearse/Re-Hearse_v1/Assets.xcassets/imageAssets/track_images/trackimage_2.imageset/trackimage_2.png",
            "/Users/user89/Desktop/Rehearse/Re-Hearse_v1/Assets.xcassets/imageAssets/track_images/trackimage_3.imageset/trackimage_3.png",
            "/Users/user89/Desktop/Rehearse/Re-Hearse_v1/Assets.xcassets/imageAssets/track_images/trackimage_4.imageset/trackimage_4.png",
            "/Users/user89/Desktop/Rehearse/Re-Hearse_v1/Assets.xcassets/imageAssets/track_images/trackimage_5.imageset/trackimage_5.png",
            "/Users/user89/Desktop/Rehearse/Re-Hearse_v1/Assets.xcassets/imageAssets/track_images/trackimage_6.imageset/trackimage_6.png",
            "/Users/user89/Desktop/Rehearse/Re-Hearse_v1/Assets.xcassets/imageAssets/track_images/trackimage_7.imageset/trackimage_7.png",
            "/Users/user89/Desktop/Rehearse/Re-Hearse_v1/Assets.xcassets/imageAssets/track_images/trackimage_8.imageset/trackimage_8.png",
            "/Users/user89/Desktop/Rehearse/Re-Hearse_v1/Assets.xcassets/imageAssets/track_images/trackimage_9.imageset/trackimage_9.png",
            "/Users/user89/Desktop/Rehearse/Re-Hearse_v1/Assets.xcassets/imageAssets/track_images/trackimage_10.imageset/trackimage_10.png",
            "/Users/user89/Desktop/Rehearse/Re-Hearse_v1/Assets.xcassets/imageAssets/track_images/trackimage_11.imageset/trackimage_11.png",
            "/Users/user89/Desktop/Rehearse/Re-Hearse_v1/Assets.xcassets/imageAssets/track_images/trackimage_12.imageset/trackimage_12.png",
            "/Users/user89/Desktop/Rehearse/Re-Hearse_v1/Assets.xcassets/imageAssets/track_images/trackimage_13.imageset/trackimage_13.png",
            "/Users/user89/Desktop/Rehearse/Re-Hearse_v1/Assets.xcassets/imageAssets/track_images/trackimage_14.imageset/trackimage_14.png",
            "/Users/user89/Desktop/Rehearse/Re-Hearse_v1/Assets.xcassets/imageAssets/track_images/trackimage_15.imageset/trackimage_15.png",
            "/Users/user89/Desktop/Rehearse/Re-Hearse_v1/Assets.xcassets/imageAssets/track_images/trackimage_16.imageset/trackimage_16.png"
        ];

        let coverUrls = [];

        for (const p of assetsPaths) {
            const fileName = p.split('/').pop();
            if(!fs.existsSync(p)) continue;
            
            const fileData = fs.readFileSync(p);
            console.log(`Uploading ${fileName}...`);
            const { data, error } = await supabase.storage.from('covers').upload(fileName, fileData, { upsert: true, contentType: 'image/png' });
            
            if (error) {
                console.error(`Upload error for ${fileName}:`, error);
                // If uploading fails, we'll try to just proceed so we know the failure mode.
            } else {
                const { data: pubData } = supabase.storage.from('covers').getPublicUrl(fileName);
                coverUrls.push(pubData.publicUrl);
                console.log(`Success: ${pubData.publicUrl}`);
            }
        }

        if (coverUrls.length === 0) {
            console.error("No images uploaded successfully.");
            return;
        }

        // Fetch songs
        const { data: songs, error: sError } = await supabase.from('songs').select('id');
        if (sError) {
            console.error("Song fetch error:", sError);
            return;
        }

        console.log(`Updating ${songs.length} songs...`);
        for (let i = 0; i < songs.length; i++) {
            const song = songs[i];
            const url = coverUrls[i % coverUrls.length];
            const { error: updError } = await supabase.from('songs').update({ cover_image_url: url }).eq('id', song.id);
            if (updError) {
                console.error(`Failed to update song ${song.id}:`, updError);
            }
        }
        
        console.log("Done updating songs.");
    } catch (e) {
        console.error("Exception:", e);
    }
}

run();

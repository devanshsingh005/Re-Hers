const { createClient } = require('@supabase/supabase-js');
const supabase = createClient('https://djqgmowfjxsnjdffdohw.supabase.co', 'sb_publishable__FkMcK1683czdRktkt7YsA_vYR4ZsOW');

async function testUpdate() {
  const { data: songs, error: sErr } = await supabase.from('songs').select('id').limit(1);
  if (sErr || !songs.length) return console.log('Fetch error', sErr);
  const { error: uErr } = await supabase.from('songs').update({ title: 'Twinkle Twinkle Little Star' }).eq('id', songs[0].id);
  console.log('Update error:', uErr);
}
testUpdate();

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

type JsonBody = Record<string, unknown>;
type ProfileRow = { avatar_url: string | null };
type PlaylistRow = { cover_image_url: string | null };

const json = (body: JsonBody, init: ResponseInit = {}) =>
  new Response(JSON.stringify(body), {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...(init.headers ?? {}),
    },
  });

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseAnonKey = Deno.env.get("ANON_KEY");
const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY");

const addPath = (target: Set<string>, path: string | null | undefined) => {
  if (!path) return;
  const trimmed = path.trim();
  if (!trimmed) return;
  target.add(trimmed);
};

const extractStoragePath = (urlOrPath: string | null | undefined, bucket: string) => {
  if (!urlOrPath) return null;
  const value = urlOrPath.trim();
  if (!value) return null;

  const fullPrefixPattern = new RegExp(
    `^.*/storage/v1/object/(?:public|sign)/${bucket}/`,
  );

  if (fullPrefixPattern.test(value)) {
    return value.replace(fullPrefixPattern, "").split("?")[0];
  }

  return value.split("?")[0];
};

serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed." }, { status: 405 });
  }

  if (!supabaseUrl || !supabaseAnonKey || !serviceRoleKey) {
    return json(
      { error: "Supabase function secrets are not configured." },
      { status: 500 },
    );
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.startsWith("Bearer ")
    ? authHeader.slice("Bearer ".length).trim()
    : "";

  if (!token) {
    return json({ error: "Missing bearer token." }, { status: 401 });
  }

  const anonClient = createClient(supabaseUrl, supabaseAnonKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  const { data: userData, error: userError } = await anonClient.auth.getUser(token);
  const user = userData.user;

  if (userError || !user) {
    return json({ error: "Invalid or expired token." }, { status: 401 });
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  const userId = user.id;

  try {
    const [profileResult, playlistsResult] = await Promise.all([
      adminClient.from("profiles").select("avatar_url").eq("id", userId).maybeSingle(),
      adminClient.from("playlists").select("cover_image_url").eq("user_id", userId),
    ]);

    if (profileResult.error) {
      return json({ error: profileResult.error.message || "Failed to load profile assets." }, { status: 500 });
    }
    if (playlistsResult.error) {
      return json({ error: playlistsResult.error.message || "Failed to load playlist assets." }, { status: 500 });
    }

    const useprofilePaths = new Set<string>();
    const playlistCoverPaths = new Set<string>();

    // Current avatar, plus every earlier avatar this user uploaded (avatar_<userId>_<timestamp>.<ext>).
    addPath(useprofilePaths, extractStoragePath((profileResult.data as ProfileRow | null)?.avatar_url ?? null, "useprofile"));
    const { data: oldAvatars } = await adminClient.storage.from("useprofile")
      .list("", { search: `avatar_${userId}`, limit: 1000 });
    for (const file of oldAvatars ?? []) addPath(useprofilePaths, file.name);

    // Covers live under <userId>/ in PlayListCover.
    for (const row of (playlistsResult.data ?? []) as PlaylistRow[]) {
      addPath(playlistCoverPaths, extractStoragePath(row.cover_image_url, "PlayListCover"));
    }
    const { data: coverFiles } = await adminClient.storage.from("PlayListCover")
      .list(userId, { limit: 1000 });
    for (const file of coverFiles ?? []) addPath(playlistCoverPaths, `${userId}/${file.name}`);

    // Synced sheet uploads: user_sheets/<userId>/<uploadId>/<file>.
    const sheetPaths: string[] = [];
    const { data: uploadFolders } = await adminClient.storage.from("user_sheets").list(userId, { limit: 1000 });
    for (const folder of uploadFolders ?? []) {
      const { data: files } = await adminClient.storage.from("user_sheets")
        .list(`${userId}/${folder.name}`, { limit: 100 });
      for (const file of files ?? []) sheetPaths.push(`${userId}/${folder.name}/${file.name}`);
    }

    // Only storage paths: bundled icons ("icon_3") and on-device covers ("doc_…") are not files in storage.
    const isStoragePath = (p: string) => p.includes("/") || p.includes(".");
    const removals: Array<Promise<unknown>> = [];
    const avatarList = Array.from(useprofilePaths).filter(isStoragePath);
    const coverList = Array.from(playlistCoverPaths).filter(isStoragePath);
    if (avatarList.length > 0) removals.push(adminClient.storage.from("useprofile").remove(avatarList));
    if (coverList.length > 0) removals.push(adminClient.storage.from("PlayListCover").remove(coverList));
    if (sheetPaths.length > 0) removals.push(adminClient.storage.from("user_sheets").remove(sheetPaths));
    await Promise.all(removals);

    const { error: cleanupError } = await adminClient.rpc("delete_user_account_data", {
      p_user_id: userId,
    });
    if (cleanupError) {
      return json(
        { error: cleanupError.message || "Failed to delete account data." },
        { status: 500 },
      );
    }

    const { error: deleteUserError } = await adminClient.auth.admin.deleteUser(userId);
    if (deleteUserError) {
      return json(
        { error: deleteUserError.message || "Failed to delete auth user." },
        { status: 500 },
      );
    }

    return json({ ok: true, deletedUserId: userId }, { status: 200 });
  } catch (error) {
    return json(
      {
        error: error instanceof Error ? error.message : "Account deletion failed.",
      },
      { status: 500 },
    );
  }
});

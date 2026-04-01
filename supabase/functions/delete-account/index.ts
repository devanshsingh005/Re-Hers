import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

type JsonBody = Record<string, unknown>;
type ProfileRow = { avatar_url: string | null };
type PlaylistRow = { cover_image_url: string | null };
type JobRow = { pdf_path: string | null; result_url: string | null };
type ScanRow = {
  processing_id: string | null;
  json_data: Record<string, unknown> | null;
};

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
    const [profileResult, playlistsResult, jobsResult, scansResult] = await Promise.all([
      adminClient.from("profiles").select("avatar_url").eq("id", userId).maybeSingle(),
      adminClient.from("playlists").select("cover_image_url").eq("user_id", userId),
      adminClient.from("jobs").select("pdf_path, result_url").eq("user_id", userId),
      adminClient.from("scans").select("processing_id, json_data").eq("user_id", userId),
    ]);

    if (profileResult.error) {
      return json({ error: profileResult.error.message || "Failed to load profile assets." }, { status: 500 });
    }
    if (playlistsResult.error) {
      return json({ error: playlistsResult.error.message || "Failed to load playlist assets." }, { status: 500 });
    }
    if (jobsResult.error) {
      return json({ error: jobsResult.error.message || "Failed to load job assets." }, { status: 500 });
    }
    if (scansResult.error) {
      return json({ error: scansResult.error.message || "Failed to load scan assets." }, { status: 500 });
    }

    const useprofilePaths = new Set<string>();
    const playlistCoverPaths = new Set<string>();
    const pdfUploadPaths = new Set<string>();
    const sheetDataPaths = new Set<string>();

    addPath(useprofilePaths, (profileResult.data as ProfileRow | null)?.avatar_url ?? null);

    for (const row of (playlistsResult.data ?? []) as PlaylistRow[]) {
      addPath(playlistCoverPaths, row.cover_image_url);
    }

    for (const row of (jobsResult.data ?? []) as JobRow[]) {
      addPath(pdfUploadPaths, row.pdf_path);
      addPath(pdfUploadPaths, extractStoragePath(row.result_url, "pdf_uploads"));
      addPath(sheetDataPaths, extractStoragePath(row.result_url, "sheet_data"));
    }

    for (const row of (scansResult.data ?? []) as ScanRow[]) {
      const processingId = row.processing_id?.trim();
      if (processingId) {
        addPath(pdfUploadPaths, `${userId}/${processingId}/input.pdf`);
        addPath(pdfUploadPaths, `${userId}/${processingId}/labeled.pdf`);
        addPath(sheetDataPaths, `${userId}/${processingId}/output.json`);
      }

      const outputURL = typeof row.json_data?.output_url === "string"
        ? row.json_data.output_url
        : null;
      addPath(pdfUploadPaths, extractStoragePath(outputURL, "pdf_uploads"));
      addPath(sheetDataPaths, extractStoragePath(outputURL, "sheet_data"));
    }

    const storageDeletes: Array<Promise<unknown>> = [];
    if (useprofilePaths.size > 0) {
      storageDeletes.push(adminClient.storage.from("useprofile").remove(Array.from(useprofilePaths)));
    }
    if (playlistCoverPaths.size > 0) {
      storageDeletes.push(adminClient.storage.from("PlayListCover").remove(Array.from(playlistCoverPaths)));
    }
    if (pdfUploadPaths.size > 0) {
      storageDeletes.push(adminClient.storage.from("pdf_uploads").remove(Array.from(pdfUploadPaths)));
    }
    if (sheetDataPaths.size > 0) {
      storageDeletes.push(adminClient.storage.from("sheet_data").remove(Array.from(sheetDataPaths)));
    }

    await Promise.all(storageDeletes);

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

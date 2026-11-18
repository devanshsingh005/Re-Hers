// Admin dashboard: suspend / unsuspend an account.
// Only callable by a dashboard admin whose session passed the authenticator step (public.is_admin()).
// Suspending uses Supabase's built-in ban: the person can't sign in or refresh their session;
// an access token they already hold stops working when it expires (within an hour).
import { createClient } from "npm:@supabase/supabase-js@2";

const ALLOWED_ORIGINS = new Set([
  "https://letsrehearse.studio",
  "https://www.letsrehearse.studio",
  "http://localhost:4321",
]);

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("ANON_KEY")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SERVICE_ROLE_KEY")!;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const SUSPEND_DURATION = "876000h"; // ~100 years: suspended until an admin lifts it

function cors(req: Request): Record<string, string> {
  const origin = req.headers.get("Origin") ?? "";
  return {
    "Access-Control-Allow-Origin": ALLOWED_ORIGINS.has(origin) ? origin : "https://letsrehearse.studio",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}

function json(req: Request, body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...cors(req) },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(req) });
  if (req.method !== "POST") return json(req, { error: "Method not allowed" }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) return json(req, { error: "Not signed in" }, 401);

  // Checks run as the caller, so is_admin() sees their JWT (including its aal claim).
  const caller = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await caller.auth.getUser(authHeader.slice(7));
  if (userError || !userData.user) return json(req, { error: "Session expired. Sign in again." }, 401);
  const { data: isAdmin, error: adminError } = await caller.rpc("is_admin");
  if (adminError || isAdmin !== true) return json(req, { error: "Not authorized" }, 403);

  let body: { action?: string; user_id?: string; reason?: string };
  try {
    body = await req.json();
  } catch {
    return json(req, { error: "Invalid JSON" }, 400);
  }
  const { action, user_id: targetId } = body;
  const reason = typeof body.reason === "string" ? body.reason.trim().slice(0, 500) : "";
  if (action !== "suspend" && action !== "unsuspend") return json(req, { error: "Unknown action" }, 400);
  if (!targetId || !UUID.test(targetId)) return json(req, { error: "Invalid user id" }, 400);
  if (targetId === userData.user.id) return json(req, { error: "You can't suspend your own account" }, 400);

  const service = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: targetAdmin } = await service.from("admins").select("user_id").eq("user_id", targetId).maybeSingle();
  if (targetAdmin) return json(req, { error: "Admins can't be suspended here" }, 400);

  const { data: updated, error: updateError } = await service.auth.admin.updateUserById(targetId, {
    ban_duration: action === "suspend" ? SUSPEND_DURATION : "none",
  });
  if (updateError || !updated.user) {
    return json(req, { error: updateError?.message ?? "User not found" }, updateError?.status ?? 404);
  }

  const { error: logError } = await service.from("admin_audit_log").insert({
    admin_id: userData.user.id,
    admin_email: userData.user.email,
    action: action === "suspend" ? "user.suspend" : "user.unsuspend",
    target_type: "user",
    target_id: targetId,
    details: { email: updated.user.email, reason: reason || null },
  });
  if (logError) console.error("audit log insert failed", logError.message);

  return json(req, {
    ok: true,
    user_id: targetId,
    banned_until: (updated.user as { banned_until?: string | null }).banned_until ?? null,
  });
});

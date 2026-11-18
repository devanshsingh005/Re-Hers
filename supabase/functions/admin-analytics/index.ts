// Admin dashboard: reads the app's Firebase (Google Analytics 4) data through the GA Data API.
// Only callable by a dashboard admin whose session passed the authenticator step (public.is_admin()).
//
// Secrets (Supabase → Edge Functions → Secrets), never sent to the browser:
//   GA_PROPERTY_ID           numeric GA4 property id, e.g. 412345678
//   GA_SERVICE_ACCOUNT_KEY   the service account's JSON key file contents (needs Viewer on the property)
import { createClient } from "npm:@supabase/supabase-js@2";

const ALLOWED_ORIGINS = new Set([
  "https://letsrehearse.studio",
  "https://www.letsrehearse.studio",
  "http://localhost:4321",
]);

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("ANON_KEY")!;

const RANGES: Record<string, number> = { "7d": 7, "28d": 28, "90d": 90 };
const CACHE_MS = 10 * 60 * 1000;

type ReportRow = { dimensionValues?: { value: string }[]; metricValues?: { value: string }[] };
type Report = { rows?: ReportRow[]; dimensionHeaders?: { name: string }[]; metricHeaders?: { name: string }[] };

const cache = new Map<string, { at: number; body: unknown }>();
let token: { value: string; expires: number } | null = null;

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

function base64url(input: ArrayBuffer | string): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : new Uint8Array(input);
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function googleAccessToken(serviceAccount: { client_email: string; private_key: string }): Promise<string> {
  if (token && token.expires > Date.now() + 60_000) return token.value;

  const now = Math.floor(Date.now() / 1000);
  const unsigned = `${base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }))}.${base64url(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/analytics.readonly",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }))}`;

  const pem = serviceAccount.private_key.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned));

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${unsigned}.${base64url(signature)}`,
    }),
  });
  const body = await res.json();
  if (!res.ok) throw new Error(`Google sign-in failed: ${body.error_description ?? body.error ?? res.status}`);
  token = { value: body.access_token, expires: Date.now() + body.expires_in * 1000 };
  return token.value;
}

async function ga(path: string, accessToken: string, payload: unknown) {
  const res = await fetch(`https://analyticsdata.googleapis.com/v1beta/${path}`, {
    method: "POST",
    headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  const body = await res.json();
  if (!res.ok) throw new Error(body.error?.message ?? `Google Analytics returned ${res.status}`);
  return body;
}

/** Turns a GA report into plain objects keyed by dimension/metric name. */
function rows(report: Report | undefined): Record<string, string | number>[] {
  if (!report?.rows) return [];
  const dims = report.dimensionHeaders?.map((h) => h.name) ?? [];
  const mets = report.metricHeaders?.map((h) => h.name) ?? [];
  return report.rows.map((row) => {
    const out: Record<string, string | number> = {};
    dims.forEach((d, i) => (out[d] = row.dimensionValues?.[i]?.value ?? ""));
    mets.forEach((m, i) => (out[m] = Number(row.metricValues?.[i]?.value ?? 0)));
    return out;
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(req) });
  if (req.method !== "POST") return json(req, { error: "Method not allowed" }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) return json(req, { error: "Not signed in" }, 401);
  const caller = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: isAdmin, error: adminError } = await caller.rpc("is_admin");
  if (adminError || isAdmin !== true) return json(req, { error: "Not authorized" }, 403);

  let range = "28d";
  try {
    const body = await req.json();
    if (typeof body?.range === "string" && body.range in RANGES) range = body.range;
  } catch { /* default range */ }

  const propertyId = (Deno.env.get("GA_PROPERTY_ID") ?? "").trim().replace(/^properties\//, "");
  const keyJson = Deno.env.get("GA_SERVICE_ACCOUNT_KEY") ?? "";
  const missing = [!propertyId && "GA_PROPERTY_ID", !keyJson && "GA_SERVICE_ACCOUNT_KEY"].filter(Boolean);
  if (missing.length) return json(req, { connected: false, missing });

  const cached = cache.get(range);
  if (cached && Date.now() - cached.at < CACHE_MS) return json(req, cached.body);

  try {
    const accessToken = await googleAccessToken(JSON.parse(keyJson));
    const days = RANGES[range];
    const dateRanges = [{ startDate: `${days - 1}daysAgo`, endDate: "today" }];
    const property = `properties/${propertyId}`;

    const [first, second] = await Promise.all([
      ga(`${property}:batchRunReports`, accessToken, {
        requests: [
          {
            dateRanges: [{ startDate: "27daysAgo", endDate: "today" }],
            metrics: [{ name: "active1DayUsers" }, { name: "active7DayUsers" }, { name: "active28DayUsers" }],
          },
          {
            dateRanges,
            metrics: [
              { name: "activeUsers" }, { name: "newUsers" }, { name: "sessions" }, { name: "screenPageViews" },
              { name: "eventCount" }, { name: "userEngagementDuration" }, { name: "engagedSessions" },
            ],
          },
          {
            dateRanges,
            dimensions: [{ name: "date" }],
            metrics: [{ name: "activeUsers" }, { name: "newUsers" }, { name: "screenPageViews" }, { name: "eventCount" }],
            orderBys: [{ dimension: { dimensionName: "date" } }],
          },
          {
            dateRanges,
            dimensions: [{ name: "unifiedScreenName" }],
            metrics: [{ name: "screenPageViews" }, { name: "activeUsers" }, { name: "userEngagementDuration" }],
            orderBys: [{ metric: { metricName: "screenPageViews" }, desc: true }],
            limit: 20,
          },
          {
            dateRanges,
            dimensions: [{ name: "eventName" }],
            metrics: [{ name: "eventCount" }, { name: "totalUsers" }],
            orderBys: [{ metric: { metricName: "eventCount" }, desc: true }],
            limit: 40,
          },
        ],
      }),
      ga(`${property}:batchRunReports`, accessToken, {
        requests: [
          {
            dateRanges,
            dimensions: [{ name: "country" }],
            metrics: [{ name: "activeUsers" }, { name: "newUsers" }],
            orderBys: [{ metric: { metricName: "activeUsers" }, desc: true }],
            limit: 20,
          },
          { dateRanges, dimensions: [{ name: "newVsReturning" }], metrics: [{ name: "activeUsers" }] },
          {
            dateRanges,
            dimensions: [{ name: "appVersion" }],
            metrics: [{ name: "activeUsers" }],
            orderBys: [{ metric: { metricName: "activeUsers" }, desc: true }],
            limit: 10,
          },
          {
            dateRanges,
            dimensions: [{ name: "deviceCategory" }],
            metrics: [{ name: "activeUsers" }],
            orderBys: [{ metric: { metricName: "activeUsers" }, desc: true }],
          },
        ],
      }),
    ]);

    // Optional extras: a failure here shouldn't hide the main reports.
    const [realtime, retention] = await Promise.allSettled([
      ga(`${property}:runRealtimeReport`, accessToken, { metrics: [{ name: "activeUsers" }] }),
      ga(`${property}:runReport`, accessToken, {
        dimensions: [{ name: "cohort" }, { name: "cohortNthWeek" }],
        metrics: [{ name: "cohortActiveUsers" }],
        cohortSpec: {
          cohorts: [5, 4, 3, 2, 1].map((weeksAgo) => ({
            name: `week_${weeksAgo}`,
            dimension: "firstSessionDate",
            dateRange: { startDate: `${weeksAgo * 7 + 6}daysAgo`, endDate: `${weeksAgo * 7}daysAgo` },
          })),
          cohortsRange: { granularity: "WEEKLY", startOffset: 0, endOffset: 5 },
        },
      }),
    ]);

    const [activeWindows, totals, trend, screens, events] = first.reports as Report[];
    const [countries, newVsReturning, appVersions, devices] = second.reports as Report[];

    const body = {
      connected: true,
      range,
      generated_at: new Date().toISOString(),
      active: rows(activeWindows)[0] ?? {},
      totals: rows(totals)[0] ?? {},
      trend: rows(trend),
      screens: rows(screens),
      events: rows(events),
      countries: rows(countries),
      new_vs_returning: rows(newVsReturning),
      app_versions: rows(appVersions),
      devices: rows(devices),
      realtime_active: realtime.status === "fulfilled" ? Number(realtime.value.rows?.[0]?.metricValues?.[0]?.value ?? 0) : null,
      retention: retention.status === "fulfilled" ? rows(retention.value) : null,
    };
    cache.set(range, { at: Date.now(), body });
    return json(req, body);
  } catch (error) {
    console.error("analytics failed", error);
    return json(req, { connected: true, error: error instanceof Error ? error.message : String(error) }, 502);
  }
});

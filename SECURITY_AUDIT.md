# SECURITY AUDIT

Scope: every `.swift` and `.py` file in `/Users/user30/Documents/Re-Hers`, excluding ignored paths requested by the audit instructions.

---
**[HIGH]** — Plain HTTP backend endpoint is allowed by default
**File:** `backend/app/config.py` line 11
**Code:**
```python
AUDIVERIS_API_URL = os.getenv("AUDIVERIS_API_URL", "http://localhost:8080")
```
**Why it is a problem:** The backend defaults to a non-TLS endpoint for document conversion. Under the audit rules, any HTTP endpoint is a finding. If this setting leaks outside a strictly local-only deployment, uploaded documents and returned data can be intercepted or modified in transit.
**Exact fix:** Remove the `http://` default, require an explicit `https://` URL in production, and hard-fail startup when a non-loopback HTTP URL is configured.

---
**[HIGH]** — JWT is decoded without signature verification
**File:** `backend/app/limiter.py` line 49
**Code:**
```python
payload = jwt.decode(
    token,
    options={"verify_signature": False},
    algorithms=["HS256", "RS256", "ES256"],
)
```
**Why it is a problem:** This accepts attacker-controlled JWT contents before cryptographic validation. Even if the code claims this is “only” for rate limiting, it still trusts unverified token claims in a security control and creates a bypass surface where attackers can forge arbitrary `sub` values to manipulate throttling behavior.
**Exact fix:** Do not parse bearer tokens without verification. Either derive the limiter key after full auth, or verify the JWT signature and issuer/audience before using any claim.

---
**[MEDIUM]** — Malformed bearer tokens are silently swallowed in rate limiting
**File:** `backend/app/limiter.py` line 57
**Code:**
```python
        except Exception:
            pass  # malformed / expired token → fall through to IP key
```
**Why it is a problem:** Broad exception handling plus a silent fallback hides token parsing failures and turns invalid bearer tokens into anonymous-IP traffic. Under the audit rules, silent failures in auth-adjacent code are findings because they obscure attack attempts and make abuse harder to detect.
**Exact fix:** Catch only expected JWT parsing errors, log them at a security-relevant level without echoing the token, and explicitly decide whether malformed bearer tokens should be rejected instead of silently downgraded.

---
**[MEDIUM]** — Rate limiter is configured to fail open
**File:** `backend/app/limiter.py` line 66
**Code:**
```python
    swallow_errors=True,        # fail open if Redis is transiently unavailable
```
**Why it is a problem:** If Redis is unavailable, rate limiting is disabled instead of degraded safely. That creates a deliberate abuse window for flooding upload and admin routes during backend dependency instability.
**Exact fix:** Set `swallow_errors=False` for security-sensitive endpoints, or implement a bounded local fallback that still enforces minimum throttling during Redis outages.

---
**[CRITICAL]** — User-scoped JSON outputs are published through public storage URLs
**File:** `backend/app/storage.py` line 75
**Code:**
```python
public_url = self.client.storage.from_(self.bucket).get_public_url(storage_path)
```
**Why it is a problem:** This converts per-user `output.json` artifacts into bearerless public links. Anyone who learns or guesses the path structure can bypass the authenticated `get_file_for_user()` flow and retrieve another user's data directly from storage.
**Exact fix:** Keep per-user buckets private, remove `get_public_url(...)` for user artifacts, and only serve access through authenticated API routes or short-lived signed URLs issued after ownership verification.

---
**[MEDIUM]** — Storage deletion failures are printed and ignored
**File:** `backend/app/storage.py` line 159
**Code:**
```python
        except Exception as e:
            print(f"Warning: Failed to delete from storage: {e}")
```
**Why it is a problem:** This is a broad exception handler that logs internal failure details to stdout and then continues. That hides partial-delete conditions, leaves orphaned user data behind, and can expose backend/storage internals through logs.
**Exact fix:** Catch specific storage exceptions, log sanitized context through the application logger, and fail the delete request or mark the record for secure retry instead of silently continuing.

---
**[MEDIUM]** — Queue status update failure is silently suppressed
**File:** `backend/app/main.py` line 211
**Code:**
```python
            except Exception:
                pass
```
**Why it is a problem:** If the backend fails to mark a rejected job as failed, the exception is swallowed and the system loses security-relevant state about what happened to a user submission. Under the audit rules, silent failure in a state-changing path is a finding.
**Exact fix:** Catch the specific database/storage exception, log sanitized context, and surface or retry the failure instead of suppressing it.

---
**[MEDIUM]** — Admin endpoints expose raw internal exception text to clients
**File:** `backend/app/main.py` line 385
**Code:**
```python
raise HTTPException(status_code=500, detail=str(e))
```
**Why it is a problem:** This returns backend exception text directly to API callers on admin routes. Exception strings frequently leak schema names, storage paths, infrastructure state, or stack-adjacent implementation details that attackers can use for follow-on exploitation.
**Exact fix:** Return a generic server error message to clients and log the detailed exception only on the server side with sanitized structured logging.

---
**[MEDIUM]** — Second admin endpoint also leaks raw internal exception text
**File:** `backend/app/main.py` line 404
**Code:**
```python
raise HTTPException(status_code=500, detail=str(e))
```
**Why it is a problem:** Same exposure pattern as above. This turns backend internals into a client-visible API surface instead of containing them to server logs.
**Exact fix:** Replace client-visible `str(e)` with a generic message and keep detailed diagnostics server-side only.

---
**[CRITICAL]** — Labeled PDFs are turned into permanent public URLs
**File:** `backend/app/dispatcher.py` line 442
**Code:**
```python
labeled_pdf_url = f"{supabase_url}/storage/v1/object/public/pdf_uploads/{pdf_result['storage_path']}"
```
**Why it is a problem:** This exposes user-owned labeled PDFs outside the authenticated `/sheets/{job_id}/pdf` path. Access control falls back to URL secrecy, which is not authorization.
**Exact fix:** Keep the storage bucket private and return only an authenticated application route or a short-lived signed URL created after verifying the caller owns the job.

---
**[CRITICAL]** — Conversion results are published at permanent public JSON URLs
**File:** `backend/app/dispatcher.py` line 465
**Code:**
```python
result_url = f"{supabase_url}/storage/v1/object/public/sheet_data/{output_json_path}"
```
**Why it is a problem:** This publishes user conversion output at a stable public endpoint even though the backend contains authenticated access paths. Any party with the URL can bypass database ownership checks and fetch the artifact directly.
**Exact fix:** Store a private storage path or internal route reference instead of a public URL, and require authenticated fetches or short-lived signed URLs.

---
**[HIGH]** — Upload validation trusts attacker-controlled MIME type instead of file contents
**File:** `backend/app/main.py` line 149
**Code:**
```python
allowed_types = ["application/pdf", "image/jpeg", "image/jpg"]
if file.content_type not in allowed_types:
```
**Why it is a problem:** `content_type` is client-controlled metadata. An attacker can send arbitrary content while claiming it is a PDF or JPEG, pushing untrusted bytes deeper into the conversion pipeline and third-party parsers.
**Exact fix:** Validate the actual file signature/magic bytes after upload, reject malformed content early, and enforce separate parser paths for PDFs and images based on verified file type rather than header metadata.

---
**[MEDIUM]** — Job listing endpoint over-fetches full database rows to clients
**File:** `backend/app/database.py` line 84
**Code:**
```python
response = self.client.table("jobs").select("*").eq(
    "user_id", user_id
).order("created_at", desc=True).range(offset, offset + limit).execute()
```
**Why it is a problem:** Returning `select("*")` for user-visible job listings exposes every column in the jobs table, including internal fields such as storage paths, backend status internals, and error details that may not be necessary for the client. Under the audit rules, over-fetching internal objects is a data-exposure finding.
**Exact fix:** Replace `select("*")` with an explicit allowlist of fields required by the client and omit backend-internal columns such as storage paths and raw internal error text.

---
**[MEDIUM]** — Job status endpoint returns raw backend error text to the client
**File:** `backend/app/main.py` line 267
**Code:**
```python
if job.get("error_message"):
    response["error"] = job["error_message"]
```
**Why it is a problem:** This reflects stored backend error text back to users. Error messages frequently contain parser failures, storage paths, upstream service details, or stack-adjacent internals that attackers can use to map the system.
**Exact fix:** Return sanitized, client-safe error codes/messages and keep detailed failure diagnostics only in server-side logs.

---
**[MEDIUM]** — Orphan detection treats every storage download exception as “file missing”
**File:** `backend/app/orphan_detector.py` line 53
**Code:**
```python
                except Exception:
                    # File doesn't exist in storage
                    orphaned_db_records.append({
```
**Why it is a problem:** Broad exception handling collapses permission errors, network failures, and transient backend faults into the same “missing file” state. That can trigger incorrect cleanup decisions against live data during attack or outage conditions.
**Exact fix:** Catch only the precise storage “not found” exception, log other failures distinctly, and abort cleanup decisions when the storage backend is unhealthy.

---
**[MEDIUM]** — Orphan cleanup prints internal storage errors and continues
**File:** `backend/app/orphan_detector.py` line 107
**Code:**
```python
print(f"Failed to delete storage file {storage_path}: {e}")
```
**Why it is a problem:** This leaks internal storage paths and backend error details to stdout while silently continuing. Under the audit rules, broad exception handling plus unredacted operational logging is a security issue.
**Exact fix:** Replace `print(...)` with sanitized structured logging and fail or quarantine cleanup work when deletion errors occur.

---
**[MEDIUM]** — Orphan cleanup also prints database update failures and continues
**File:** `backend/app/orphan_detector.py` line 119
**Code:**
```python
print(f"Failed to mark file as orphaned: {e}")
```
**Why it is a problem:** This exposes raw exception text and suppresses a state-management failure in an admin cleanup path, leaving audit state inconsistent and hiding the problem from callers.
**Exact fix:** Log sanitized details through the application logger and return an explicit partial-failure result instead of continuing silently.

---
**[HIGH]** — Worker readiness check sends unauthenticated HTTP probes to the conversion backend
**File:** `backend/worker.py` line 136
**Code:**
```python
response = http_session.post(AUDIVERIS_API_URL, timeout=5)
```
**Why it is a problem:** This is a second plain-HTTP attack surface and it actively transmits requests to the conversion backend without TLS or peer verification guarantees if `AUDIVERIS_API_URL` is insecure. Under the audit rules, any HTTP endpoint is a finding.
**Exact fix:** Require HTTPS for the backend URL, verify TLS certificates, and use a dedicated authenticated health/readiness endpoint instead of POSTing blindly to the conversion root.

---
**[MEDIUM]** — Worker startup retry path swallows all exception types into retry logic
**File:** `backend/worker.py` line 276
**Code:**
```python
                except Exception as exc:  # noqa: BLE001
```
**Why it is a problem:** A blanket catch in infrastructure control flow can mask credential issues, authorization failures, corrupted state, or programming errors as transient startup problems. Under the audit rules, broad exception handling in security-sensitive infrastructure paths is a finding.
**Exact fix:** Catch only expected transient exceptions, fail fast on authentication/authorization/configuration errors, and log a security-relevant event for non-retryable failures.

---
**[MEDIUM]** — Note labeling logs upstream stdout/stderr directly
**File:** `backend/app/label_notes.py` line 327
**Code:**
```python
if "detail" in data:
    logger.error(f"Audiveris error detail: {data.get('detail')}")
if "stderr" in data:
    logger.error(f"Audiveris stderr: {data.get('stderr')}")
if "stdout" in data:
    logger.error(f"Audiveris stdout: {data.get('stdout')}")
```
**Why it is a problem:** This copies untrusted upstream process output directly into application logs. Those strings can contain file paths, document fragments, parser internals, or attacker-supplied content, creating both data-exposure and log-injection risk.
**Exact fix:** Sanitize and truncate upstream error content before logging, and avoid logging raw stdout/stderr from document-processing services.

---
**[LOW]** — Invalid note metadata is silently accepted with fallback behavior
**File:** `backend/app/label_notes.py` line 216
**Code:**
```python
        except (ValueError, TypeError):
            pass
```
**Why it is a problem:** This silently suppresses malformed input while continuing processing with fallback defaults. Under the audit rules, silent handling of malformed external data is a finding because it hides parser abuse and reduces visibility into malicious inputs.
**Exact fix:** Log sanitized validation failures and either reject malformed note metadata or count/report the corruption explicitly instead of suppressing it.

---
**[MEDIUM]** — App stores authentication state in `UserDefaults`
**File:** `Screens/MainLoginSignupScreen/AuthViewController.swift` line 696
**Code:**
```swift
UserDefaults.standard.set(true, forKey: "isLoggedIn")
```
**Why it is a problem:** `UserDefaults` is not a secure storage mechanism for auth state. Even though this is only a boolean, the app uses it to gate routing, which means local tampering can influence authentication flow and session handling.
**Exact fix:** Remove `isLoggedIn` from `UserDefaults` and derive login state only from the actual authenticated Supabase session stored in the Keychain.

---
**[MEDIUM]** — Startup routing trusts a mutable `UserDefaults` auth flag
**File:** `Re-Hearse_v1/SceneDelegate.swift` line 35
**Code:**
```swift
let isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
```
**Why it is a problem:** The initial route decision depends on a user-modifiable local preference instead of a cryptographically protected session source. That creates an auth-state tampering surface and weakens logout/session integrity on compromised devices.
**Exact fix:** Remove this flag from routing and determine the initial screen exclusively from the current Supabase session and onboarding state.

---
**[MEDIUM]** — No app-switcher privacy protection is implemented for sensitive screens
**File:** `Re-Hearse_v1/SceneDelegate.swift` line 145
**Code:**
```swift
func sceneDidEnterBackground(_ scene: UIScene) {
    // Called as the scene transitions from the foreground to the background.
```
**Why it is a problem:** This background transition hook is empty, so the app does not obscure potentially sensitive content before the iOS app-switcher snapshot is taken. Under the audit rules, absence of screen privacy protection on auth/profile/document views is a risk.
**Exact fix:** Add a privacy overlay or blur in `sceneWillResignActive`/`sceneDidEnterBackground` and remove it on foreground entry for any screen that may contain account or document data.

---
**[HIGH]** — Hardcoded Supabase project URL in source
**File:** `SupabaseBackend/SupabaseManager.swift` line 21
**Code:**
```swift
let urlString = "https://djqgmowfjxsnjdffdohw.supabase.co"
```
**Why it is a problem:** Your audit rules explicitly require flagging Supabase URLs in source. Hardcoding backend coordinates in the client increases fingerprinting, ties builds to a single environment, and makes configuration rotation harder.
**Exact fix:** Move backend URLs into environment-specific build configuration and keep production values out of source-controlled literals.

---
**[HIGH]** — Hardcoded Supabase publishable key in client source
**File:** `SupabaseBackend/SupabaseManager.swift` line 22
**Code:**
```swift
let key       = "sb_publishable__FkMcK1683czdRktkt7YsA_vYR4ZsOW"
```
**Why it is a problem:** The audit rules require flagging any hardcoded key-like credential, including Supabase publishable/anon-style keys. Shipping it in source and the app binary exposes it permanently and complicates rotation.
**Exact fix:** Inject the key from build configuration or remote configuration, keep it out of source control, and rotate the currently embedded key.

---
**[MEDIUM]** — Force unwrap in auth/bootstrap configuration is a crash vector
**File:** `SupabaseBackend/SupabaseManager.swift` line 27
**Code:**
```swift
supabaseURL: URL(string: urlString)!,
```
**Why it is a problem:** Under the audit rules, force unwraps in security-sensitive code paths are findings. If configuration is corrupted or modified, this crashes the auth/bootstrap path and creates a denial-of-service vector.
**Exact fix:** Replace the force unwrap with guarded URL validation and fail closed with a controlled error path.

---
**[CRITICAL]** — Upload flow hardcodes a public Supabase storage base URL
**File:** `Screens/MainUploadScreen/UploadScreen.swift` line 45
**Code:**
```swift
private let storageBaseURL = "https://djqgmowfjxsnjdffdohw.supabase.co/storage/v1/object/public"
```
**Why it is a problem:** This bakes the public object endpoint directly into the client upload flow for user-owned artifacts. It encourages the app to consume private outputs through anonymous public storage instead of authenticated application routes.
**Exact fix:** Remove public storage URL construction from the client and fetch user artifacts only through authenticated backend endpoints or short-lived signed URLs.

---
**[HIGH]** — Upload flow logs auth/token retrieval failures directly
**File:** `Screens/MainUploadScreen/UploadScreen.swift` line 744
**Code:**
```swift
catch { print("[Auth] token error: \(error)"); return nil }
```
**Why it is a problem:** Auth-path failures are printed directly to logs. Depending on SDK error content, these messages can expose session details, backend responses, or device-specific auth state to logs that should not carry sensitive auth context.
**Exact fix:** Replace `print(...)` with sanitized error handling that avoids logging raw auth exceptions in production builds.

---
**[HIGH]** — Upload flow exposes internal artifact paths in logs
**File:** `Screens/MainUploadScreen/UploadScreen.swift` line 773
**Code:**
```swift
print("[Upload] pdfPath=\(pdfPath)")
print("[Upload] outputURL=\(outputURL)")
```
**Why it is a problem:** These logs expose user-specific storage paths and output URLs. In this codebase those URLs are usable artifact locators, so logging them expands the blast radius of any device log collection or crash-report leak.
**Exact fix:** Remove these logs in production and never log user-scoped storage paths or result URLs.

---
**[MEDIUM]** — Bearer-token upload request has no certificate pinning
**File:** `Screens/MainUploadScreen/UploadScreen.swift` line 828
**Code:**
```swift
let url      = URL(string: "https://re-hers-api.bravesea-cec8c7b0.eastus.azurecontainerapps.io/convert")!
...
req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
```
**Why it is a problem:** The audit rules require flagging the absence of certificate pinning on endpoints handling auth data. This request carries a bearer token and user document payload over standard `URLSession.shared` with no pinning or custom trust evaluation.
**Exact fix:** Use a dedicated `URLSession` with certificate/public-key pinning for auth-bearing requests to the conversion backend, or route the operation through the Supabase SDK if that is the supported trust boundary.

---
**[MEDIUM]** — Conversion API URL is force unwrapped in a security-sensitive path
**File:** `Screens/MainUploadScreen/UploadScreen.swift` line 828
**Code:**
```swift
let url      = URL(string: "https://re-hers-api.bravesea-cec8c7b0.eastus.azurecontainerapps.io/convert")!
```
**Why it is a problem:** This is a force unwrap in a token-bearing upload path. Under the audit rules, that is a crash vector and therefore a finding.
**Exact fix:** Replace the force unwrap with guarded URL construction and fail the request cleanly if configuration is invalid.

---
**[CRITICAL]** — Client reconstructs a public URL for user-owned JSON output
**File:** `Screens/MainUploadScreen/UploadPageNextViewController.swift` line 182
**Code:**
```swift
return "https://\(projectID).supabase.co/storage/v1/object/public/sheet_data/\(userId)/\(jobId.uuidString.lowercased())/output.json"
```
**Why it is a problem:** This derives a permanent public URL for a user-specific conversion result from predictable identifiers. That bypasses authenticated backend access and turns path knowledge into direct data access if the bucket is public.
**Exact fix:** Stop deriving public storage URLs on the client. Request the artifact through an authenticated backend endpoint or a signed URL issued after ownership verification.

---
**[HIGH]** — Upload detail screen logs raw storage paths and result URLs
**File:** `Screens/MainUploadScreen/UploadPageNextViewController.swift` line 150
**Code:**
```swift
print("[Load] pdf_path=\(row.pdfPath)  db_result_url=\(row.resultUrl ?? "nil")")
```
**Why it is a problem:** This prints backend storage paths and result URLs directly to logs. Those values are sensitive locators for user-owned artifacts in this codebase.
**Exact fix:** Remove these logs from production and avoid printing user-scoped storage or result-location data.

---
**[MEDIUM]** — Upload detail screen silently suppresses polling/database failures
**File:** `Screens/MainUploadScreen/UploadPageNextViewController.swift` line 311
**Code:**
```swift
} catch {
    print("[Poll] ⚠️ DB error: \(error.localizedDescription)")
}
```
**Why it is a problem:** A state-management failure in the job-status path is reduced to a print and otherwise ignored. Under the audit rules, silent failures in security-relevant or data-access paths are findings.
**Exact fix:** Surface the failure to the user in a controlled way, stop polling, and log sanitized telemetry instead of suppressing the error.

---
**[CRITICAL]** — Completed-job screen treats labeled PDFs as public, unauthenticated assets
**File:** `Screens/MainUploadScreen/UploadPageNextViewController.swift` line 328
**Code:**
```swift
let publicBase = "https://\(projectID).supabase.co/storage/v1/object/public"
...
let pdfPublicURL = relPath.hasPrefix("http") ? relPath : "\(publicBase)/\(relPath)"
```
**Why it is a problem:** This code is explicitly designed to fetch completed labeled PDFs from public storage with no auth. That is a direct data-exposure path for user-owned documents.
**Exact fix:** Remove the public-base construction and fetch completed PDFs only through authenticated API routes or server-issued signed URLs.

---
**[MEDIUM]** — Force unwrap of attacker-influenced URL string in JSON fetch path
**File:** `Screens/MainUploadScreen/UploadPageNextViewController.swift` line 352
**Code:**
```swift
let (data, response) = try await URLSession.shared.data(from: URL(string: jsonURL)!)
```
**Why it is a problem:** This is a force unwrap in a path that operates on a dynamically constructed URL. Under the audit rules, force unwraps in data-fetch flows are crash vectors and must be flagged.
**Exact fix:** Validate the URL with `guard let` and fail cleanly when the constructed value is invalid.

---
**[MEDIUM]** — Signup flow logs the raw authentication result object
**File:** `Screens/MainLoginSignupScreen/AuthViewController.swift` line 870
**Code:**
```swift
print("SIGNUP RESULT:", result)
```
**Why it is a problem:** Auth result objects commonly contain session metadata, user identifiers, or token-adjacent state. Logging them verbatim is a data-exposure risk.
**Exact fix:** Remove this log entirely, or log only sanitized non-sensitive status information in debug builds.

---
**[MEDIUM]** — OAuth onboarding flow prints user onboarding data and raw errors
**File:** `Screens/MainLoginSignupScreen/AuthViewController.swift` line 786
**Code:**
```swift
print("Google Auth Onboarding Check - Retrieved Genres: \(String(describing: row.genres))")
...
print("Google Auth Onboarding Check - No record found: \(error.localizedDescription)")
```
**Why it is a problem:** This logs user profile/onboarding data and backend error text during authentication. That is both a privacy leak and an information-disclosure issue.
**Exact fix:** Remove these prints from production and replace them with sanitized, non-user-specific debug telemetry if needed.

---
**[MEDIUM]** — Email auth flow also logs onboarding data and backend errors
**File:** `Screens/MainLoginSignupScreen/AuthViewController.swift` line 917
**Code:**
```swift
print("Email Auth Onboarding Check - Retrieved Genres: \(String(describing: row.genres))")
...
print("Email Auth Onboarding Check - No record found: \(error.localizedDescription)")
```
**Why it is a problem:** Same data-exposure pattern as the Google flow, but on the email/password login path.
**Exact fix:** Remove the logs and avoid printing user onboarding content or backend error strings during auth.

---
**[CRITICAL]** — Discovery conversion flow falls back to a public user-output URL
**File:** `Screens/MainDiscoverScreen/DiscoverSongPreviewViewController.swift` line 401
**Code:**
```swift
let outputURL = (api["output_url"] as? String)
    ?? "\(supabaseBase)/storage/v1/object/public/sheet_data/\(apiUidStr.lowercased())/\(jobIdStr.lowercased())/output.json"
```
**Why it is a problem:** When the backend does not return an output URL, the client guesses a public storage path for a user-scoped artifact. That recreates the authorization bypass client-side.
**Exact fix:** Remove the fallback entirely. Treat a missing output location as an error and fetch the result only through an authenticated backend path or signed URL.

---
**[HIGH]** — Discovery conversion flow logs artifact URLs and auth-path failures
**File:** `Screens/MainDiscoverScreen/DiscoverSongPreviewViewController.swift` line 373
**Code:**
```swift
print("[Convert] PDF resolved: \(urlString)")
...
print("[Convert] API keys: \(api.keys.sorted())")
...
catch { print("[Auth] \(error)"); return nil }
```
**Why it is a problem:** This logs document URLs, backend response shape, and raw auth failures in a user-data path. That creates avoidable disclosure through device logs.
**Exact fix:** Remove these logs from production and replace them with sanitized diagnostics that exclude document locations and auth/backend error text.

---
**[MEDIUM]** — Discovery upload request sends bearer token with no certificate pinning
**File:** `Screens/MainDiscoverScreen/DiscoverSongPreviewViewController.swift` line 455
**Code:**
```swift
let url      = URL(string: "https://re-hers-api.bravesea-cec8c7b0.eastus.azurecontainerapps.io/convert")!
...
req.setValue("Bearer \(token)",                            forHTTPHeaderField: "Authorization")
```
**Why it is a problem:** This is another token-bearing `URLSession.shared` request with no certificate pinning. The audit rules require flagging absence of pinning for auth-sensitive endpoints.
**Exact fix:** Use a pinned `URLSession` for this backend or move the operation behind a trusted SDK/backend boundary that already enforces certificate validation policy.

---
**[CRITICAL]** — Profile photo upload publishes user avatars to public storage
**File:** `Screens/ProfileScreen/UserProfileViewController.swift` line 791
**Code:**
```swift
let publicURL = "https://\(projectRef).supabase.co/storage/v1/object/public/useprofile/\(fileName)"
```
**Why it is a problem:** This stores profile photos at a permanent public URL and persists that URL in the profile record. User avatars are user-owned media and this design makes them anonymously accessible by URL.
**Exact fix:** Store avatars in a private bucket or serve them via signed/authenticated URLs, and do not persist permanent public object URLs for user-owned media.

---
**[HIGH]** — Multiple UI components deliberately rewrite private avatar paths to public object URLs
**File:** `Common/UIComponents/TopNavbar/NavigationBarHelper.swift` line 260
**Code:**
```swift
finalURLString = urlString.replacingOccurrences(of: "/object/useprofile/", with: "/object/public/useprofile/")
```
**Why it is a problem:** This code intentionally converts a non-public storage path into a public one. The same pattern also appears in `Screens/MainUploadScreen/UploadScreen.swift:227`, `Screens/LearningCurve/LessonMapViewController.swift:224`, and `Screens/MainDiscoverScreen/DiscoverViewController.swift:682`, which means the client is systematically bypassing authenticated media access.
**Exact fix:** Stop rewriting storage URLs to public endpoints. Use signed URLs or authenticated media fetches instead.

---
**[HIGH]** — Additional screens hardcode public Supabase object bases
**File:** `Screens/MainPlaylistScreen/SongDetailsPage.swift` line 29
**Code:**
```swift
private var publicBase: String { "https://\(projectID).supabase.co/storage/v1/object/public" }
```
**Why it is a problem:** This repeats the pattern of embedding public object storage access directly in user-facing screens. Under the strict audit rules, hardcoded Supabase object-public endpoints in source are findings.
**Exact fix:** Remove hardcoded public object bases from screens and source all artifact/media access from authenticated or signed backend URLs.

---
**[HIGH]** — Discover detail screen also hardcodes a public Supabase object base
**File:** `Screens/MainDiscoverScreen/DiscoverSongDetailViewController.swift` line 23
**Code:**
```swift
"https://\(projectID).supabase.co/storage/v1/object/public"
```
**Why it is a problem:** Same public-object exposure pattern as above, now in another user-facing screen.
**Exact fix:** Stop constructing public storage endpoints in the client and move artifact access to authenticated or signed URLs.

---
**[CRITICAL]** — Playlist detail screen fetches user JSON from a public object URL
**File:** `Screens/MainPlaylistScreen/SongDetailsPage.swift` line 300
**Code:**
```swift
guard let url = URL(string: "\(publicBase)/sheet_data/\(userId)/\(jobId.uuidString.lowercased())/output.json"),
      let (data, _) = try? await URLSession.shared.data(from: url),
```
**Why it is a problem:** This screen directly fetches a user-specific `output.json` from public storage using predictable identifiers. That is the same authorization bypass pattern found elsewhere in the app.
**Exact fix:** Remove direct public storage access and request the JSON through an authenticated backend endpoint or a signed URL issued per request.

---
**[CRITICAL]** — Playlist detail screen also reconstructs public labeled/original PDF URLs
**File:** `Screens/MainPlaylistScreen/SongDetailsPage.swift` line 310
**Code:**
```swift
urlStr = rel.hasPrefix("http") ? rel : "\(publicBase)/\(rel)"
...
urlStr = "\(publicBase)/sheet_data/\(userId)/\(jId.uuidString.lowercased())/labeled.pdf"
...
await fetchAndCache(urlString: "\(publicBase)/pdf_uploads/\(path)", isOriginal: true)
```
**Why it is a problem:** This code path is designed around public, unauthenticated storage for user-owned PDFs. It expands the same data-exposure vulnerability into the playlist detail flow.
**Exact fix:** Stop using `publicBase` for user artifacts and fetch PDFs only through authenticated backend routes or short-lived signed URLs.

---
**[MEDIUM]** — Playlist detail screen force unwraps dynamic URLs in a user-data fetch path
**File:** `Screens/MainPlaylistScreen/SongDetailsPage.swift` line 324
**Code:**
```swift
var req = URLRequest(url: URL(string: urlString)!)
```
**Why it is a problem:** Under the audit rules, force unwraps in security-sensitive data-fetch paths are crash vectors. Here the URL string is assembled dynamically from remote/database-derived values.
**Exact fix:** Guard the URL construction and fail cleanly if the value is invalid.

---
**[HIGH]** — Playlist cover uploads are published as public URLs
**File:** `Screens/MainPlaylistScreen/Managers/PlaylistsManager.swift` line 484
**Code:**
```swift
let publicUrl = try client.getPublicURL(path: fileName)
```
**Why it is a problem:** This persists playlist cover images as public objects. Even if playlist covers feel lower sensitivity than sheet data, the audit rules require flagging public exposure of user-owned media unless it is intentionally and provably public.
**Exact fix:** Store covers in a private bucket or use signed URLs with explicit access policy rather than permanent public URLs.

---
**[MEDIUM]** — Playlist cover fallback writes files to Documents without file protection
**File:** `Screens/MainPlaylistScreen/Managers/PlaylistsManager.swift` line 495
**Code:**
```swift
try data.write(to: url, options: .atomic)
```
**Why it is a problem:** This writes user media into the Documents directory without any `NSFileProtection` attributes. Under the audit rules, sensitive or user-owned local files without explicit data-protection settings are findings.
**Exact fix:** Write the file with `NSFileProtectionComplete` or stronger, or avoid persistent local fallback storage for user media.

---
**[MEDIUM]** — Playlist image loader reads arbitrary local document files by identifier
**File:** `Screens/MainPlaylistScreen/MainPlayListScreen.swift` line 381
**Code:**
```swift
let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                     .first!.appendingPathComponent(identifier)
if let data = try? Data(contentsOf: url) { return UIImage(data: data) }
```
**Why it is a problem:** This uses a string identifier to build a local file path and reads it without canonicalization or file-protection checks. The current guard only blocks `https://` and `token=` patterns; it does not prove the identifier is a safe local filename.
**Exact fix:** Restrict identifiers to an allowlisted filename format, reject path separators, avoid force unwraps, and store files with explicit protection attributes.

---
**[LOW]** — Shared image loader uses default `URLSession` behavior with no explicit timeout or response validation
**File:** `Common/UIComponents/ImageLoader.swift` line 26
**Code:**
```swift
let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
```
**Why it is a problem:** The audit rules require flagging requests without explicit timeouts. This loader also accepts any response body that decodes as an image without validating HTTP status or content type.
**Exact fix:** Use a configured `URLSessionConfiguration` with explicit request/resource timeouts and validate the HTTP response before caching the body.

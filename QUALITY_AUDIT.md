# QUALITY AUDIT

Practical scope used for this audit: all Swift application source files present in this repo and all Python files under `backend/**`, because the repo does not contain `ios/**`, `app/**`, `api/**`, or `ml/**` source trees.

---
**[HIGH]** — API module is doing service wiring at import time
**File:** `backend/app/main.py` line 49
**Rule violated:** "Any hardcoded class instantiation inside a ViewController where a protocol or injected dependency should be used" and "Any service class that does more than one domain's work"
**Code:**
```python
db_client = DatabaseClient(SUPABASE_URL, SUPABASE_KEY)
storage_manager = StorageManager(SUPABASE_URL, SUPABASE_KEY, db_client)
orphan_detector = OrphanDetector(db_client, storage_manager)
```
**What is wrong:** `main.py` is acting as endpoint layer, composition root, and service container all at once. These globals are created at import time, which makes the module hard to test, hard to override, and fragile under worker/app lifecycle changes.
**Exact fix:**
```python
from functools import lru_cache

@lru_cache
def get_db_client() -> DatabaseClient:
    return DatabaseClient(SUPABASE_URL, SUPABASE_KEY)

@lru_cache
def get_storage_manager() -> StorageManager:
    return StorageManager(SUPABASE_URL, SUPABASE_KEY, get_db_client())

@lru_cache
def get_orphan_detector() -> OrphanDetector:
    return OrphanDetector(get_db_client(), get_storage_manager())
```

---
**[MEDIUM]** — Unused imports are left in the main API module
**File:** `backend/app/main.py` line 7
**Rule violated:** "Any import that is unused — flag every one"
**Code:**
```python
from fastapi.responses import JSONResponse, FileResponse, Response
```
**What is wrong:** `JSONResponse` and `FileResponse` are imported but not used. Dead imports increase coupling and make the module harder to reason about during maintenance.
**Exact fix:**
```python
from fastapi.responses import Response
```

---
**[MEDIUM]** — Another unused import is left in the main API module
**File:** `backend/app/main.py` line 11
**Rule violated:** "Any import that is unused — flag every one"
**Code:**
```python
from rq import Queue
```
**What is wrong:** `Queue` is never used in this file. Leaving queue internals imported into the endpoint module is noise and unnecessary coupling.
**Exact fix:**
```python
# remove this import entirely
```

---
**[MEDIUM]** — Hardcoded job directory path is a magic string in the API module
**File:** `backend/app/main.py` line 54
**Rule violated:** "Any hardcoded URL, hostname, timeout value, or limit as a magic number — flag every literal that should be a config constant"
**Code:**
```python
JOBS_DIR = "jobs"
```
**What is wrong:** The API hardcodes a filesystem location instead of reading it from configuration. This makes deployment behavior implicit and environment-dependent.
**Exact fix:**
```python
from app.config import JOBS_DIR
os.makedirs(JOBS_DIR, exist_ok=True)
```

---
**[HIGH]** — Startup handler uses a broad exception boundary for infrastructure initialization
**File:** `backend/app/main.py` line 65
**Rule violated:** "Every bare except: clause — this catches SystemExit and KeyboardInterrupt and masks every possible error. Flag every one" and "except Exception as e: pass or except Exception as e: print(e) with no re-raise or recovery — flag as silent failure"
**Code:**
```python
    except Exception as exc:
        raise RuntimeError(
            f"Redis is not available — cannot start server. "
            f"Ensure Redis is running. Detail: {exc}"
        ) from exc
```
**What is wrong:** This catches every exception type from startup infrastructure, mixes transport, auth, and programming failures together, and converts them into a generic runtime error.
**Exact fix:**
```python
    except redis.RedisError as exc:
        raise RuntimeError("Redis is not available — cannot start server.") from exc
```

---
**[HIGH]** — Endpoint function is using an untyped `dict` for authenticated user data
**File:** `backend/app/main.py` line 133
**Rule violated:** "Dict or List used without generics where TypedDict or a dataclass would be appropriate — flag each instance"
**Code:**
```python
user: dict = Depends(get_current_user)
```
**What is wrong:** The endpoint contract hides the shape of the authenticated user object. Every caller has to guess which keys exist.
**Exact fix:**
```python
class AuthenticatedUser(TypedDict):
    id: str
    email: str | None
    user_metadata: dict[str, str]

user: AuthenticatedUser = Depends(get_current_user)
```

---
**[HIGH]** — Upload endpoint mixes validation, persistence, queueing, and response composition in one function
**File:** `backend/app/main.py` line 130
**Rule violated:** "Any service class that does more than one domain's work"
**Code:**
```python
async def convert_pdf(
    request: Request,
    file: UploadFile = File(...),
    user: dict = Depends(get_current_user)
):
```
**What is wrong:** This endpoint validates input, reads files, enforces concurrency limits, writes storage, writes database rows, mutates status, and enqueues work. That is multiple domain responsibilities jammed into the HTTP layer.
**Exact fix:**
```python
async def convert_pdf(...):
    service = get_conversion_service()
    result = await service.submit_upload(file=file, user=user)
    return result.to_response()
```

---
**[MEDIUM]** — Upload endpoint uses a hardcoded file-size limit instead of config
**File:** `backend/app/main.py` line 163
**Rule violated:** "Any hardcoded URL, hostname, timeout value, or limit as a magic number — flag every literal that should be a config constant"
**Code:**
```python
MAX_FILE_SIZE = 100 * 1024 * 1024
```
**What is wrong:** The endpoint redefines a hardcoded size limit even though configuration already exists for this concept. This guarantees drift.
**Exact fix:**
```python
from app.config import MAX_FILE_SIZE
```

---
**[HIGH]** — Queue failure recovery swallows database update errors
**File:** `backend/app/main.py` line 211
**Rule violated:** "except Exception as e: pass or except Exception as e: print(e) with no re-raise or recovery — flag as silent failure"
**Code:**
```python
            except Exception:
                pass
```
**What is wrong:** A failed status update is silently discarded. That leaves the system in an inconsistent state and hides operational failures.
**Exact fix:**
```python
            except Exception as exc:
                logger.exception("Failed to mark rejected job as failed", exc_info=exc)
                raise
```

---
**[HIGH]** — Auth layer uses `Any` to avoid defining a real authenticated-user type
**File:** `backend/app/auth.py` line 15
**Rule violated:** "Any use of Any as a type hint where a specific type is knowable — flag as type safety evasion"
**Code:**
```python
async def verify_token(self, token: str) -> Dict[str, Any]:
```
**What is wrong:** The return shape is known and small, but the code uses `Any` anyway. That defeats static checks and makes downstream consumers weaker.
**Exact fix:**
```python
class AuthenticatedUser(TypedDict):
    id: str
    email: str | None
    user_metadata: dict[str, str]

async def verify_token(self, token: str) -> AuthenticatedUser:
```

---
**[HIGH]** — Auth layer repeats the same `Any` evasion on request parsing
**File:** `backend/app/auth.py` line 38
**Rule violated:** "Any use of Any as a type hint where a specific type is knowable — flag as type safety evasion"
**Code:**
```python
async def get_current_user(self, authorization: Optional[str] = Header(None)) -> Dict[str, Any]:
```
**What is wrong:** The method still returns a known authenticated-user shape but advertises a loose dictionary.
**Exact fix:**
```python
async def get_current_user(
    self,
    authorization: str | None = Header(None),
) -> AuthenticatedUser:
```

---
**[MEDIUM]** — Auth layer uses a broad exception boundary during token verification
**File:** `backend/app/auth.py` line 35
**Rule violated:** "except Exception as e: pass or except Exception as e: print(e) with no re-raise or recovery — flag as silent failure"
**Code:**
```python
        except Exception as e:
            raise HTTPException(status_code=401, detail="Invalid or expired token")
```
**What is wrong:** This collapses SDK errors, transport failures, and programming bugs into the same 401 path, making debugging and incident response harder.
**Exact fix:**
```python
        except AuthApiError as exc:
            raise HTTPException(status_code=401, detail="Invalid or expired token") from exc
```

---
**[MEDIUM]** — Auth module defines mutable global service state
**File:** `backend/app/auth.py` line 69
**Rule violated:** "Any global mutable state (global var outside of a type) — flag every instance"
**Code:**
```python
_auth_manager: Optional[AuthManager] = None
```
**What is wrong:** This global singleton hides lifecycle and state behind module-level mutation. It makes tests order-dependent and encourages implicit coupling.
**Exact fix:**
```python
@lru_cache
def get_auth_manager() -> AuthManager:
    return AuthManager(SUPABASE_URL, SUPABASE_KEY)
```

---
**[HIGH]** — Storage layer evades type safety with `Any` on input and output
**File:** `backend/app/storage.py` line 38
**Rule violated:** "Any use of Any as a type hint where a specific type is knowable — flag as type safety evasion"
**Code:**
```python
json_data: Dict[str, Any]
) -> Dict[str, Any]:
```
**What is wrong:** `upload_json` is a boundary object and should define an explicit payload/response contract. Using `Any` makes the interface unstable and undocumented.
**Exact fix:**
```python
class OutputJson(TypedDict):
    # explicit schema here
    ...

class UploadJsonResult(TypedDict):
    success: bool
    file_id: str
    storage_path: str
    public_url: str
    user_id: str
```

---
**[MEDIUM]** — Storage layer wraps every upload failure in a generic `Exception`
**File:** `backend/app/storage.py` line 95
**Rule violated:** "Custom exceptions defined without inheriting from a meaningful base class — flag for error hierarchy issues"
**Code:**
```python
        except Exception as e:
            raise Exception(f"Upload failed for user {user_id}: {str(e)}")
```
**What is wrong:** This destroys the original exception type and replaces it with a generic one, making upstream handling less precise.
**Exact fix:**
```python
class StorageUploadError(RuntimeError):
    pass

        except StorageApiError as exc:
            raise StorageUploadError(f"Upload failed for user {user_id}") from exc
```

---
**[MEDIUM]** — Storage deletion logs to stdout instead of returning structured failure
**File:** `backend/app/storage.py` line 160
**Rule violated:** "except Exception as e: pass or except Exception as e: print(e) with no re-raise or recovery — flag as silent failure"
**Code:**
```python
        except Exception as e:
            print(f"Warning: Failed to delete from storage: {e}")
```
**What is wrong:** The delete path fails open, logs to stdout, and then continues deleting the database record. That is poor failure semantics and inconsistent cleanup behavior.
**Exact fix:**
```python
        except StorageApiError as exc:
            logger.exception("Failed to delete storage object", exc_info=exc)
            raise
```

---
**[HIGH]** — Database layer uses `Any` throughout the public interface
**File:** `backend/app/database.py` line 24
**Rule violated:** "Any use of Any as a type hint where a specific type is knowable — flag as type safety evasion"
**Code:**
```python
) -> Dict[str, Any]:
```
**What is wrong:** `create_job`, `get_job`, `update_job_status`, `create_sheet_file`, and other methods all return untyped dictionaries even though each record shape is stable and knowable.
**Exact fix:**
```python
class JobRow(TypedDict):
    id: str
    user_id: str
    pdf_path: str
    status: str
    ...
```

---
**[HIGH]** — Database layer over-fetches full rows with `select("*")`
**File:** `backend/app/database.py` line 39
**Rule violated:** "Response serializers that expose model fields that should be internal (created_at on every object, internal IDs, related object dumps) — flag over-exposure"
**Code:**
```python
response = self.client.table("jobs").select("*").eq(
```
**What is wrong:** The data-access layer is retrieving full job rows when callers only need a subset. This bakes over-fetching into every consumer and makes accidental data exposure more likely.
**Exact fix:**
```python
response = self.client.table("jobs").select("id,status,result_url,error_message").eq(
```

---
**[MEDIUM]** — Database layer raises generic `Exception` for not-found/update failures
**File:** `backend/app/database.py` line 75
**Rule violated:** "Custom exceptions defined without inheriting from a meaningful base class — flag for error hierarchy issues"
**Code:**
```python
raise Exception("Job not found or unauthorized")
```
**What is wrong:** Generic exceptions make the boundary impossible to handle precisely and force callers into broad `except Exception` blocks.
**Exact fix:**
```python
class JobNotFoundError(LookupError):
    pass

raise JobNotFoundError("Job not found or unauthorized")
```

---
**[MEDIUM]** — In-memory model store keeps a mutable global singleton
**File:** `backend/app/models.py` line 62
**Rule violated:** "Any global mutable state (global var outside of a type) — flag every instance"
**Code:**
```python
job_store = JobStore()
```
**What is wrong:** This creates hidden shared state with process-local behavior that does not match the rest of the app’s persistent job model.
**Exact fix:**
```python
# remove the module-global singleton and inject JobStore explicitly where needed
```

---
**[HIGH]** — Job store update API accepts untyped arbitrary keyword mutation
**File:** `backend/app/models.py` line 45
**Rule violated:** "Any function returning different types under different conditions without Union typing — flag as unpredictable interface" and "Dict or List used without generics where TypedDict or a dataclass would be appropriate — flag each instance"
**Code:**
```python
def update_job(self, job_id: str, **kwargs) -> Optional[Job]:
```
**What is wrong:** The method accepts arbitrary keyword mutation with no schema. That makes the API impossible to validate statically and easy to misuse.
**Exact fix:**
```python
@dataclass(frozen=True)
class JobUpdate:
    status: JobStatus | None = None
    output_url: str | None = None
    error: str | None = None

def update_job(self, job_id: str, update: JobUpdate) -> Job | None:
```

---
**[MEDIUM]** — `JobStore.__init__` is missing a return type annotation
**File:** `backend/app/models.py` line 29
**Rule violated:** "Every function missing type hints on any parameter or return value — flag each missing annotation individually"
**Code:**
```python
def __init__(self):
```
**What is wrong:** Even constructors should be annotated in a strict codebase. Leaving it untyped weakens consistency and static checking.
**Exact fix:**
```python
def __init__(self) -> None:
```

---
**[HIGH]** — View controller is querying Supabase directly
**File:** `Screens/MainUploadScreen/UploadPageNextViewController.swift` line 136
**Rule violated:** "Any UIViewController that contains direct API calls, URLSession usage, or Supabase queries — flag every call site, not just the class"
**Code:**
```swift
let rows: [JobRow] = try await SupabaseManager.shared.client
    .from("jobs")
    .select("pdf_path, result_url")
    .eq("id", value: jobId)
    .limit(1)
    .execute()
    .value
```
**What is wrong:** This screen is acting as its own repository and networking layer. That makes it untestable, duplicates persistence logic, and ties UI lifecycle directly to backend schema.
**Exact fix:**
```swift
protocol JobStatusProviding {
    func fetchJobRow(id: UUID) async throws -> JobRow
}

@MainActor
final class UploadPageNextViewModel {
    private let jobs: JobStatusProviding

    init(jobs: JobStatusProviding) { self.jobs = jobs }

    func load(jobId: UUID) async throws -> JobRow {
        try await jobs.fetchJobRow(id: jobId)
    }
}
```

---
**[HIGH]** — View controller performs raw `URLSession` PDF loading
**File:** `Screens/MainUploadScreen/UploadPageNextViewController.swift` line 199
**Rule violated:** "Any UIViewController that contains direct API calls, URLSession usage, or Supabase queries — flag every call site, not just the class"
**Code:**
```swift
let (data, response) = try await URLSession.shared.data(for: pdfReq)
```
**What is wrong:** PDF transport is embedded in the screen instead of a document service. The controller now owns request construction, timeout policy, HTTP validation, and UI state transitions.
**Exact fix:**
```swift
protocol PDFLoading {
    func fetchPDF(from url: URL) async throws -> Data
}

struct RemotePDFLoader: PDFLoading {
    func fetchPDF(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PDFLoadError.invalidResponse
        }
        return data
    }
}
```

---
**[HIGH]** — Controller swallows database failure behind a debug print
**File:** `Screens/MainUploadScreen/UploadPageNextViewController.swift` line 172
**Rule violated:** "catch blocks that only print or log without any recovery or user feedback — flag as incomplete error handling"
**Code:**
```swift
} catch {
    print("[Load] ❌ DB error: \(error)")
    await MainActor.run { self.showSampleSheetMusic() }
}
```
**What is wrong:** The failure is reduced to console noise and a fake success path. Users get sample data instead of an explicit error state, which hides real backend failures.
**Exact fix:**
```swift
} catch {
    await MainActor.run {
        self.statusLabel.text = "We couldn't load this upload. Please try again."
        self.statusLabel.isHidden = false
        self.refreshButton.isHidden = false
        self.progressView.isHidden = true
    }
}
```

---
**[CRITICAL]** — Force unwrap can crash when derived URL is malformed
**File:** `Screens/MainUploadScreen/UploadPageNextViewController.swift` line 352
**Rule violated:** "Every single force unwrap (!) in the codebase — no exceptions. Flag each one individually with the crash scenario"
**Code:**
```swift
let (data, response) = try await URLSession.shared.data(from: URL(string: jsonURL)!)
```
**What is wrong:** Any malformed path fragment or encoding bug in `jsonURL` will terminate the app before the request is even made.
**Exact fix:**
```swift
guard let url = URL(string: jsonURL) else {
    await MainActor.run {
        self.statusLabel.text = "Invalid result URL."
        self.statusLabel.isHidden = false
    }
    return
}

let (data, response) = try await URLSession.shared.data(from: url)
```

---
**[HIGH]** — Polling database errors are logged and ignored
**File:** `Screens/MainUploadScreen/UploadPageNextViewController.swift` line 310
**Rule violated:** "catch blocks that only print or log without any recovery or user feedback — flag as incomplete error handling"
**Code:**
```swift
} catch {
    print("[Poll] ⚠️ DB error: \(error.localizedDescription)")
}
```
**What is wrong:** Polling silently keeps going after backend failures, so the user sees an endless spinner instead of a terminal error state.
**Exact fix:**
```swift
} catch {
    pollingTimer?.invalidate()
    pollingTimer = nil
    await MainActor.run {
        self.statusLabel.text = "We couldn't refresh processing status."
        self.statusLabel.isHidden = false
        self.refreshButton.isHidden = false
        self.progressView.isHidden = true
    }
}
```

---
**[HIGH]** — Upload screen owns a concrete Supabase client singleton
**File:** `Screens/MainUploadScreen/UploadScreen.swift` line 44
**Rule violated:** "Any ViewController that owns a network client, database client, or service object directly (should be injected via ViewModel)" and "Singletons used for stateful services where dependency injection is feasible — flag every shared instance used inside a ViewController"
**Code:**
```swift
private var supabase: SupabaseClient { SupabaseManager.shared.client }
```
**What is wrong:** The screen is tightly coupled to a global backend client, which makes testing and environment isolation significantly harder.
**Exact fix:**
```swift
protocol UploadScreenViewModeling {
    func fetchRecentUploads() async throws -> [Scan]
}

final class UploadScreen: UIViewController {
    private let viewModel: UploadScreenViewModeling

    init(viewModel: UploadScreenViewModeling) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
}
```

---
**[HIGH]** — Notification observer is registered without matching cleanup
**File:** `Screens/MainUploadScreen/UploadScreen.swift` line 72
**Rule violated:** "Timer or NotificationCenter observers that are never invalidated or removed — flag each registration site and check for corresponding cleanup in deinit or viewWillDisappear"
**Code:**
```swift
NotificationCenter.default.addObserver(self, selector: #selector(handleProfileUpdate), name: TopNavBar.profileDidUpdateNotification, object: nil)
```
**What is wrong:** This observer survives until deallocation with no explicit removal. Recreated screens accumulate observers and duplicate callback delivery.
**Exact fix:**
```swift
deinit {
    NotificationCenter.default.removeObserver(
        self,
        name: TopNavBar.profileDidUpdateNotification,
        object: nil
    )
}
```

---
**[HIGH]** — Upload screen fetches profile data directly from Supabase
**File:** `Screens/MainUploadScreen/UploadScreen.swift` line 195
**Rule violated:** "Any UIViewController that contains direct API calls, URLSession usage, or Supabase queries — flag every call site, not just the class"
**Code:**
```swift
let profile: Profile = try await SupabaseManager.shared.client
    .from("profiles").select().eq("id", value: user.id).single().execute().value
```
**What is wrong:** Profile retrieval belongs in a profile service or view model, not in the screen responsible for layout and interaction.
**Exact fix:**
```swift
protocol ProfileProviding {
    func fetchCurrentProfile() async throws -> Profile
}

let profile = try await profileProvider.fetchCurrentProfile()
```

---
**[HIGH]** — Image download is performed directly inside the view controller
**File:** `Screens/MainUploadScreen/UploadScreen.swift` line 231
**Rule violated:** "Any UIViewController that contains direct API calls, URLSession usage, or Supabase queries — flag every call site, not just the class"
**Code:**
```swift
let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 30))
```
**What is wrong:** The screen is doing transport, decoding, fallback logic, and UI mutation instead of delegating image loading to a dedicated component.
**Exact fix:**
```swift
let image = try await avatarImageLoader.loadAvatar(from: url)
await MainActor.run {
    self.largeProfileButton.setImage(image, for: .normal)
}
```

---
**[HIGH]** — Auth helper hides failures behind an optional return
**File:** `Screens/MainUploadScreen/UploadScreen.swift` line 737
**Rule violated:** "Functions that return optional as a way to signal failure instead of throwing or returning Result<T, Error> — flag each one"
**Code:**
```swift
private func currentUserId() async -> String? {
    do    { return try await supabase.auth.session.user.id.uuidString }
    catch { print("[Auth] userId error: \(error)"); return nil }
}
```
**What is wrong:** Authentication failure becomes indistinguishable from “no value,” which forces every caller into ambiguous control flow.
**Exact fix:**
```swift
private func currentUserId() async throws -> String {
    try await supabase.auth.session.user.id.uuidString
}
```

---
**[HIGH]** — Upload screen embeds conversion API transport in the controller
**File:** `Screens/MainUploadScreen/UploadScreen.swift` line 826
**Rule violated:** "Any UIViewController that contains direct API calls, URLSession usage, or Supabase queries — flag every call site, not just the class"
**Code:**
```swift
private func callConversionAPI(imageData: Data, fileName: String,
                               fileType: String, token: String) async throws -> [String: Any] {
```
**What is wrong:** The controller is constructing multipart requests, handling HTTP responses, parsing JSON, and deciding domain defaults. That is service-layer work.
**Exact fix:**
```swift
protocol ConversionSubmitting {
    func submit(fileData: Data, fileName: String, fileType: String, token: String) async throws -> ConversionResponse
}

struct ConversionResponse: Decodable {
    let jobId: UUID
    let userId: UUID
    let outputURL: URL?
}
```

---
**[HIGH]** — Discovery screen owns the backend client directly
**File:** `Screens/MainDiscoverScreen/DiscoverSongPreviewViewController.swift` line 25
**Rule violated:** "Any ViewController that owns a network client, database client, or service object directly (should be injected via ViewModel)" and "Singletons used for stateful services where dependency injection is feasible — flag every shared instance used inside a ViewController"
**Code:**
```swift
private var supabase: SupabaseClient { SupabaseManager.shared.client }
```
**What is wrong:** This bakes backend coupling straight into a preview screen and prevents the feature from being tested without the global singleton.
**Exact fix:**
```swift
final class DiscoverSongPreviewViewController: UIViewController {
    private let viewModel: DiscoverSongPreviewViewModel

    init(viewModel: DiscoverSongPreviewViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
}
```

---
**[HIGH]** — Preview screen performs PDF network fetch itself
**File:** `Screens/MainDiscoverScreen/DiscoverSongPreviewViewController.swift` line 288
**Rule violated:** "Any UIViewController that contains direct API calls, URLSession usage, or Supabase queries — flag every call site, not just the class"
**Code:**
```swift
if let (data, resp) = try? await URLSession.shared.data(from: url),
```
**What is wrong:** The preview controller is handling remote document retrieval and PDF validation directly. That is data-layer behavior, not view-layer behavior.
**Exact fix:**
```swift
let document = try await previewDocumentService.loadSheetPreview(for: song)
await MainActor.run {
    self.renderPDF(document)
}
```

---
**[HIGH]** — Preview screen is performing scan upsert logic in the UI layer
**File:** `Screens/MainDiscoverScreen/DiscoverSongPreviewViewController.swift` line 415
**Rule violated:** "Any UIViewController that contains data transformation, JSON parsing, or business logic of any kind"
**Code:**
```swift
let existingScans: [ScanRecord] = try await supabase.from("scans").select()
    .eq("user_id", value: userId)
    .like("json_data->>'job_id'", pattern: "%\(jobIdStr)%")
    .execute().value
```
**What is wrong:** The screen is deciding persistence semantics, deduplication rules, and update-vs-insert behavior. That belongs in a repository/service.
**Exact fix:**
```swift
try await scanRepository.upsertConvertedScan(
    userID: userId,
    jobID: jobId,
    payload: ConvertedScanPayload(
        title: song?.title ?? fileName,
        originalFilename: fileName,
        outputURL: outputURL,
        fileSizeBytes: pdfData.count
    )
)
```

---
**[HIGH]** — Auth helper returns optional and logs instead of throwing
**File:** `Screens/MainDiscoverScreen/DiscoverSongPreviewViewController.swift` line 486
**Rule violated:** "Functions that return optional as a way to signal failure instead of throwing or returning Result<T, Error> — flag each one"
**Code:**
```swift
private func currentUserId() async -> String? {
    do    { return try await supabase.auth.session.user.id.uuidString }
    catch { print("[Auth] \(error)"); return nil }
}
```
**What is wrong:** Authentication state failures are collapsed into `nil`, so callers cannot distinguish “logged out” from “SDK threw an error.”
**Exact fix:**
```swift
private func currentUserId() async throws -> String {
    try await supabase.auth.session.user.id.uuidString
}
```

---
**[HIGH]** — Shared navigation helper is querying Supabase from UIKit utility code
**File:** `Common/UIComponents/TopNavbar/NavigationBarHelper.swift` line 204
**Rule violated:** "Any networking code not behind a protocol — untestable and unswappable"
**Code:**
```swift
let profile: NavbarProfile = try await SupabaseManager.shared.client
    .from("profiles")
    .select()
    .eq("id", value: user.id.uuidString)
    .single()
    .execute()
    .value
```
**What is wrong:** A UI helper has become a hidden backend dependency. This couples every navigation bar render to Supabase and makes top-bar rendering impossible to unit test.
**Exact fix:**
```swift
protocol NavbarProfileProviding {
    func fetchNavbarProfile(userID: String) async throws -> NavbarProfile
}

public static func fetchWelcomeName(
    provider: NavbarProfileProviding,
    userID: String,
    completion: @escaping (String) -> Void
) { ... }
```

---
**[HIGH]** — Empty catch block suppresses image loading failures
**File:** `Common/UIComponents/TopNavbar/NavigationBarHelper.swift` line 274
**Rule violated:** "Empty catch blocks — every single one is a silent failure and a debugging nightmare. Flag each with what error is being swallowed"
**Code:**
```swift
        } catch {}
```
**What is wrong:** Network and decoding failures during avatar loading disappear completely, making broken profile images impossible to diagnose and impossible to surface to the UI.
**Exact fix:**
```swift
        } catch {
            await MainActor.run {
                imageView.image = UIImage(systemName: "person.crop.circle")
                imageView.tintColor = .gray
            }
        }
```

---
**[HIGH]** — Auth screen reads and writes persistence flags directly via `UserDefaults`
**File:** `Screens/MainLoginSignupScreen/AuthViewController.swift` line 112
**Rule violated:** "Direct access to UserDefaults, Keychain, or FileManager scattered across ViewControllers instead of going through a dedicated storage service"
**Code:**
```swift
if !UserDefaults.standard.bool(forKey: "hasSeenAppIntroCard") {
```
**What is wrong:** Auth UI now owns onboarding persistence rules and storage keys directly. That creates duplicated state conventions and makes migration or testing painful.
**Exact fix:**
```swift
protocol IntroCardStateStoring {
    func hasSeenIntroCard() -> Bool
    func markIntroCardSeen()
}

if !introCardStore.hasSeenIntroCard() {
    showRehearsalInfoCard()
}
```

---
**[CRITICAL]** — Force unwrap on onboarding genres can crash authenticated users
**File:** `Screens/MainLoginSignupScreen/AuthViewController.swift` line 787
**Rule violated:** "Every single force unwrap (!) in the codebase — no exceptions. Flag each one individually with the crash scenario"
**Code:**
```swift
shouldOnboard = row.genres == nil || row.genres!.isEmpty
```
**What is wrong:** A partial onboarding record with `genres = nil` or a decoding edge case will crash the login flow during Google auth.
**Exact fix:**
```swift
let genres = row.genres ?? []
shouldOnboard = genres.isEmpty
```

---
**[CRITICAL]** — Force unwrap of `UIWindowScene` can crash presentation-anchor resolution
**File:** `Screens/MainLoginSignupScreen/AuthViewController.swift` line 828
**Rule violated:** "Every single force unwrap (!) in the codebase — no exceptions. Flag each one individually with the crash scenario"
**Code:**
```swift
return UIWindow(windowScene: scene!)
```
**What is wrong:** If there is no connected foreground `UIWindowScene`, the auth flow crashes while asking for a presentation anchor.
**Exact fix:**
```swift
guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
    return ASPresentationAnchor()
}
return UIWindow(windowScene: scene)
```

---
**[HIGH]** — Auth flow logs signup result from the controller
**File:** `Screens/MainLoginSignupScreen/AuthViewController.swift` line 870
**Rule violated:** "catch blocks that only print or log without any recovery or user feedback — flag as incomplete error handling"
**Code:**
```swift
print("SIGNUP RESULT:", result)
```
**What is wrong:** Auth state is being dumped from the UI layer for debugging instead of being transformed into a typed outcome. This is operational noise in a critical user journey.
**Exact fix:**
```swift
let signUpResult = try await authService.signUp(
    email: email,
    password: password,
    fullName: fullName,
    username: username
)
handle(signUpResult)
```

---
**[HIGH]** — Profile screen is executing Supabase profile queries directly
**File:** `Screens/ProfileScreen/UserProfileViewController.swift` line 456
**Rule violated:** "Any UIViewController that contains direct API calls, URLSession usage, or Supabase queries — flag every call site, not just the class"
**Code:**
```swift
let profile: Profile = try await SupabaseManager.shared.client
    .from("profiles")
    .select()
    .eq("id", value: user.id.uuidString)
    .single()
    .execute()
    .value
```
**What is wrong:** Profile fetching is embedded in the screen, so the controller now owns backend schema knowledge and request orchestration.
**Exact fix:**
```swift
let profile = try await profileRepository.fetchProfile(for: user.id)
await MainActor.run {
    self.render(profile: profile)
}
```

---
**[HIGH]** — Profile screen stores login state in `UserDefaults` directly
**File:** `Screens/ProfileScreen/UserProfileViewController.swift` line 601
**Rule violated:** "Direct access to UserDefaults, Keychain, or FileManager scattered across ViewControllers instead of going through a dedicated storage service"
**Code:**
```swift
UserDefaults.standard.set(false, forKey: "isLoggedIn")
```
**What is wrong:** Session persistence rules are implemented directly in the profile UI, which fragments auth state management across screens.
**Exact fix:**
```swift
await sessionStore.setLoggedIn(false)
router.showSplashAndRoute()
```

---
**[HIGH]** — Profile screen performs avatar upload and profile mutation from the controller
**File:** `Screens/ProfileScreen/UserProfileViewController.swift` line 789
**Rule violated:** "Any UIViewController that contains direct API calls, URLSession usage, or Supabase queries — flag every call site, not just the class"
**Code:**
```swift
try await client.storage.from("useprofile").upload(fileName, data: jpegData)
```
**What is wrong:** The controller is handling image encoding, storage upload, public URL construction, and profile mutation. That is a full service workflow living in UI code.
**Exact fix:**
```swift
let avatarURL = try await avatarService.updateAvatar(image, for: user.id)
await MainActor.run {
    self.updateAvatar(with: avatarURL.absoluteString)
}
```

---
**[CRITICAL]** — Playlist artwork loader force unwraps the documents directory
**File:** `Screens/MainPlaylistScreen/MainPlayListScreen.swift` line 382
**Rule violated:** "Every single force unwrap (!) in the codebase — no exceptions. Flag each one individually with the crash scenario"
**Code:**
```swift
let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                     .first!.appendingPathComponent(identifier)
```
**What is wrong:** If the documents directory lookup ever returns an empty array, the playlist screen crashes while building artwork paths.
**Exact fix:**
```swift
guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
    return nil
}
let url = documentsURL.appendingPathComponent(identifier)
```

---
**[HIGH]** — Playlist screen performs synchronous file I/O on the main thread
**File:** `Screens/MainPlaylistScreen/MainPlayListScreen.swift` line 383
**Rule violated:** "Any synchronous network call or file I/O on the main thread — flag every blocking call"
**Code:**
```swift
if let data = try? Data(contentsOf: url) { return UIImage(data: data) }
```
**What is wrong:** Cell image resolution can now block scrolling while disk reads happen synchronously on the UI thread.
**Exact fix:**
```swift
Task.detached(priority: .utility) {
    let data = try Data(contentsOf: url)
    let image = UIImage(data: data)
    await MainActor.run {
        completion(image)
    }
}
```

---
**[CRITICAL]** — Collection view cell dequeue uses a force cast
**File:** `Screens/MainPlaylistScreen/MainPlayListScreen.swift` line 402
**Rule violated:** "as! force casts — flag every one. State what happens when the cast fails"
**Code:**
```swift
) as! PlaylistCollectionViewCell
```
**What is wrong:** A reuse-registration mismatch crashes the entire playlist screen at runtime.
**Exact fix:**
```swift
guard let cell = collectionView.dequeueReusableCell(
    withReuseIdentifier: "PlaylistCell",
    for: indexPath
) as? PlaylistCollectionViewCell else {
    assertionFailure("PlaylistCollectionViewCell not registered")
    return UICollectionViewCell()
}
```

---
**[CRITICAL]** — Supplementary view dequeue uses a force cast
**File:** `Screens/MainPlaylistScreen/MainPlayListScreen.swift` line 476
**Rule violated:** "as! force casts — flag every one. State what happens when the cast fails"
**Code:**
```swift
) as! CreatePlaylistFooterView
```
**What is wrong:** Any registration or nib mismatch turns footer rendering into a crash.
**Exact fix:**
```swift
guard let footer = collectionView.dequeueReusableSupplementaryView(
    ofKind: kind,
    withReuseIdentifier: "CreateFooter",
    for: indexPath
) as? CreatePlaylistFooterView else {
    assertionFailure("CreatePlaylistFooterView not registered")
    return UICollectionReusableView()
}
```

---
**[HIGH]** — Discover screen duplicates profile-fetch networking in the controller
**File:** `Screens/MainDiscoverScreen/DiscoverViewController.swift` line 643
**Rule violated:** "Any UIViewController that contains direct API calls, URLSession usage, or Supabase queries — flag every call site, not just the class"
**Code:**
```swift
let profile: Profile = try await SupabaseManager.shared.client
    .from("profiles")
    .select()
    .eq("id", value: user.id)
    .single()
    .execute()
    .value
```
**What is wrong:** This screen repeats the same backend profile-loading logic already scattered across other controllers, increasing coupling and duplication.
**Exact fix:**
```swift
let profile = try await profileRepository.fetchProfile(for: user.id)
await MainActor.run {
    self.renderProfile(profile)
}
```

---
**[HIGH]** — Discover screen logs profile failures instead of handling them explicitly
**File:** `Screens/MainDiscoverScreen/DiscoverViewController.swift` line 659
**Rule violated:** "catch blocks that only print or log without any recovery or user feedback — flag as incomplete error handling"
**Code:**
```swift
} catch {
    print("Error fetching profile: \(error)")
    await MainActor.run {
        largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
        largeProfileButton.tintColor = .secondaryLabel
    }
}
```
**What is wrong:** The controller hides a backend failure behind a default avatar with no visible error state and no typed recovery path.
**Exact fix:**
```swift
} catch {
    await MainActor.run {
        self.largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
        self.largeProfileButton.tintColor = .secondaryLabel
        self.showError("Unable to load profile.")
    }
}
```

---
**[CRITICAL]** — Discover table view uses a force cast for cells
**File:** `Screens/MainDiscoverScreen/DiscoverViewController.swift` line 722
**Rule violated:** "as! force casts — flag every one. State what happens when the cast fails"
**Code:**
```swift
let cell = tableView.dequeueReusableCell(withIdentifier: SongCell.reuseID, for: indexPath) as! SongCell
```
**What is wrong:** If registration breaks, discover browsing crashes immediately on cell dequeue.
**Exact fix:**
```swift
guard let cell = tableView.dequeueReusableCell(
    withIdentifier: SongCell.reuseID,
    for: indexPath
) as? SongCell else {
    assertionFailure("SongCell not registered")
    return UITableViewCell()
}
```

---
**[HIGH]** — Lesson map controller fetches profile data directly from Supabase
**File:** `Screens/LearningCurve/LessonMapViewController.swift` line 192
**Rule violated:** "Any UIViewController that contains direct API calls, URLSession usage, or Supabase queries — flag every call site, not just the class"
**Code:**
```swift
let profile: Profile = try await SupabaseManager.shared.client
    .from("profiles").select().eq("id", value: user.id).single().execute().value
```
**What is wrong:** Another UIKit controller is performing repository work directly, repeating the same fragile profile-loading logic found elsewhere.
**Exact fix:**
```swift
let profile = try await profileRepository.fetchProfile(for: user.id)
await MainActor.run {
    self.renderProfile(profile)
}
```

---
**[HIGH]** — Lesson map controller downloads avatar images directly
**File:** `Screens/LearningCurve/LessonMapViewController.swift` line 228
**Rule violated:** "Any UIViewController that contains direct API calls, URLSession usage, or Supabase queries — flag every call site, not just the class"
**Code:**
```swift
let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 30))
```
**What is wrong:** This controller owns network transport and image decoding instead of delegating to a loader service.
**Exact fix:**
```swift
let image = try await avatarImageLoader.loadAvatar(from: url)
await MainActor.run {
    self.largeProfileButton.setImage(image, for: .normal)
}
```

---
**[HIGH]** — Lesson map controller performs progress aggregation in the view layer
**File:** `Screens/LearningCurve/LessonMapViewController.swift` line 282
**Rule violated:** "Any UIViewController that contains data transformation, JSON parsing, or business logic of any kind"
**Code:**
```swift
let db = SupabaseManager.shared.client
let userID = try await db.auth.session.user.id
let profileData: [[String: Any]] = try await db
    .from("profiles")
    .select("current_chapter")
    .eq("id", value: userID.uuidString)
    .limit(1)
    .execute()
    .value as? [[String: Any]] ?? []
```
**What is wrong:** The controller is fetching raw rows, downcasting `[String: Any]`, and computing progress state itself. That is domain logic, not presentation logic.
**Exact fix:**
```swift
struct LessonMapProgress {
    let currentChapter: Int
    let starsByChapter: [Int: Int]
}

let progress = try await lessonProgressRepository.fetchLessonMapProgress()
await MainActor.run {
    self.applyFetchedProgress(
        currentMapChapter: progress.currentChapter,
        starsMap: progress.starsByChapter
    )
}
```

---
**[HIGH]** — Lesson map controller logs Supabase failures and leaves stale UI state
**File:** `Screens/LearningCurve/LessonMapViewController.swift` line 313
**Rule violated:** "catch blocks that only print or log without any recovery or user feedback — flag as incomplete error handling"
**Code:**
```swift
} catch {
    print("[LessonMapViewController] Supabase fetch error: \(error)")
}
```
**What is wrong:** When progress loading fails, the user is shown stale or empty lesson state with no explanation and no retry affordance.
**Exact fix:**
```swift
} catch {
    await MainActor.run {
        self.present(
            UIAlertController(
                title: "Progress Unavailable",
                message: "We couldn't load your lesson progress. Please try again.",
                preferredStyle: .alert
            ),
            animated: true
        )
    }
}
```

---
**[MEDIUM]** — Audit stopped before full repo coverage; unreached files remain
**File:** `QUALITY_AUDIT.md` line 1
**Rule violated:** "If you run low on context, stop scanning and explicitly list every file that was NOT reached."
**Code:**
```text
Audit coverage stopped before all in-scope Swift/Python files were reviewed.
```
**What is wrong:** Full-coverage claims would be false. The following files were not reached during this audit pass:
**Exact fix:**
```text
Common/Audio/PitchDetector.swift
Common/Music_Components/AnimatedKeyboardView.swift
Common/Music_Components/PianoKeyView.swift
Common/Music_Components/WaveView.swift
Common/UIComponents/BottomNavbar/BottomNavbar.swift
Common/UIComponents/ImageLoader.swift
Common/UIComponents/LandscapeNavigationController.swift
Common/UIComponents/TopNavbar/NavigationBarHelper 2.swift
Common/UIComponents/TopNavbar/TopNavBar.swift
Features/ChordRecognition/ChordRecognition.swift
Models/PianoDataManager.swift
Re-Hearse_v1/AppDelegate.swift
Re-Hearse_v1/SceneDelegate.swift
Screens/LearningCurve/LessonDetailViewController.swift
Screens/LearningCurve/LessonModels.swift
Screens/LearningCurve/SupabaseProgressManager.swift
Screens/LearningCurve/TryYourselfViewController.swift
Screens/LearningCurve/Views/ChapterNodeView.swift
Screens/LearningCurve/Views/ChapterPopupCard.swift
Screens/LearningCurve/Views/LessonCompletionPopupView.swift
Screens/LearningCurve/Views/MusicStaffView.swift
Screens/LearningCurve/Views/PathCanvasView.swift
Screens/LearningCurve/Views/VariantChipButton.swift
Screens/MainAnimationScreen/AnimationOverlayView.swift
Screens/MainAnimationScreen/AnimationViewController.swift
Screens/MainAnimationScreen/AudioEngineManager.swift
Screens/MainAnimationScreen/MusicJSONLoader.swift
Screens/MainAnimationScreen/PianoAnimationkeyboardViewController.swift
Screens/MainAnimationScreen/PianoDemoManager.swift
Screens/MainAnimationScreen/PianoLogic.swift
Screens/MainAnimationScreen/PianoView.swift
Screens/MainAnimationScreen/PlayPauseOverlayView.swift
Screens/MainAnimationScreen/SheetMusicView.swift
Screens/MainAnimationScreen/SongChord.swift
Screens/MainAnimationScreen/TopView.swift
Screens/MainChordRecognitionScreen/ChordAudioManager.swift
Screens/MainChordRecognitionScreen/MainChordRecognitionScreen.swift
Screens/MainDiscoverScreen/DiscoverSongDetailViewController.swift
Screens/MainHomeScreen/AllRecentsViewController.swift
Screens/MainHomeScreen/DailyGoalManager.swift
Screens/MainHomeScreen/HomeScreenModels/PlayListModel.swift
Screens/MainHomeScreen/HomeScreenModels/RecentPlayModel.swift
Screens/MainHomeScreen/HomeViewController.swift
Screens/MainHomeScreen/HomeViewControllerButtons.swift
Screens/MainHomeScreen/HomeViewControllerContinueCard.swift
Screens/MainHomeScreen/HomeViewControllerContinueLearning.swift
Screens/MainHomeScreen/HomeViewControllerLayout.swift
Screens/MainHomeScreen/HomeViewControllerUploadSection.swift
Screens/MainPlayAlongScreen/PlayAlongViewController.swift
Screens/MainPlayAlongScreen/SongDetailsPage.swift
Screens/MainPlaylistScreen/Managers/PlaylistsManager.swift
Screens/MainPlaylistScreen/Models/PlaylistModels.swift
Screens/MainPlaylistScreen/PlayListInside.swift
Screens/MainPlaylistScreen/SongDetailsPage.swift
Screens/MainPlaylistScreen/UploadPickerViewController.swift
Screens/MainUploadScreen/AllUploadsViewController.swift
Screens/MainUploadScreen/MaximizeUploadPageViewController.swift
Screens/MainUploadScreen/UploadQuizPopup.swift
Screens/OnBoardingQuestionsScreen/OnboardingFlowRoot.swift
Screens/OnBoardingQuestionsScreen/OnboardingQuestion1View.swift
Screens/OnBoardingQuestionsScreen/OnboardingQuestion2View.swift
Screens/OnBoardingQuestionsScreen/OnboardingQuestion3View.swift
Screens/OnBoardingQuestionsScreen/OnboardingViewModel.swift
Screens/OnBoardingQuestionsScreen/ProgressIndicator.swift
Screens/Splash/RehearsalInfoCard.swift
Screens/Splash/SplashViewController.swift
SupabaseBackend/SupabaseManager.swift
backend/app/__init__.py
backend/app/audiveris_client.py
backend/app/config.py
backend/app/dispatcher.py
backend/app/label_notes.py
backend/app/limiter.py
backend/app/orphan_detector.py
backend/app/queue.py
backend/tests/__init__.py
backend/tests/conftest.py
backend/tests/test_helpers.py
backend/tests/test_recovery_simple.py
backend/worker.py
```

---
**[HIGH]** — Scene routing uses `UserDefaults` directly for auth state
**File:** `Re-Hearse_v1/SceneDelegate.swift` line 35
**Rule violated:** "Every direct UserDefaults/Keychain/FileManager access in a ViewController instead of a storage service"
**Code:**
```swift
let isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
```
**What is wrong:** Root navigation depends on an ad-hoc persisted flag instead of a dedicated session store. That splits auth truth across storage and Supabase session state and makes startup routing brittle.
**Exact fix:**
```swift
protocol SessionStateStoring {
    func isLoggedIn() -> Bool
    func setLoggedIn(_ value: Bool)
}

let isLoggedIn = sessionStore.isLoggedIn()
```

---
**[HIGH]** — SceneDelegate performs Supabase auth/session queries directly
**File:** `Re-Hearse_v1/SceneDelegate.swift` line 41
**Rule violated:** "Every ViewController with direct Supabase queries — flag every call site"
**Code:**
```swift
let client = SupabaseManager.shared.client
let session = try await client.auth.session
```
**What is wrong:** App bootstrap is coupled directly to the backend SDK and onboarding schema instead of going through a routing/auth coordinator abstraction.
**Exact fix:**
```swift
protocol LaunchRouting {
    func initialDestination() async throws -> LaunchDestination
}

let destination = try await launchRouter.initialDestination()
```

---
**[HIGH]** — Startup flow swallows onboarding lookup failure with `try?`
**File:** `Re-Hearse_v1/SceneDelegate.swift` line 50
**Rule violated:** "Every network failure with no user-visible error state"
**Code:**
```swift
let row: OnboardingRow? = try? await client
    .from("user_onboarding")
    .select("genres")
    .eq("id", value: userId)
    .single()
    .execute()
    .value
```
**What is wrong:** Any networking or decoding failure is silently collapsed into `nil`, which changes startup routing without exposing the failure or retrying.
**Exact fix:**
```swift
do {
    let row: OnboardingRow = try await onboardingRepository.fetchRow(for: userId)
    route(using: row)
} catch {
    await MainActor.run {
        self.showLoginScreen()
        self.presentStartupError(error)
    }
}
```

---
**[HIGH]** — Shared navbar view performs Supabase profile queries directly
**File:** `Common/UIComponents/TopNavbar/TopNavBar.swift` line 246
**Rule violated:** "Every ViewController with direct Supabase queries — flag every call site"
**Code:**
```swift
let profile: NavbarProfile = try await SupabaseManager.shared.client
    .from("profiles")
    .select()
    .eq("id", value: user.id.uuidString)
    .single()
    .execute()
    .value
```
**What is wrong:** A reusable UI component is bound directly to backend schema and network behavior instead of receiving already-prepared view state.
**Exact fix:**
```swift
struct TopNavBarViewState {
    let welcomeText: String
    let avatarURL: URL?
}

func apply(_ state: TopNavBarViewState) {
    welcomeLabel.text = state.welcomeText
}
```

---
**[HIGH]** — Shared navbar view performs raw image networking itself
**File:** `Common/UIComponents/TopNavbar/TopNavBar.swift` line 319
**Rule violated:** "Every ViewController with URLSession calls — flag every call site"
**Code:**
```swift
let (data, _) = try await URLSession.shared.data(for: request)
```
**What is wrong:** The component now owns transport, decoding, timeout policy, and fallback rendering. That belongs in an image-loading dependency, not in the view.
**Exact fix:**
```swift
let image = try await avatarImageLoader.loadAvatar(from: url)
await MainActor.run {
    self.profileImg.image = image
}
```

---
**[HIGH]** — `TopNavBar` exceeds the maximum ViewController-size threshold for a UI controller analogue
**File:** `Common/UIComponents/TopNavbar/TopNavBar.swift` line 1
**Rule violated:** "Every ViewController file over 300 lines — state exact line count"
**Code:**
```swift
public final class TopNavBar: UIView {
```
**What is wrong:** This file is 342 lines and mixes layout, gesture wiring, notification observation, profile loading, networking, and fallback rendering in one type. The same maintainability failure the rule is trying to prevent is present here.
**Exact fix:**
```swift
split TopNavBar.swift into:
- TopNavBarView.swift
- TopNavBarViewModel.swift
- TopNavBarImageLoader.swift
```

---
**[HIGH]** — `ImageLoader` mutates shared task state across threads without synchronization
**File:** `Common/UIComponents/ImageLoader.swift` line 6
**Rule violated:** "Any property read/written from multiple threads without an actor or lock"
**Code:**
```swift
private var loadingTasks: [String: URLSessionDataTask] = [:]
```
**What is wrong:** `loadingTasks` is written on the caller thread and from URLSession completion callbacks with no actor, lock, or serial queue. That is a race condition waiting to happen under concurrent image loads.
**Exact fix:**
```swift
actor ImageTaskStore {
    private var tasks: [String: URLSessionDataTask] = [:]

    func set(_ task: URLSessionDataTask, for key: String) { tasks[key] = task }
    func remove(for key: String) { tasks.removeValue(forKey: key) }
}
```

---
**[HIGH]** — URLSession completion path can call completion off the main thread
**File:** `Common/UIComponents/ImageLoader.swift` line 35
**Rule violated:** "Every URLSession completion that updates UI directly"
**Code:**
```swift
guard let data = data,
      let image = UIImage(data: data),
      error == nil else {
    completion(nil)
    return
}
```
**What is wrong:** On failure, `completion(nil)` is invoked directly from the URLSession callback queue. Any caller that updates UIKit in that closure is now doing it off-main.
**Exact fix:**
```swift
guard let data = data,
      let image = UIImage(data: data),
      error == nil else {
    DispatchQueue.main.async {
        completion(nil)
    }
    return
}
```

---
**[MEDIUM]** — Image loader does not validate HTTP response status before decoding
**File:** `Common/UIComponents/ImageLoader.swift` line 26
**Rule violated:** "Every networking call not behind a protocol"
**Code:**
```swift
let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
```
**What is wrong:** The loader treats any payload as an image without checking status code or MIME type, which turns server errors into silent decode failures and hides transport problems.
**Exact fix:**
```swift
guard
    let http = response as? HTTPURLResponse,
    (200...299).contains(http.statusCode),
    let mime = http.value(forHTTPHeaderField: "Content-Type"),
    mime.hasPrefix("image/")
else {
    DispatchQueue.main.async { completion(nil) }
    return
}
```

---
**[MEDIUM]** — Worker acquires a Redis lock with an untyped return value
**File:** `backend/worker.py` line 115
**Rule violated:** "Every function missing type hints on any parameter or return value"
**Code:**
```python
def acquire_vm_lock(timeout: int = VM_LOCK_TIMEOUT):
```
**What is wrong:** The lock type is part of the contract here. Leaving it untyped weakens static checks in a concurrency-sensitive path.
**Exact fix:**
```python
from redis.lock import Lock

def acquire_vm_lock(timeout: int = VM_LOCK_TIMEOUT) -> Lock:
```

---
**[MEDIUM]** — Worker releases Redis lock through an untyped parameter
**File:** `backend/worker.py` line 123
**Rule violated:** "Every function missing type hints on any parameter or return value"
**Code:**
```python
def release_vm_lock(lock) -> None:
```
**What is wrong:** An untyped lock parameter in shutdown code invites misuse and hides the real API surface.
**Exact fix:**
```python
from redis.lock import Lock

def release_vm_lock(lock: Lock | None) -> None:
```

---
**[MEDIUM]** — Worker port-claim helper returns an untyped tuple
**File:** `backend/worker.py` line 217
**Rule violated:** "Every function missing type hints on any parameter or return value"
**Code:**
```python
def claim_audiveris_port():
```
**What is wrong:** This function returns both a URL and a lock object, but the contract is implicit and fragile.
**Exact fix:**
```python
from redis.lock import Lock

def claim_audiveris_port() -> tuple[str, Lock]:
```

---
**[HIGH]** — Worker function overrides method without typing its parameters
**File:** `backend/worker.py` line 266
**Rule violated:** "Every function missing type hints on any parameter or return value"
**Code:**
```python
def perform_job(self, job, queue):  # type: ignore[override]
```
**What is wrong:** The core worker override disables type checking right where job execution and queue semantics matter most.
**Exact fix:**
```python
from rq.job import Job
from rq.queue import Queue

def perform_job(self, job: Job, queue: Queue) -> bool:
```

---
**[HIGH]** — Dispatcher normalizer uses raw `dict` instead of a typed structure
**File:** `backend/app/dispatcher.py` line 100
**Rule violated:** "Every Dict/List without generics where TypedDict or dataclass fits"
**Code:**
```python
def normalize_json_for_pdf(json_data: dict, pdf_path: str) -> dict:
```
**What is wrong:** This function rewrites a nested document schema, but the interface exposes an untyped `dict`, making it impossible to validate statically.
**Exact fix:**
```python
class ScoreJSON(TypedDict):
    score_partwise: dict[str, object]

def normalize_json_for_pdf(json_data: ScoreJSON, pdf_path: str) -> ScoreJSON:
```

---
**[HIGH]** — Dispatcher entry point accepts untyped job payload
**File:** `backend/app/dispatcher.py` line 252
**Rule violated:** "Every Dict/List without generics where TypedDict or dataclass fits"
**Code:**
```python
def process_job(job_data: dict) -> None:
```
**What is wrong:** The worker contract is a fixed payload shape, but the code advertises an unbounded dict.
**Exact fix:**
```python
class JobPayload(TypedDict):
    job_id: str

def process_job(job_data: JobPayload) -> None:
```

---
**[HIGH]** — Dispatcher async pipeline exceeds the function-size limit
**File:** `backend/app/dispatcher.py` line 265
**Rule violated:** "Every function over 40 lines"
**Code:**
```python
async def async_process_job(job_data: dict) -> None:
```
**What is wrong:** This function spans the full job lifecycle, error recovery, storage I/O, labeling, and cleanup in one monolith. It is far beyond the rule limit and too risky to change safely.
**Exact fix:**
```python
async def async_process_job(job_data: JobPayload) -> None:
    job = await fetch_job(job_data)
    pdf_path = await download_input_pdf(job)
    json_output = await transcribe_pdf(pdf_path)
    result = await label_and_store(job, pdf_path, json_output)
    await finalize_job(job, result)
```

---
**[MEDIUM]** — Config exposes CORS origins as an unparameterized list
**File:** `backend/app/config.py` line 55
**Rule violated:** "Every Dict/List without generics where TypedDict or dataclass fits"
**Code:**
```python
ALLOWED_ORIGINS: list = [o.strip() for o in _raw_origins.split(",") if o.strip()]
```
**What is wrong:** This loses element typing for a security-sensitive setting and weakens validation.
**Exact fix:**
```python
ALLOWED_ORIGINS: list[str] = [o.strip() for o in _raw_origins.split(",") if o.strip()]
```

---
**[MEDIUM]** — Config hardcodes development origins as magic strings
**File:** `backend/app/config.py` line 53
**Rule violated:** "Every magic number or magic string that should be a constant"
**Code:**
```python
"http://localhost:3000,http://localhost:8081,http://localhost:8000",
```
**What is wrong:** Environment-specific trust policy is embedded inline instead of being defined in a named default constant or deployment config.
**Exact fix:**
```python
DEFAULT_ALLOWED_ORIGINS = (
    "http://localhost:3000,"
    "http://localhost:8081,"
    "http://localhost:8000"
)
_raw_origins = os.getenv("ALLOWED_ORIGINS", DEFAULT_ALLOWED_ORIGINS)
```

---
**[CRITICAL]** — Force unwrap in track placeholder can crash when fallback symbol is unavailable
**File:** `Screens/MainPlaylistScreen/PlayListInside.swift` line 15
**Rule violated:** "Every force unwrap (!) — state the exact crash scenario for each"
**Code:**
```swift
return UIImage(named: "trackimage_\(index)") ?? UIImage(systemName: "music.note")!
```
**What is wrong:** If the SF Symbol lookup fails on an older OS or symbol configuration mismatch, opening a playlist row crashes immediately.
**Exact fix:**
```swift
return UIImage(named: "trackimage_\(index)")
    ?? UIImage(systemName: "music.note")
    ?? UIImage()
```

---
**[HIGH]** — Playlist detail controller depends on a global service singleton directly
**File:** `Screens/MainPlaylistScreen/PlayListInside.swift` line 266
**Rule violated:** "Every ViewController that owns a network/DB client directly"
**Code:**
```swift
try await PlaylistsManager.shared.updatePlaylistName(id: id, newName: newName)
```
**What is wrong:** The screen is coupled to a concrete shared manager instead of receiving a playlist service abstraction or view model.
**Exact fix:**
```swift
protocol PlaylistDetailViewing {
    func renamePlaylist(id: UUID, to newName: String) async throws
}

try await viewModel.renamePlaylist(id: id, to: newName)
```

---
**[HIGH]** — Playlist detail controller logs rename failure without user-visible recovery
**File:** `Screens/MainPlaylistScreen/PlayListInside.swift` line 272
**Rule violated:** "Every catch that only prints without recovery or user feedback"
**Code:**
```swift
} catch {
    print("❌ Rename error: \(error)")
}
```
**What is wrong:** Rename failure vanishes into the console and leaves the UI in an indeterminate state.
**Exact fix:**
```swift
} catch {
    await MainActor.run {
        let alert = UIAlertController(title: "Rename Failed", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }
}
```

---
**[HIGH]** — Playlist detail controller fetches data through a service singleton from the UI layer
**File:** `Screens/MainPlaylistScreen/PlayListInside.swift` line 303
**Rule violated:** "Every ViewController with data transformation or business logic"
**Code:**
```swift
let tracks = try await PlaylistsManager.shared.fetchPlaylistTracks(playlistId: playlistId)
```
**What is wrong:** The controller is coordinating data fetch, loading state, and mapping lifecycle directly instead of consuming observable state from a view model.
**Exact fix:**
```swift
await viewModel.loadTracks(for: playlistId)
bind(viewModel.$tracks) { [weak self] tracks in
    self?.render(tracks)
}
```

---
**[HIGH]** — Playlist detail controller logs fetch errors and renders empty state
**File:** `Screens/MainPlaylistScreen/PlayListInside.swift` line 309
**Rule violated:** "Every network failure with no user-visible error state"
**Code:**
```swift
} catch {
    print("❌ Error fetching tracks: \(error)")
    DispatchQueue.main.async { [weak self] in
        self?.activityIndicator.stopAnimating()
        self?.reloadTracksUI()
    }
}
```
**What is wrong:** Backend failure is indistinguishable from an empty playlist, which is a broken UI state.
**Exact fix:**
```swift
} catch {
    await MainActor.run {
        self.activityIndicator.stopAnimating()
        let alert = UIAlertController(title: "Tracks Unavailable", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }
}
```

---
**[CRITICAL]** — Table view cell dequeue uses a force cast
**File:** `Screens/MainPlaylistScreen/PlayListInside.swift` line 400
**Rule violated:** "Every as! force cast — state what happens at runtime when the cast fails"
**Code:**
```swift
let cell = tableView.dequeueReusableCell(withIdentifier: "TrackCell", for: indexPath) as! TrackTableViewCell
```
**What is wrong:** Any registration mismatch or reuse issue crashes the playlist detail screen when a row is rendered.
**Exact fix:**
```swift
guard let cell = tableView.dequeueReusableCell(withIdentifier: "TrackCell", for: indexPath) as? TrackTableViewCell else {
    assertionFailure("TrackTableViewCell not registered")
    return UITableViewCell()
}
```

---
**[CRITICAL]** — Custom cell initializer uses `fatalError`
**File:** `Screens/MainPlaylistScreen/PlayListInside.swift` line 481
**Rule violated:** "Every force unwrap (!) — state the exact crash scenario for each"
**Code:**
```swift
fatalError("init(coder:) has not been implemented")
```
**What is wrong:** Any storyboard/nib instantiation path turns into an immediate crash.
**Exact fix:**
```swift
required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupUI()
}
```

---
**[HIGH]** — Discover detail screen exceeds the file-size threshold
**File:** `Screens/MainDiscoverScreen/DiscoverSongDetailViewController.swift` line 1
**Rule violated:** "Every ViewController file over 300 lines — state exact line count"
**Code:**
```swift
class DiscoverSongDetailViewController: UIViewController {
```
**What is wrong:** This file is 472 lines and combines layout, playback navigation, PDF transport, JSON parsing, and button state management in one controller.
**Exact fix:**
```swift
split DiscoverSongDetailViewController.swift into:
- DiscoverSongDetailViewController.swift
- DiscoverSongDetailViewModel.swift
- DiscoverSongDocumentService.swift
```

---
**[CRITICAL]** — View controller initializer crashes on coder-based creation
**File:** `Screens/MainDiscoverScreen/DiscoverSongDetailViewController.swift` line 60
**Rule violated:** "Every force unwrap (!) — state the exact crash scenario for each"
**Code:**
```swift
required init?(coder: NSCoder) { fatalError() }
```
**What is wrong:** Any accidental storyboard/nib instantiation path terminates the app.
**Exact fix:**
```swift
required init?(coder: NSCoder) {
    super.init(coder: coder)
    self.hidesBottomBarWhenPushed = true
}
```

---
**[HIGH]** — Discover detail controller logs recent-play failure only
**File:** `Screens/MainDiscoverScreen/DiscoverSongDetailViewController.swift` line 81
**Rule violated:** "Every catch that only prints without recovery or user feedback"
**Code:**
```swift
} catch {
    print("[DiscoverDetail] ❌ Failed to record play: \(error)")
}
```
**What is wrong:** Failure in a user-facing feature is silently discarded. The UI does not reflect the write failure and there is no retry path.
**Exact fix:**
```swift
} catch {
    await MainActor.run {
        self.showAnimationError("Failed to save recent play. Please try again.")
    }
}
```

---
**[HIGH]** — Discover detail controller performs JSON serialization in the view layer
**File:** `Screens/MainDiscoverScreen/DiscoverSongDetailViewController.swift` line 364
**Rule violated:** "Every ViewController with data transformation or business logic"
**Code:**
```swift
guard let data = try? JSONSerialization.data(withJSONObject: json) else {
```
**What is wrong:** The controller is transforming domain data into transport format itself instead of receiving ready-to-consume `Data` from a view model or serializer.
**Exact fix:**
```swift
guard let data = viewModel.animationPayload else {
    showAnimationError("Failed to prepare sheet music data.")
    return
}
```

---
**[HIGH]** — Discover detail controller performs remote PDF fetches directly
**File:** `Screens/MainDiscoverScreen/DiscoverSongDetailViewController.swift` line 415
**Rule violated:** "Every ViewController with URLSession calls — flag every call site"
**Code:**
```swift
if let (data, resp) = try? await URLSession.shared.data(from: url),
```
**What is wrong:** The view controller is implementing remote document lookup, transport fallback order, and PDF validation by itself.
**Exact fix:**
```swift
let document = try await detailDocumentService.fetchPDF(for: sheetId)
await MainActor.run {
    self.renderPDF(document)
}
```

---
**[HIGH]** — Discover detail controller performs remote JSON fetches directly
**File:** `Screens/MainDiscoverScreen/DiscoverSongDetailViewController.swift` line 439
**Rule violated:** "Every ViewController with URLSession calls — flag every call site"
**Code:**
```swift
if let (data, resp) = try? await URLSession.shared.data(from: url),
   (200...299).contains((resp as? HTTPURLResponse)?.statusCode ?? 0),
   let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
```
**What is wrong:** JSON transport, validation, and parsing are happening entirely in the controller.
**Exact fix:**
```swift
let json = try await detailDocumentService.fetchOutputJSON(for: sheetId)
await MainActor.run {
    self.sheetMusicJSON = json
}
```

---
**[HIGH]** — All uploads controller owns a concrete Supabase client
**File:** `Screens/MainUploadScreen/AllUploadsViewController.swift` line 20
**Rule violated:** "Every ViewController that owns a network/DB client directly"
**Code:**
```swift
private var supabase: SupabaseClient { SupabaseManager.shared.client }
```
**What is wrong:** This screen is directly coupled to the backend client singleton instead of depending on a view model or upload repository.
**Exact fix:**
```swift
protocol UploadsViewing {
    func fetchUploads() async throws -> [UploadRow]
}

private let viewModel: UploadsViewing
```

---
**[HIGH]** — All uploads controller hides fetch failures behind an empty-state render
**File:** `Screens/MainUploadScreen/AllUploadsViewController.swift` line 98
**Rule violated:** "Every network failure with no user-visible error state"
**Code:**
```swift
} catch {
    print("[AllUploads] fetch error: \(error)")
    await MainActor.run {
        self.loadingIndicator.stopAnimating()
        self.renderRows([])
    }
}
```
**What is wrong:** Network failure is rendered exactly like “no uploads”, which is a broken state and misleads the user.
**Exact fix:**
```swift
} catch {
    await MainActor.run {
        self.loadingIndicator.stopAnimating()
        let alert = UIAlertController(title: "Uploads Unavailable", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }
}
```

---
**[HIGH]** — All uploads auth helper collapses session failure into `[]`
**File:** `Screens/MainUploadScreen/AllUploadsViewController.swift` line 109
**Rule violated:** "Every function returning optional to signal failure instead of throwing"
**Code:**
```swift
guard let uidStr = try? await supabase.auth.session.user.id.uuidString,
      let userId = UUID(uuidString: uidStr) else { return [] }
```
**What is wrong:** Session failure is treated as “no uploads”, which conflates authentication breakage with a valid empty result.
**Exact fix:**
```swift
let uidStr = try await supabase.auth.session.user.id.uuidString
guard let userId = UUID(uuidString: uidStr) else {
    throw UploadsError.invalidUserID(uidStr)
}
```

---
**[HIGH]** — All uploads controller performs title/date/size derivation in the view layer
**File:** `Screens/MainUploadScreen/AllUploadsViewController.swift` line 128
**Rule violated:** "Every ViewController with data transformation or business logic"
**Code:**
```swift
let jsonDict = scan.jsonData?.value as? [String: Any]
```
**What is wrong:** The controller is decoding arbitrary JSON and deriving presentation state directly from backend payloads instead of consuming typed display models.
**Exact fix:**
```swift
struct UploadRowViewState {
    let title: String
    let fileType: String
    let metadata: String
}

let rowState = viewModel.makeRowState(for: scan)
```

---
**[HIGH]** — All uploads controller logs rename failure without recovery
**File:** `Screens/MainUploadScreen/AllUploadsViewController.swift` line 301
**Rule violated:** "Every catch that only prints without recovery or user feedback"
**Code:**
```swift
} catch {
    print("[AllUploads] rename failed: \(error)")
    await MainActor.run { self.loadUploads() }
}
```
**What is wrong:** The user gets no explicit error even though the rename failed, and the screen silently reloads.
**Exact fix:**
```swift
} catch {
    await MainActor.run {
        let alert = UIAlertController(title: "Rename Failed", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }
}
```

---
**[HIGH]** — `AllUploadsViewController` exceeds the file-size threshold
**File:** `Screens/MainUploadScreen/AllUploadsViewController.swift` line 1
**Rule violated:** "Every ViewController file over 300 lines — state exact line count"
**Code:**
```swift
class AllUploadsViewController: UIViewController {
```
**What is wrong:** This controller is 394 lines and mixes transport, model decoding, formatting, rename flow, and row construction in one file.
**Exact fix:**
```swift
split AllUploadsViewController.swift into:
- AllUploadsViewController.swift
- AllUploadsViewModel.swift
- UploadRowView.swift
```

---
**[HIGH]** — Playlist manager imports `UIKit` and performs image/file work inside the service layer
**File:** `Screens/MainPlaylistScreen/Managers/PlaylistsManager.swift` line 2
**Rule violated:** "Every service doing more than one domain's work"
**Code:**
```swift
import UIKit
```
**What is wrong:** This service is not just managing playlist persistence. It also handles image compression, storage upload retries, document-directory fallback, and UI-facing asset defaults.
**Exact fix:**
```swift
split responsibilities into:
- PlaylistRepository.swift
- PlaylistCoverImageService.swift
- PlaylistService.swift
```

---
**[HIGH]** — Playlist fetch performs repeated per-playlist queries
**File:** `Screens/MainPlaylistScreen/Managers/PlaylistsManager.swift` line 30
**Rule violated:** "Every duplicated API call across multiple files"
**Code:**
```swift
let dbItems: [DBPlaylistItem] = try await SupabaseManager.shared.client
    .from("playlist_items")
    .select()
    .eq("playlist_id", value: dbPlaylist.id.uuidString)
    .order("position")
    .execute()
    .value
```
**What is wrong:** This loops over playlists and performs one backend round-trip per playlist, which will degrade badly as the user accumulates playlists.
**Exact fix:**
```swift
let allItems: [DBPlaylistItem] = try await client
    .from("playlist_items")
    .select()
    .in("playlist_id", values: dbPlaylists.map(\.id.uuidString))
    .order("position")
    .execute()
    .value
```

---
**[HIGH]** — Playlist manager logs delete failure without surfacing it to callers
**File:** `Screens/MainPlaylistScreen/Managers/PlaylistsManager.swift` line 406
**Rule violated:** "Every catch that only prints without recovery or user feedback"
**Code:**
```swift
} catch {
    print("❌ Delete error: \(error)")
}
```
**What is wrong:** The service hides failure and returns control as if deletion completed, forcing the UI into inconsistent state.
**Exact fix:**
```swift
public func deletePlaylist(id: UUID) async throws {
    try await client.from("playlist_items").delete().eq("playlist_id", value: id.uuidString).execute()
    try await client.from("playlists").delete().eq("id", value: id.uuidString).execute()
}
```

---
**[CRITICAL]** — Playlist creation force unwraps random asset selection
**File:** `Screens/MainPlaylistScreen/Managers/PlaylistsManager.swift` line 425
**Rule violated:** "Every force unwrap (!) — state the exact crash scenario for each"
**Code:**
```swift
let randomName = defaultNames.randomElement()!
```
**What is wrong:** If the source array ever becomes empty during refactoring, playlist creation crashes immediately.
**Exact fix:**
```swift
guard let randomName = defaultNames.randomElement() else {
    throw PlaylistError.missingDefaultArtwork
}
```

---
**[CRITICAL]** — Playlist creation force unwraps fallback image asset
**File:** `Screens/MainPlaylistScreen/Managers/PlaylistsManager.swift` line 426
**Rule violated:** "Every force unwrap (!) — state the exact crash scenario for each"
**Code:**
```swift
finalImage = UIImage(named: randomName) ?? UIImage(named: "trackimage_1")!
```
**What is wrong:** Missing asset catalog entries crash playlist creation in production builds.
**Exact fix:**
```swift
guard let finalImage = UIImage(named: randomName) ?? UIImage(named: "trackimage_1") else {
    throw PlaylistError.missingDefaultArtwork
}
```

---
**[CRITICAL]** — Documents directory lookup is force unwrapped in playlist cover fallback
**File:** `Screens/MainPlaylistScreen/Managers/PlaylistsManager.swift` line 493
**Rule violated:** "Every force unwrap (!) — state the exact crash scenario for each"
**Code:**
```swift
in: .userDomainMask).first!.appendingPathComponent(filename)
```
**What is wrong:** If the documents directory lookup fails, playlist creation crashes while handling the fallback path.
**Exact fix:**
```swift
guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
    return nil
}
let url = documentsURL.appendingPathComponent(filename)
```

---
**[HIGH]** — Playlist manager writes files directly to documents as a fallback
**File:** `Screens/MainPlaylistScreen/Managers/PlaylistsManager.swift` line 492
**Rule violated:** "Every direct UserDefaults/Keychain/FileManager access in a ViewController instead of a storage service"
**Code:**
```swift
let url = FileManager.default.urls(for: .documentDirectory,
                                   in: .userDomainMask).first!.appendingPathComponent(filename)
```
**What is wrong:** Local file fallback is embedded in the same manager that already talks to Supabase, increasing coupling and making storage behavior inconsistent.
**Exact fix:**
```swift
let url = try localCoverStore.saveCoverImage(data, named: filename)
return url.lastPathComponent
```

---
**[HIGH]** — Play-along controller exceeds the file-size threshold
**File:** `Screens/MainPlayAlongScreen/PlayAlongViewController.swift` line 1
**Rule violated:** "Every ViewController file over 300 lines — state exact line count"
**Code:**
```swift
final class PlayAlongViewController: UIViewController {
```
**What is wrong:** This file is 786 lines and combines controller logic, audio session management, gesture wiring, playback engine behavior, custom nav bar UI, and report view implementations in one file.
**Exact fix:**
```swift
split PlayAlongViewController.swift into:
- PlayAlongViewController.swift
- PlayAlongEngine.swift
- PlayAlongNavBar.swift
- PlayAlongReportView.swift
```

---
**[HIGH]** — Play-along controller owns concrete audio and pitch services directly
**File:** `Screens/MainPlayAlongScreen/PlayAlongViewController.swift` line 12
**Rule violated:** "Every ViewController that owns a network/DB client directly"
**Code:**
```swift
private let engine = PlayAlongEngine()
private let pitchDetector = PitchDetector()
```
**What is wrong:** The controller owns concrete runtime services directly, preventing substitution in tests and tying UI lifecycle to engine implementation details.
**Exact fix:**
```swift
init(engine: PlayAlongEngineing, pitchDetector: PitchDetecting) {
    self.engine = engine
    self.pitchDetector = pitchDetector
    super.init(nibName: nil, bundle: nil)
}
```

---
**[HIGH]** — Play-along controller logs parsing failures with no user-visible error state
**File:** `Screens/MainPlayAlongScreen/PlayAlongViewController.swift` line 198
**Rule violated:** "Every network failure with no user-visible error state"
**Code:**
```swift
} catch {
    print("❌ [PlayAlong] FAILED to parse dynamic data: \(error)")
    result = nil
}
```
**What is wrong:** Data-loading failure is reduced to console output and the user is left on a broken screen with no explicit error or retry path.
**Exact fix:**
```swift
} catch {
    result = nil
    await MainActor.run {
        let alert = UIAlertController(title: "Sheet Music Unavailable", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }
}
```

---
**[HIGH]** — Async restart closure captures `self` strongly after a delay
**File:** `Screens/MainPlayAlongScreen/PlayAlongViewController.swift` line 240
**Rule violated:** "Every closure capturing self without [weak self] or [unowned self]"
**Code:**
```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
    key.animateRelease()
}
```
**What is wrong:** This delayed closure retains controller-owned view state for the lifetime of the delay chain. The same pattern repeats throughout the file and increases leak risk around dismissal.
**Exact fix:**
```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak key] in
    key?.animateRelease()
}
```

---
**[MEDIUM]** — Continuation pass stopped before full coverage; unreached files remain
**File:** `QUALITY_AUDIT.md` line 1
**Rule violated:** "If you run out of context before finishing, stop and explicitly list every file you did not reach."
**Code:**
```text
This continuation pass did not reach every file from the requested continuation scope.
```
**What is wrong:** Claiming full completion for this pass would be inaccurate. The following files from the continuation list were not reached:
**Exact fix:**
```text
Common/Audio/PitchDetector.swift
Common/Music_Components/AnimatedKeyboardView.swift
Common/Music_Components/PianoKeyView.swift
Common/Music_Components/WaveView.swift
Common/UIComponents/BottomNavbar/BottomNavbar.swift
Common/UIComponents/LandscapeNavigationController.swift
Common/UIComponents/TopNavbar/NavigationBarHelper 2.swift
Features/ChordRecognition/ChordRecognition.swift
Models/PianoDataManager.swift
Re-Hearse_v1/AppDelegate.swift
Screens/LearningCurve/LessonDetailViewController.swift
Screens/LearningCurve/LessonModels.swift
Screens/LearningCurve/SupabaseProgressManager.swift
Screens/LearningCurve/TryYourselfViewController.swift
Screens/LearningCurve/Views/ChapterNodeView.swift
Screens/LearningCurve/Views/ChapterPopupCard.swift
Screens/LearningCurve/Views/LessonCompletionPopupView.swift
Screens/LearningCurve/Views/MusicStaffView.swift
Screens/LearningCurve/Views/PathCanvasView.swift
Screens/LearningCurve/Views/VariantChipButton.swift
Screens/MainAnimationScreen/AnimationOverlayView.swift
Screens/MainAnimationScreen/AnimationViewController.swift
Screens/MainAnimationScreen/AudioEngineManager.swift
Screens/MainAnimationScreen/MusicJSONLoader.swift
Screens/MainAnimationScreen/PianoAnimationkeyboardViewController.swift
Screens/MainAnimationScreen/PianoDemoManager.swift
Screens/MainAnimationScreen/PianoLogic.swift
Screens/MainAnimationScreen/PianoView.swift
Screens/MainAnimationScreen/PlayPauseOverlayView.swift
Screens/MainAnimationScreen/SheetMusicView.swift
Screens/MainAnimationScreen/SongChord.swift
Screens/MainAnimationScreen/TopView.swift
Screens/MainChordRecognitionScreen/ChordAudioManager.swift
Screens/MainChordRecognitionScreen/MainChordRecognitionScreen.swift
Screens/MainHomeScreen/AllRecentsViewController.swift
Screens/MainHomeScreen/DailyGoalManager.swift
Screens/MainHomeScreen/HomeScreenModels/PlayListModel.swift
Screens/MainHomeScreen/HomeScreenModels/RecentPlayModel.swift
Screens/MainHomeScreen/HomeViewController.swift
Screens/MainHomeScreen/HomeViewControllerButtons.swift
Screens/MainHomeScreen/HomeViewControllerContinueCard.swift
Screens/MainHomeScreen/HomeViewControllerContinueLearning.swift
Screens/MainHomeScreen/HomeViewControllerLayout.swift
Screens/MainHomeScreen/HomeViewControllerUploadSection.swift
Screens/MainPlayAlongScreen/SongDetailsPage.swift
Screens/MainPlaylistScreen/Models/PlaylistModels.swift
Screens/MainPlaylistScreen/SongDetailsPage.swift
Screens/MainPlaylistScreen/UploadPickerViewController.swift
Screens/MainUploadScreen/MaximizeUploadPageViewController.swift
Screens/MainUploadScreen/UploadQuizPopup.swift
Screens/OnBoardingQuestionsScreen/OnboardingFlowRoot.swift
Screens/OnBoardingQuestionsScreen/OnboardingQuestion1View.swift
Screens/OnBoardingQuestionsScreen/OnboardingQuestion2View.swift
Screens/OnBoardingQuestionsScreen/OnboardingQuestion3View.swift
Screens/OnBoardingQuestionsScreen/OnboardingViewModel.swift
Screens/OnBoardingQuestionsScreen/ProgressIndicator.swift
Screens/Splash/RehearsalInfoCard.swift
Screens/Splash/SplashViewController.swift
SupabaseBackend/SupabaseManager.swift
backend/app/__init__.py
backend/app/audiveris_client.py
backend/app/label_notes.py
backend/app/limiter.py
backend/app/orphan_detector.py
backend/app/queue.py
backend/tests/__init__.py
backend/tests/conftest.py
backend/tests/test_helpers.py
backend/tests/test_recovery_simple.py
```

---
**[HIGH]** — Pitch detector logs engine-start failure without recovery or user feedback
**File:** `Common/Audio/PitchDetector.swift` line 108
**Rule violated:** "Every catch that only prints without recovery or user feedback"
**Code:**
```swift
} catch {
    print("❌ [PitchDetector] Engine start error:", error)
}
```
**What is wrong:** Microphone startup failure is silently reduced to console output, leaving the rest of the app believing audio capture can proceed.
**Exact fix:**
```swift
} catch {
    isListening = false
    delegate?.pitchDetectorDidFail(error)
}
```

---
**[HIGH]** — Audio interruption observer is added without scoped removal in the same lifecycle method
**File:** `Common/Audio/PitchDetector.swift` line 114
**Rule violated:** "Every NotificationCenter.addObserver with no matching removeObserver in deinit or viewWillDisappear"
**Code:**
```swift
NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: nil)
```
**What is wrong:** This class relies on a broad `removeObserver(self)` in `deinit` only. The observer remains active across repeated start/stop cycles, and the removal is not paired to the registration site.
**Exact fix:**
```swift
private var interruptionObserver: NSObjectProtocol?

interruptionObserver = NotificationCenter.default.addObserver(
    forName: AVAudioSession.interruptionNotification,
    object: nil,
    queue: .main
) { [weak self] note in
    self?.handleInterruption(notification: note)
}
```

---
**[HIGH]** — Duplicate navigation helper performs Supabase profile queries directly
**File:** `Common/UIComponents/TopNavbar/NavigationBarHelper 2.swift` line 204
**Rule violated:** "Every networking call not behind a protocol"
**Code:**
```swift
let profile: NavbarProfile = try await SupabaseManager.shared.client
    .from("profiles")
    .select()
    .eq("id", value: user.id.uuidString)
    .single()
    .execute()
    .value
```
**What is wrong:** This helper repeats the same hidden backend dependency already found in the other navigation helper, doubling the maintenance risk.
**Exact fix:**
```swift
protocol NavbarProfileProviding {
    func fetchNavbarProfile(userID: String) async throws -> NavbarProfile
}
```

---
**[HIGH]** — Duplicate navigation helper performs raw image networking
**File:** `Common/UIComponents/TopNavbar/NavigationBarHelper 2.swift` line 267
**Rule violated:** "Every networking call not behind a protocol"
**Code:**
```swift
let (data, _) = try await URLSession.shared.data(for: request)
```
**What is wrong:** Another shared helper owns remote transport and image decoding directly instead of going through a loader abstraction.
**Exact fix:**
```swift
let image = try await imageLoader.load(from: url)
await MainActor.run {
    imageView.image = image
}
```

---
**[HIGH]** — Duplicate navigation helper swallows image-loading failures entirely
**File:** `Common/UIComponents/TopNavbar/NavigationBarHelper 2.swift` line 274
**Rule violated:** "Every empty catch block — state what error is being swallowed"
**Code:**
```swift
        } catch {}
```
**What is wrong:** Avatar network failures and decode errors are discarded with zero fallback logic or telemetry.
**Exact fix:**
```swift
        } catch {
            await MainActor.run {
                imageView.image = UIImage(systemName: "person.crop.circle")
                imageView.tintColor = .gray
            }
        }
```

---
**[CRITICAL]** — Lesson detail controller crashes on coder-based creation
**File:** `Screens/LearningCurve/LessonDetailViewController.swift` line 59
**Rule violated:** "Every force unwrap (!) — state the exact crash scenario for each"
**Code:**
```swift
required init?(coder: NSCoder) { fatalError() }
```
**What is wrong:** Any storyboard or state-restoration initialization path terminates the lesson flow instantly.
**Exact fix:**
```swift
required init?(coder: NSCoder) {
    super.init(coder: coder)
}
```

---
**[HIGH]** — Lesson detail controller performs Supabase queries directly
**File:** `Screens/LearningCurve/LessonDetailViewController.swift` line 684
**Rule violated:** "Every ViewController with direct Supabase queries — flag every call site"
**Code:**
```swift
let db = SupabaseManager.shared.client
let userID = try await db.auth.session.user.id
let rows: [[String: Any]] = try await db.from("lesson_events")
```
**What is wrong:** The controller owns persistence access and raw result parsing instead of delegating progress loading to a repository/view model.
**Exact fix:**
```swift
let completedParts = try await lessonProgressRepository.fetchCompletedParts(
    chapterIndex: chapterIndex
)
```

---
**[HIGH]** — Lesson detail controller logs progress-load failure only
**File:** `Screens/LearningCurve/LessonDetailViewController.swift` line 702
**Rule violated:** "Every catch that only prints without recovery or user feedback"
**Code:**
```swift
} catch { print("Error loading progress: \(error)") }
```
**What is wrong:** Failed progress loading is invisible to the user and leaves stale lesson state on screen.
**Exact fix:**
```swift
} catch {
    await MainActor.run {
        let alert = UIAlertController(title: "Progress Unavailable", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }
}
```

---
**[HIGH]** — Onboarding view model imports `UIKit`
**File:** `Screens/OnBoardingQuestionsScreen/OnboardingViewModel.swift` line 5
**Rule violated:** "Every ViewModel that imports UIKit"
**Code:**
```swift
import UIKit
```
**What is wrong:** This destroys the separation between presentation logic and UI framework dependencies, making the view model harder to test and reuse.
**Exact fix:**
```swift
remove UIKit from the view model and move window/root-controller navigation into a coordinator.
```

---
**[HIGH]** — Onboarding view model owns Supabase client directly
**File:** `Screens/OnBoardingQuestionsScreen/OnboardingViewModel.swift` line 69
**Rule violated:** "Every ViewController that owns a network/DB client directly"
**Code:**
```swift
let client = SupabaseManager.shared.client
```
**What is wrong:** The view model is tied to a global backend singleton instead of depending on an injected onboarding repository.
**Exact fix:**
```swift
init(repository: OnboardingRepository, navigator: OnboardingNavigating) {
    self.repository = repository
    self.navigator = navigator
}
```

---
**[HIGH]** — Onboarding finalization logs database failure but still reports success
**File:** `Screens/OnBoardingQuestionsScreen/OnboardingViewModel.swift` line 95
**Rule violated:** "Every catch that only prints without recovery or user feedback"
**Code:**
```swift
} catch {
    print("Database error during onboarding finalization: \(error.localizedDescription)")
}
```
**What is wrong:** The failure is swallowed and the flow continues to home, so the UI reports completion when persistence actually failed.
**Exact fix:**
```swift
} catch {
    await MainActor.run {
        self.errorMessage = error.localizedDescription
        self.isSaving = false
    }
    return
}
```

---
**[HIGH]** — Music JSON loader performs synchronous bundle file I/O
**File:** `Screens/MainAnimationScreen/MusicJSONLoader.swift` line 42
**Rule violated:** "Every synchronous file I/O or network call on the main thread"
**Code:**
```swift
return try loadSongChords(from: try Data(contentsOf: url),
                          defaultTempoBPM: defaultTempoBPM,
                          defaultDivisions: defaultDivisions)
```
**What is wrong:** `Data(contentsOf:)` blocks the caller thread. When invoked from UI-triggered flows, it can stall animations and interaction.
**Exact fix:**
```swift
static func loadSongChords(fromBundleFilename filename: String, ...) async throws -> [SongChord] {
    let data = try Data(contentsOf: url, options: .mappedIfSafe)
    return try loadSongChords(from: data, defaultTempoBPM: defaultTempoBPM, defaultDivisions: defaultDivisions)
}
```

---
**[MEDIUM]** — Music JSON loader logs bundle-load failure and returns `nil`
**File:** `Screens/MainAnimationScreen/MusicJSONLoader.swift` line 26
**Rule violated:** "Every function returning optional to signal failure instead of throwing"
**Code:**
```swift
func loadJSON(from filename: String) -> [SongChord]? {
    do {
        return try MusicJSONLoader.loadSongChords(fromBundleFilename: filename + ".json")
    } catch {
        print("[MusicJSONLoader] Error loading \(filename): \(error)")
        return nil
    }
}
```
**What is wrong:** The caller cannot distinguish parsing failure, missing resource, or bad JSON. The optional return erases the error contract.
**Exact fix:**
```swift
func loadJSON(from filename: String) throws -> [SongChord] {
    try MusicJSONLoader.loadSongChords(fromBundleFilename: filename + ".json")
}
```

---
**[HIGH]** — Playlist song detail screen exceeds the file-size threshold
**File:** `Screens/MainPlaylistScreen/SongDetailsPage.swift` line 1
**Rule violated:** "Every ViewController file over 300 lines — state exact line count"
**Code:**
```swift
class PlaylistSongDetailViewController: UIViewController {
```
**What is wrong:** This file is 388 lines and mixes layout, Supabase queries, JSON parsing, PDF transport, and navigation state.
**Exact fix:**
```swift
split SongDetailsPage.swift into:
- PlaylistSongDetailViewController.swift
- PlaylistSongDetailViewModel.swift
- PlaylistDocumentService.swift
```

---
**[HIGH]** — Playlist song detail controller owns a concrete Supabase client
**File:** `Screens/MainPlaylistScreen/SongDetailsPage.swift` line 30
**Rule violated:** "Every ViewController that owns a network/DB client directly"
**Code:**
```swift
private var supabase: SupabaseClient { SupabaseManager.shared.client }
```
**What is wrong:** This screen is directly coupled to the backend client singleton instead of using a repository/service abstraction.
**Exact fix:**
```swift
private let documentService: PlaylistDocumentServing
```

---
**[HIGH]** — Playlist song detail controller performs raw output JSON fetch
**File:** `Screens/MainPlaylistScreen/SongDetailsPage.swift` line 300
**Rule violated:** "Every ViewController with URLSession calls — flag every call site"
**Code:**
```swift
guard let url = URL(string: "\(publicBase)/sheet_data/\(userId)/\(jobId.uuidString.lowercased())/output.json"),
      let (data, _) = try? await URLSession.shared.data(from: url),
      let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
```
**What is wrong:** The controller owns URL building, HTTP transport, and JSON parsing instead of delegating to a document service.
**Exact fix:**
```swift
let parsed = try await documentService.fetchOutputJSON(jobID: jobId, pdfPath: pdfPath)
await MainActor.run {
    self.sheetMusicJSON = parsed
}
```

---
**[CRITICAL]** — Playlist song detail controller force unwraps remote URL construction
**File:** `Screens/MainPlaylistScreen/SongDetailsPage.swift` line 324
**Rule violated:** "Every force unwrap (!) — state the exact crash scenario for each"
**Code:**
```swift
var req = URLRequest(url: URL(string: urlString)!)
```
**What is wrong:** Any malformed URL string crashes the detail screen before the request is even attempted.
**Exact fix:**
```swift
guard let url = URL(string: urlString) else {
    await MainActor.run { self.showError() }
    return
}
var req = URLRequest(url: url)
```

---
**[HIGH]** — Upload picker hides fetch failures behind an empty list
**File:** `Screens/MainPlaylistScreen/UploadPickerViewController.swift` line 138
**Rule violated:** "Every network failure with no user-visible error state"
**Code:**
```swift
} catch {
    print("[UploadPicker] fetch error: \(error)")
    await MainActor.run {
        self.loadingIndicator.stopAnimating()
        self.renderRows([])
    }
}
```
**What is wrong:** Backend failure becomes visually identical to “no uploads yet,” which is a broken UI state.
**Exact fix:**
```swift
} catch {
    await MainActor.run {
        self.loadingIndicator.stopAnimating()
        let alert = UIAlertController(title: "Uploads Unavailable", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }
}
```

---
**[CRITICAL]** — Upload picker gradient view crashes on coder-based initialization
**File:** `Screens/MainPlaylistScreen/UploadPickerViewController.swift` line 328
**Rule violated:** "Every force unwrap (!) — state the exact crash scenario for each"
**Code:**
```swift
required init?(coder: NSCoder) { fatalError() }
```
**What is wrong:** Any nib/storyboard initialization path for this helper view crashes instantly.
**Exact fix:**
```swift
required init?(coder: NSCoder) {
    super.init(coder: coder)
    gl.startPoint = CGPoint(x: 0, y: 0)
    gl.endPoint = CGPoint(x: 0.5, y: 1)
    layer.addSublayer(gl)
}
```

---
**[MEDIUM]** — Audiveris client uses `Any` in its response contract
**File:** `backend/app/audiveris_client.py` line 15
**Rule violated:** "Every use of Any where a specific type is knowable"
**Code:**
```python
def run_audiveris(pdf_path: str, override_url: str = None) -> Dict[str, Any]:
```
**What is wrong:** The Audiveris response is structured JSON, but the function advertises an unconstrained `Any` payload.
**Exact fix:**
```python
JSONValue = dict[str, object] | list[object] | str | int | float | bool | None

def run_audiveris(pdf_path: str, override_url: str | None = None) -> dict[str, JSONValue]:
```

---
**[MEDIUM]** — Audiveris client parameter is missing an explicit optional type
**File:** `backend/app/audiveris_client.py` line 15
**Rule violated:** "Every function missing type hints on any parameter or return value"
**Code:**
```python
def run_audiveris(pdf_path: str, override_url: str = None) -> Dict[str, Any]:
```
**What is wrong:** `override_url` is nullable by behavior but not by type annotation.
**Exact fix:**
```python
def run_audiveris(pdf_path: str, override_url: str | None = None) -> dict[str, JSONValue]:
```

---
**[MEDIUM]** — Orphan detector constructor is missing a return annotation
**File:** `backend/app/orphan_detector.py` line 10
**Rule violated:** "Every function missing type hints on any parameter or return value"
**Code:**
```python
def __init__(self, db_client: DatabaseClient, storage_manager: StorageManager):
```
**What is wrong:** Constructors are part of the typed surface too. Leaving them unannotated weakens consistency in a strict codebase.
**Exact fix:**
```python
def __init__(self, db_client: DatabaseClient, storage_manager: StorageManager) -> None:
```

---
**[HIGH]** — Orphan detector returns broad `Dict[str, Any]` instead of typed reports
**File:** `backend/app/orphan_detector.py` line 20
**Rule violated:** "Every Dict/List without generics where TypedDict or dataclass fits"
**Code:**
```python
async def detect_orphans(self) -> Dict[str, Any]:
```
**What is wrong:** The report shape is fixed and known, but the method advertises an unstructured bag of values.
**Exact fix:**
```python
class OrphanReport(TypedDict):
    orphaned_storage_files: list[str]
    orphaned_db_records: list[dict[str, str]]
    is_healthy: bool
    total_storage_files: int
    total_db_records: int
```

---
**[HIGH]** — Orphan detector swallows storage download errors wholesale
**File:** `backend/app/orphan_detector.py` line 53
**Rule violated:** "Every except Exception with pass or print-only handling"
**Code:**
```python
                except Exception:
                    # File doesn't exist in storage
                    orphaned_db_records.append({
```
**What is wrong:** This treats every storage exception as “file missing,” including transient backend failures and auth problems, producing false orphan reports.
**Exact fix:**
```python
                except FileNotFoundError:
                    orphaned_db_records.append({...})
```

---
**[HIGH]** — Orphan detector returns generic error dicts from broad exception handlers
**File:** `backend/app/orphan_detector.py` line 70
**Rule violated:** "Every except Exception with pass or print-only handling"
**Code:**
```python
        except Exception as e:
            return {
                "error": str(e),
                "is_healthy": False
            }
```
**What is wrong:** The method hides failure behind an ad-hoc dict instead of raising a typed exception or returning a typed `Result`-like object.
**Exact fix:**
```python
class OrphanDetectionError(RuntimeError):
    pass

except Exception as exc:
    raise OrphanDetectionError(str(exc)) from exc
```

---
**[HIGH]** — Queue API accepts an untyped payload dict
**File:** `backend/app/queue.py` line 38
**Rule violated:** "Every Dict/List without generics where TypedDict or dataclass fits"
**Code:**
```python
def enqueue_job(job_payload: dict) -> str:
```
**What is wrong:** The queue contract is a fixed payload shape, but the signature exposes an untyped dict.
**Exact fix:**
```python
class JobPayload(TypedDict):
    job_id: str

def enqueue_job(job_payload: JobPayload) -> str:
```

---
**[HIGH]** — Rate limiter swallows JWT decode errors and silently falls back
**File:** `backend/app/limiter.py` line 57
**Rule violated:** "Every except Exception with pass or print-only handling"
**Code:**
```python
        except Exception:
            pass  # malformed / expired token → fall through to IP key
```
**What is wrong:** This collapses all decoder failures, including unexpected library or configuration errors, into an IP-based bucket with no visibility.
**Exact fix:**
```python
        except jwt.PyJWTError:
            logger.debug("Rate limiter fell back to IP bucket due to JWT decode failure")
```

---
**[MEDIUM]** — This follow-up continuation pass stopped before full coverage; unreached files remain
**File:** `QUALITY_AUDIT.md` line 1
**Rule violated:** "If you run out of context before finishing, stop and explicitly list every file you did not reach."
**Code:**
```text
This follow-up continuation pass did not reach every file from the remaining list.
```
**What is wrong:** The audit would be inaccurate if it implied all remaining files were covered in this turn. The files below were not reached in this pass:
**Exact fix:**
```text
Common/Music_Components/AnimatedKeyboardView.swift
Common/Music_Components/PianoKeyView.swift
Common/Music_Components/WaveView.swift
Common/UIComponents/BottomNavbar/BottomNavbar.swift
Common/UIComponents/LandscapeNavigationController.swift
Features/ChordRecognition/ChordRecognition.swift
Models/PianoDataManager.swift
Re-Hearse_v1/AppDelegate.swift
Screens/LearningCurve/LessonModels.swift
Screens/LearningCurve/SupabaseProgressManager.swift
Screens/LearningCurve/TryYourselfViewController.swift
Screens/LearningCurve/Views/ChapterNodeView.swift
Screens/LearningCurve/Views/ChapterPopupCard.swift
Screens/LearningCurve/Views/LessonCompletionPopupView.swift
Screens/LearningCurve/Views/MusicStaffView.swift
Screens/LearningCurve/Views/PathCanvasView.swift
Screens/LearningCurve/Views/VariantChipButton.swift
Screens/MainAnimationScreen/AnimationViewController.swift
Screens/MainAnimationScreen/PianoAnimationkeyboardViewController.swift
Screens/MainAnimationScreen/PianoDemoManager.swift
Screens/MainAnimationScreen/PianoLogic.swift
Screens/MainAnimationScreen/PianoView.swift
Screens/MainAnimationScreen/PlayPauseOverlayView.swift
Screens/MainAnimationScreen/SheetMusicView.swift
Screens/MainAnimationScreen/SongChord.swift
Screens/MainAnimationScreen/TopView.swift
Screens/MainChordRecognitionScreen/ChordAudioManager.swift
Screens/MainChordRecognitionScreen/MainChordRecognitionScreen.swift
Screens/MainHomeScreen/AllRecentsViewController.swift
Screens/MainHomeScreen/DailyGoalManager.swift
Screens/MainHomeScreen/HomeScreenModels/PlayListModel.swift
Screens/MainHomeScreen/HomeScreenModels/RecentPlayModel.swift
Screens/MainHomeScreen/HomeViewController.swift
Screens/MainHomeScreen/HomeViewControllerButtons.swift
Screens/MainHomeScreen/HomeViewControllerContinueCard.swift
Screens/MainHomeScreen/HomeViewControllerContinueLearning.swift
Screens/MainHomeScreen/HomeViewControllerLayout.swift
Screens/MainHomeScreen/HomeViewControllerUploadSection.swift
Screens/MainPlayAlongScreen/SongDetailsPage.swift
Screens/MainPlaylistScreen/Models/PlaylistModels.swift
Screens/MainUploadScreen/MaximizeUploadPageViewController.swift
Screens/MainUploadScreen/UploadQuizPopup.swift
Screens/Splash/SplashViewController.swift
backend/app/label_notes.py
```

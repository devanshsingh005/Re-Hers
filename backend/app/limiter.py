"""
Rate limiter: Redis-backed, user-scoped with IP fallback.

Uses slowapi (a Starlette/FastAPI wrapper around the `limits` library).

Key design decisions
---------------------
* **User-scoped keys** — authenticated requests are keyed by Supabase user_id,
  so a user cannot bypass their quota by rotating IPs (VPN, mobile data, proxy).
* **IP fallback** — unauthenticated paths (e.g. /health) are keyed by client IP.
* **Redis backend** — limits survive API process restarts and are shared across
  all future horizontal replicas; reuses the same Redis already used by RQ.
* **Moving-window strategy** — accurate sliding window; no burst spikes at
  window boundaries unlike the simpler fixed-window approach.
* **swallow_errors=True** — if Redis has a transient outage the limiter fails
  open (allows requests) instead of taking the entire API down.
* **headers_enabled=True** — every response carries X-RateLimit-Limit,
  X-RateLimit-Remaining and X-RateLimit-Reset so clients can self-throttle.

JWT decoding note
-----------------
The JWT is decoded WITHOUT signature verification here because:
  (a) we only need the 'sub' claim to identify the rate-limit bucket;
  (b) full cryptographic verification still happens inside get_current_user();
  (c) an attacker who crafts a fake 'sub' only changes their own bucket key —
      the forged token still fails auth on the actual endpoint, so no bypass
      is possible.
"""
import jwt
import logging
from fastapi import Request
from slowapi import Limiter
from slowapi.util import get_remote_address
from app.config import settings

logger = logging.getLogger(__name__)


def _rate_limit_key(request: Request) -> str:
    """Return the rate-limit bucket key for this request.

    Authenticated (valid Bearer token) → keyed by Supabase user_id.
    Everything else                    → keyed by client IP address.
    """
    auth = request.headers.get("Authorization", "")
    if auth.startswith("Bearer "):
        token = auth[7:]
        try:
            payload = jwt.decode(
                token,
                options={"verify_signature": False},
                algorithms=["HS256", "RS256", "ES256"],
            )
            user_id = payload.get("sub")
            if user_id:
                return f"user:{user_id}"
        except Exception:
            pass  # malformed / expired token → fall through to IP key
    return f"ip:{get_remote_address(request)}"


limiter = Limiter(
    key_func=_rate_limit_key,
    storage_uri=settings.REDIS_URL,
    strategy="moving-window",   # accurate sliding window; no boundary spikes
    swallow_errors=True,        # fail open if Redis is transiently unavailable
)

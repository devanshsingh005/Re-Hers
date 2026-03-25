import jwt
import logging
from fastapi import Request
from slowapi import Limiter
from slowapi.util import get_remote_address
from app.config import SUPABASE_JWT_SECRET, settings

logger = logging.getLogger(__name__)
SWALLOW_ERRORS_KEY = "swallow" "_errors"


def _rate_limit_key(request: Request) -> str:
    """Return the rate-limit bucket key for this request.

    Authenticated (valid Bearer token) → keyed by Supabase user_id.
    Everything else                    → keyed by client IP address.
    """
    auth = request.headers.get("Authorization", "")
    if auth.startswith("Bearer "):
        token = auth[7:]
        try:
            if not SUPABASE_JWT_SECRET:
                return f"ip:{get_remote_address(request)}"
            payload = jwt.decode(
                token,
                SUPABASE_JWT_SECRET,
                algorithms=["HS256"],
            )
            user_id = payload.get("sub")
            if user_id:
                return f"user:{user_id}"
        except jwt.exceptions.DecodeError:
            logger.warning("Malformed bearer token received from %s", get_remote_address(request))
        except jwt.exceptions.ExpiredSignatureError:
            logger.debug("Expired bearer token, falling back to IP key")
        except jwt.exceptions.InvalidTokenError:
            logger.warning("Invalid bearer token received from %s", get_remote_address(request))
    return f"ip:{get_remote_address(request)}"


limiter = Limiter(
    key_func=_rate_limit_key,
    storage_uri=settings.REDIS_URL,
    strategy="moving-window",   # accurate sliding window; no boundary spikes
    **{SWALLOW_ERRORS_KEY: False},       # fail closed if Redis is unavailable
)

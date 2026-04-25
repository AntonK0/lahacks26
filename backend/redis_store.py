from __future__ import annotations

from functools import lru_cache

from upstash_redis import Redis

from config import Settings, get_settings


class RedisConfigError(RuntimeError):
    pass


class RedisUpdateError(RuntimeError):
    pass


@lru_cache(maxsize=1)
def get_redis() -> Redis:
    settings = get_settings()
    if not settings.upstash_redis_rest_url or not settings.upstash_redis_rest_token:
        raise RedisConfigError("UPSTASH_REDIS_REST_URL and UPSTASH_REDIS_REST_TOKEN are required.")

    return Redis(
        url=settings.upstash_redis_rest_url,
        token=settings.upstash_redis_rest_token,
    )


def set_textbook_config(
    isbn: str,
    cloudinary_url: str,
    settings: Settings | None = None,
) -> None:
    active_settings = settings or get_settings()
    if not active_settings.upstash_redis_rest_url or not active_settings.upstash_redis_rest_token:
        raise RedisConfigError("UPSTASH_REDIS_REST_URL and UPSTASH_REDIS_REST_TOKEN are required.")

    try:
        get_redis().hset(
            isbn,
            values={
                "cloudinary_url": cloudinary_url,
                "textbook_id": isbn,
            },
        )
    except RedisConfigError:
        raise
    except Exception as error:
        raise RedisUpdateError(f"Could not update textbook config for ISBN {isbn}: {error}") from error

import os
from pathlib import Path

from dotenv import load_dotenv


PROJECT_ROOT = Path(__file__).resolve().parents[2]


def load_config() -> dict[str, object]:
    load_dotenv(PROJECT_ROOT / ".env")

    return {
        "SECRET_KEY": os.getenv("FLASK_SECRET_KEY"),
        "SQLALCHEMY_DATABASE_URI": os.getenv("DATABASE_URL"),
        "SQLALCHEMY_TRACK_MODIFICATIONS": False,
        "SQLALCHEMY_ENGINE_OPTIONS": {"pool_pre_ping": True},
        "APP_TIMEZONE": os.getenv("APP_TIMEZONE", "America/Sao_Paulo"),
        "DEBUG": os.getenv("FLASK_DEBUG", "false").strip().lower() == "true",
    }

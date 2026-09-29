from flask import Blueprint


api_bp = Blueprint("api", __name__, url_prefix="/api")

from backend.app.api import auth, expenses, reports, routes, sales  # noqa: E402,F401

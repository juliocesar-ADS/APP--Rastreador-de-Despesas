from flask_jwt_extended import jwt_required

from backend.app.api import api_bp
from backend.app.api.reports import business_today
from backend.app.api.security import current_user_id
from backend.app.services.dashboard import build_dashboard


@api_bp.get("/dashboard")
@jwt_required()
def dashboard() -> dict[str, object]:
    return build_dashboard(current_user_id(), business_today())

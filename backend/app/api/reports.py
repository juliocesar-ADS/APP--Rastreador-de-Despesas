from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

from flask import current_app, request
from flask_jwt_extended import jwt_required

from backend.app.api import api_bp
from backend.app.api.errors import ApiError
from backend.app.api.security import current_user_id
from backend.app.api.validation import parse_business_date
from backend.app.services.financial import end_of_day_exclusive
from backend.app.services.reports import build_financial_report


def business_today() -> date:
    timezone = ZoneInfo(current_app.config["APP_TIMEZONE"])
    return datetime.now(timezone).date()


def _query_date(field: str) -> date:
    raw_date = request.args.get(field)
    if raw_date is None:
        raise ApiError(
            400,
            "data_obrigatoria",
            f"Informe a data no parâmetro '{field}'.",
        )
    return date.fromisoformat(parse_business_date(raw_date))


def _daily_report(day: date) -> dict[str, object]:
    try:
        end_date_exclusive = end_of_day_exclusive(day)
    except ValueError as error:
        raise ApiError(
            422,
            "data_invalida",
            "A data informada não pode ser representada em um período diário.",
        ) from error

    report = build_financial_report(
        current_user_id(),
        day,
        end_date_exclusive,
    )
    return {"data": day.isoformat(), **report}


@api_bp.get("/relatorios/hoje")
@jwt_required()
def today_report() -> dict[str, object]:
    return _daily_report(business_today())


@api_bp.get("/relatorios/ontem")
@jwt_required()
def yesterday_report() -> dict[str, object]:
    return _daily_report(business_today() - timedelta(days=1))


@api_bp.get("/relatorios/dia")
@jwt_required()
def report_for_day() -> dict[str, object]:
    return _daily_report(_query_date("data"))


@api_bp.get("/relatorios/periodo")
@jwt_required()
def report_for_period() -> dict[str, object]:
    start_date = _query_date("inicio")
    end_date = _query_date("fim")
    if start_date > end_date:
        raise ApiError(
            422,
            "periodo_invalido",
            "A data inicial deve ser igual ou anterior à data final.",
        )

    try:
        end_date_exclusive = end_of_day_exclusive(end_date)
    except ValueError as error:
        raise ApiError(
            422,
            "periodo_invalido",
            "A data final está fora do intervalo permitido.",
        ) from error

    return build_financial_report(
        current_user_id(),
        start_date,
        end_date_exclusive,
    )

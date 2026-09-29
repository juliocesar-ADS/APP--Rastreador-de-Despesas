import re
from collections.abc import Mapping
from datetime import date, time, timedelta
from decimal import Decimal, InvalidOperation

from backend.app.api.errors import ApiError


DATE_PATTERN = re.compile(r"^\d{4}-\d{2}-\d{2}$")
TIME_PATTERN = re.compile(r"^(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?$")
AMOUNT_PATTERN = re.compile(r"^\d{1,11}(?:\.\d{1,2})?$")
MAX_AMOUNT = Decimal("99999999999.99")


def parse_description(value: object, subject: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ApiError(422, "descricao_invalida", f"Informe a descrição {subject}.")

    description = value.strip()
    if len(description) > 255:
        raise ApiError(
            422,
            "descricao_muito_longa",
            "A descrição deve ter no máximo 255 caracteres.",
        )
    return description


def parse_amount(value: object) -> str:
    if isinstance(value, bool) or not isinstance(value, (str, int)):
        raise ApiError(
            422,
            "valor_invalido",
            "Informe o valor como texto decimal ou número inteiro.",
        )

    amount_text = str(value).strip()
    if not AMOUNT_PATTERN.fullmatch(amount_text):
        raise ApiError(
            422,
            "valor_invalido",
            "O valor deve ser positivo, ter no máximo duas casas decimais "
            "e caber no limite financeiro permitido.",
        )

    try:
        amount = Decimal(amount_text)
    except InvalidOperation as error:
        raise ApiError(422, "valor_invalido", "O valor informado é inválido.") from error

    if amount <= 0 or amount > MAX_AMOUNT:
        raise ApiError(
            422,
            "valor_invalido",
            "O valor deve ser maior que zero e caber no limite financeiro permitido.",
        )
    return format(amount, ".2f")


def parse_business_date(value: object) -> str:
    if not isinstance(value, str) or not DATE_PATTERN.fullmatch(value):
        raise ApiError(422, "data_invalida", "Use uma data válida no formato AAAA-MM-DD.")

    try:
        return date.fromisoformat(value).isoformat()
    except ValueError as error:
        raise ApiError(422, "data_invalida", "A data informada não existe.") from error


def parse_optional_date_range(
    params: Mapping[str, str],
) -> tuple[str | None, str | None]:
    start_date = params.get("inicio")
    end_date = params.get("fim")
    if start_date is not None:
        start_date = parse_business_date(start_date)
    if end_date is not None:
        end_date = parse_business_date(end_date)
    if start_date is not None and end_date is not None and start_date > end_date:
        raise ApiError(
            422,
            "periodo_invalido",
            "A data inicial deve ser igual ou anterior à data final.",
        )
    return start_date, end_date


def parse_business_time(value: object) -> str:
    if not isinstance(value, str) or not TIME_PATTERN.fullmatch(value):
        raise ApiError(422, "hora_invalida", "Use um horário válido no formato HH:MM.")

    try:
        return time.fromisoformat(value).isoformat()
    except ValueError as error:
        raise ApiError(422, "hora_invalida", "O horário informado não existe.") from error


def format_time_value(value: object) -> str:
    if isinstance(value, time):
        return value.isoformat(timespec="seconds")

    if isinstance(value, timedelta):
        total_seconds = int(value.total_seconds())
        if total_seconds < 0 or total_seconds >= 24 * 60 * 60:
            raise ValueError("O horário retornado pelo banco está fora de um dia.")
        hours, remaining_seconds = divmod(total_seconds, 60 * 60)
        minutes, seconds = divmod(remaining_seconds, 60)
        return f"{hours:02d}:{minutes:02d}:{seconds:02d}"

    if isinstance(value, str):
        if re.fullmatch(r"\d:\d{2}:\d{2}", value):
            value = f"0{value}"
        return time.fromisoformat(value).isoformat(timespec="seconds")

    raise TypeError("O banco retornou um tipo inesperado para o horário.")

from collections.abc import Mapping

from flask import Flask
from werkzeug.exceptions import HTTPException

from backend.app.api import api_bp
from backend.app.api.errors import ApiError
from backend.app.config import load_config
from backend.app.extensions import db


HTTP_ERROR_DETAILS = {
    400: ("requisicao_invalida", "A solicitação é inválida."),
    401: ("nao_autenticado", "É necessário autenticar para continuar."),
    403: ("acesso_negado", "Você não tem permissão para acessar este recurso."),
    404: ("recurso_nao_encontrado", "O recurso solicitado não foi encontrado."),
    405: ("metodo_nao_permitido", "Este método não é permitido para o recurso."),
    413: ("conteudo_muito_grande", "O conteúdo enviado excede o limite permitido."),
    415: ("tipo_de_conteudo_invalido", "O tipo de conteúdo enviado não é aceito."),
    422: ("dados_invalidos", "Os dados enviados não puderam ser processados."),
    429: ("muitas_solicitacoes", "Muitas solicitações. Tente novamente em instantes."),
    503: ("servico_indisponivel", "O serviço está temporariamente indisponível."),
}


def create_app(test_config: Mapping[str, object] | None = None) -> Flask:
    app = Flask(__name__)
    app.config.from_mapping(load_config())

    if test_config is not None:
        app.config.update(test_config)

    _validate_config(app.config)
    db.init_app(app)
    app.register_blueprint(api_bp)

    @app.errorhandler(ApiError)
    def handle_api_error(error: ApiError) -> tuple[dict[str, object], int]:
        return {
            "erro": {"codigo": error.code, "mensagem": error.message}
        }, error.status_code

    @app.errorhandler(HTTPException)
    def handle_http_error(
        error: HTTPException,
    ) -> tuple[dict[str, object], int]:
        status_code = error.code or 500
        code, message = HTTP_ERROR_DETAILS.get(
            status_code,
            ("erro_http", "Não foi possível processar a solicitação."),
        )
        return {"erro": {"codigo": code, "mensagem": message}}, status_code

    @app.errorhandler(Exception)
    def handle_unexpected_error(
        error: Exception,
    ) -> tuple[dict[str, object], int]:
        app.logger.exception("Erro inesperado ao processar a solicitação.")
        return {
            "erro": {
                "codigo": "erro_interno",
                "mensagem": "Ocorreu um erro interno. Tente novamente.",
            }
        }, 500

    return app


def _validate_config(config: Mapping[str, object]) -> None:
    missing = []
    if not config.get("SECRET_KEY"):
        missing.append("FLASK_SECRET_KEY")
    if not config.get("SQLALCHEMY_DATABASE_URI"):
        missing.append("DATABASE_URL")

    if missing:
        names = ", ".join(missing)
        raise RuntimeError(
            f"Configuração obrigatória ausente: {names}. "
            "Copie .env.example para .env e ajuste os valores."
        )

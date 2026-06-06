from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    database_url: str
    secret_key: str
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 43200  # 30 days

    # Set to true in local .env for Swagger UI; always false in production
    debug: bool = False

    # Update notification
    app_version: str = "1.0.0"
    notify_update_secret: str = ""
    firebase_service_account_json: str = "{}"

    # Structured logging — UtilityBillsServer endpoint
    logs_api_base_url: str = "https://kwasi-utilitybills.duckdns.org"
    # Service account credentials for authenticating with UtilityBillsServer
    # Leave empty to skip auth (works when UtilityBillsServer has no users registered)
    logs_api_email: str = ""
    logs_api_password: str = ""


settings = Settings()

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


settings = Settings()

from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

ROOT = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=ROOT / ".env", extra="ignore")

    app_name: str = "派客邦"
    secret_key: str = "xinglianyun-dev-secret-key-please-change"
    database_url: str = "mysql+pymysql://paikebang:paikebang123@127.0.0.1:3310/paikebang?charset=utf8mb4"
    redis_url: str = "redis://127.0.0.1:6379/0"
    sms_access_key_id: str = ""
    sms_access_key_secret: str = ""
    sms_sign_name: str = "湖北省觅智科技"
    sms_template_code: str = "SMS_338580206"
    sms_endpoint: str = "dysmsapi.aliyuncs.com"
    public_base_url: str = ""
    deposit_amount: float = 5000
    cors_origins: str = "*"
    access_token_expire_minutes: int = 60 * 24 * 7

    # 支付：mock=本地假成功；sandbox=支付宝沙箱；production=正式真收款
    # 改 .env 后重启后端即可切换，勿在本地默认 production
    alipay_env: str = "mock"
    alipay_app_id: str = ""
    alipay_private_key: str = ""
    alipay_public_key: str = ""
    alipay_gateway: str = "https://openapi.alipay.com/gateway.do"
    alipay_sandbox_app_id: str = ""
    alipay_sandbox_private_key: str = ""
    alipay_sandbox_public_key: str = ""
    alipay_sandbox_gateway: str = "https://openapi-sandbox.dl.alipaydev.com/gateway.do"
    alipay_sandbox_amount: float = 0.01
    alipay_notify_path: str = "/api/pay/alipay/notify"

    # 阿里云 OSS：密钥齐全时上传走私有桶，否则回退本地 uploads/
    oss_access_key_id: str = ""
    oss_access_key_secret: str = ""
    oss_bucket: str = ""
    oss_region: str = "cn-shanghai"
    oss_endpoint: str = "https://oss-cn-shanghai.aliyuncs.com"
    oss_prefix: str = "uploads"
    oss_sign_expires: int = 3600


settings = Settings()

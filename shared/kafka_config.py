from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Any, Dict, Optional


class KafkaConfigError(RuntimeError):
    """Raised when required Kafka environment configuration is missing."""


@dataclass(frozen=True)
class KafkaSecurity:
    protocol: str  # "ssl" | "sasl_ssl"
    ca_location: Optional[str] = None
    cert_location: Optional[str] = None
    key_location: Optional[str] = None
    sasl_mechanism: Optional[str] = None
    sasl_username: Optional[str] = None
    sasl_password: Optional[str] = None


def _env(name: str, default: Optional[str] = None) -> Optional[str]:
    val = os.getenv(name, default)
    if val is None:
        return None
    val = val.strip()
    return val if val else None


def load_security_from_env() -> KafkaSecurity:
    protocol = (_env("KAFKA_SECURITY_PROTOCOL", "ssl") or "ssl").lower()

    ca = _env("KAFKA_SSL_CA_LOCATION")
    cert = _env("KAFKA_SSL_CERT_LOCATION")
    key = _env("KAFKA_SSL_KEY_LOCATION")

    mech = _env("KAFKA_SASL_MECHANISM", "SCRAM-SHA-256")
    user = _env("KAFKA_SASL_USERNAME")
    pwd = _env("KAFKA_SASL_PASSWORD")

    return KafkaSecurity(
        protocol=protocol,
        ca_location=ca,
        cert_location=cert,
        key_location=key,
        sasl_mechanism=mech,
        sasl_username=user,
        sasl_password=pwd,
    )


def build_kafka_conf(*, base: Dict[str, Any]) -> Dict[str, Any]:
    """
    Build confluent-kafka (librdkafka) client configuration using env vars.

    Required ENV:
      - BOOTSTRAP_SERVERS

    For SSL (mTLS) mode:
      - KAFKA_SECURITY_PROTOCOL=ssl
      - KAFKA_SSL_CA_LOCATION
      - KAFKA_SSL_CERT_LOCATION
      - KAFKA_SSL_KEY_LOCATION

    For SASL_SSL mode:
      - KAFKA_SECURITY_PROTOCOL=sasl_ssl
      - KAFKA_SSL_CA_LOCATION
      - KAFKA_SASL_MECHANISM (default SCRAM-SHA-256)
      - KAFKA_SASL_USERNAME
      - KAFKA_SASL_PASSWORD
    """
    bootstrap = _env("BOOTSTRAP_SERVERS")
    if not bootstrap:
        raise KafkaConfigError("Missing BOOTSTRAP_SERVERS")

    sec = load_security_from_env()
    conf: Dict[str, Any] = dict(base)
    conf["bootstrap.servers"] = bootstrap

    debug = _env("KAFKA_DEBUG")
    if debug:
        conf["debug"] = debug

    if sec.protocol == "ssl":
        if not (sec.ca_location and sec.cert_location and sec.key_location):
            raise KafkaConfigError(
                "SSL mode requires KAFKA_SSL_CA_LOCATION, KAFKA_SSL_CERT_LOCATION, KAFKA_SSL_KEY_LOCATION"
            )
        conf["security.protocol"] = "ssl"
        conf["ssl.ca.location"] = sec.ca_location
        conf["ssl.certificate.location"] = sec.cert_location
        conf["ssl.key.location"] = sec.key_location
        return conf

    if sec.protocol in ("sasl_ssl", "sasl+ssl", "saslssl"):
        if not sec.ca_location:
            raise KafkaConfigError("SASL_SSL mode requires KAFKA_SSL_CA_LOCATION")
        if not (sec.sasl_username and sec.sasl_password):
            raise KafkaConfigError("SASL_SSL mode requires KAFKA_SASL_USERNAME and KAFKA_SASL_PASSWORD")

        conf["security.protocol"] = "sasl_ssl"
        conf["ssl.ca.location"] = sec.ca_location
        conf["sasl.mechanism"] = sec.sasl_mechanism or "SCRAM-SHA-256"
        conf["sasl.username"] = sec.sasl_username
        conf["sasl.password"] = sec.sasl_password
        return conf

    raise KafkaConfigError(f"Unsupported KAFKA_SECURITY_PROTOCOL={sec.protocol!r}")

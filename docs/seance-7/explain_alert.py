"""Explique des alertes de fraude : charge le contexte, appelle le modèle, valide le JSON.

python3 tools/llm/explain_alert.py --url https://team1-llm-xxxx.run.app
python3 tools/llm/explain_alert.py --url http://localhost:8080 --limit 2

Nécessite `pip install openai`. `gcloud` doit être installé et authentifié (ou `TOKEN` défini)
pour une URL Cloud Run.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

import llmclient
from openai import AuthenticationError, OpenAI, PermissionDeniedError

from opentelemetry import trace
from opentelemetry.exporter.cloud_trace import CloudTraceSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

provider = TracerProvider()
provider.add_span_processor(BatchSpanProcessor(CloudTraceSpanExporter(project_id="advanced-cloud-ai")))
trace.set_tracer_provider(provider)
tracer = trace.get_tracer("explain-alert")

PROMPT_VERSION = "explain-v1"
ACTIONS = ("block", "review", "allow")
SYSTEM_PROMPT = (
    "Tu es analyste fraude dans une banque. On te donne une alerte : une transaction dont le score "
    "du modèle dépasse le seuil, avec ses features. Réponds uniquement par un objet JSON à trois "
    'clés : "explanation" (explication en français, trois phrases au plus), "risk_factors" '
    "(liste des noms de features qui expliquent l'alerte, choisis parmi les clés de `features`) et "
    '"recommended_action" (exactement "block", "review" ou "allow"). Un score élevé sur un '
    "montant ordinaire doit rester prudent. N'ajoute aucun texte hors du JSON."
)


def load_context(alert_id: str, path: Path) -> dict:
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        if line.strip():
            alert = json.loads(line)
            if alert["alert_id"] == alert_id:
                return alert
    raise KeyError(f"alerte introuvable : {alert_id}")


def build_messages(context: dict) -> list[dict]:
    return [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": json.dumps(context, ensure_ascii=False, indent=1)},
    ]


def validate(text: str) -> dict:
    body = text.strip()
    if body.startswith("```"):
        body = body.split("\n", 1)[1] if "\n" in body else ""
        body = body.rsplit("```", 1)[0]
    try:
        data = json.loads(body)
    except ValueError as exc:
        raise ValueError(f"JSON illisible : {exc}") from exc
    if not isinstance(data, dict):
        raise ValueError("l'objet JSON est attendu")
    if not isinstance(data.get("explanation"), str):
        raise ValueError("`explanation` doit être une chaîne")
    factors = data.get("risk_factors")
    if not isinstance(factors, list) or not all(isinstance(f, str) for f in factors):
        raise ValueError("`risk_factors` doit être une liste de chaînes")
    if data.get("recommended_action") not in ACTIONS:
        raise ValueError(f"`recommended_action` doit valoir l'une de {ACTIONS}")
    return data


def explain(alert_id: str, client: OpenAI, model: str, path: Path) -> dict:
    with tracer.start_as_current_span("explain_alert"):
        t0 = time.perf_counter()
        with tracer.start_as_current_span("load_context"):
            context = load_context(alert_id, path)
        t1 = time.perf_counter()
        with tracer.start_as_current_span(f"chat {model}") as span:
            response = client.chat.completions.create(
                model=model, messages=build_messages(context), max_tokens=200, temperature=0
            )
            span.set_attribute("gen_ai.operation.name", "chat")
            span.set_attribute("gen_ai.request.model", model)
            span.set_attribute("gen_ai.usage.input_tokens", response.usage.prompt_tokens)
            span.set_attribute("gen_ai.usage.output_tokens", response.usage.completion_tokens)
            span.set_attribute("app.prompt.version", PROMPT_VERSION)
        t2 = time.perf_counter()
        with tracer.start_as_current_span("validate_json"):
            result = validate(response.choices[0].message.content or "")
        t3 = time.perf_counter()
        usage = response.usage
        tokens_in = usage.prompt_tokens if usage else 0
        tokens_out = usage.completion_tokens if usage else 0
        print(
            f"{alert_id[:12]}  contexte {t1 - t0:.3f} s  modèle {t2 - t1:.2f} s  "
            f"validation {t3 - t2:.3f} s  tokens {tokens_in} -> {tokens_out}"
        )
        return result


def alert_ids(path: Path, limit: int) -> list[str]:
    lines = [ln for ln in Path(path).read_text(encoding="utf-8").splitlines() if ln.strip()]
    return [json.loads(ln)["alert_id"] for ln in lines[:limit]]


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    ap.add_argument("--url", required=True, help="URL du service LLM")
    ap.add_argument("--alerts", type=Path, default=Path(__file__).with_name("alerts.jsonl"))
    ap.add_argument("--limit", type=int, default=5, help="nombre d'alertes à expliquer")
    args = ap.parse_args(argv)

    try:
        token = llmclient.identity_token(args.url)
    except llmclient.LLMError as exc:
        print(f"erreur : {exc}", file=sys.stderr)
        return 2
    client = OpenAI(base_url=f"{args.url.rstrip('/')}/v1", api_key=token or "local")
    failures = 0
    try:
        model = next(iter(client.models.list())).id
        for alert_id in alert_ids(args.alerts, args.limit):
            try:
                result = explain(alert_id, client, model, args.alerts)
            except ValueError as exc:
                failures += 1
                print(f"{alert_id[:12]}  réponse invalide : {exc}", file=sys.stderr)
                continue
            print(json.dumps(result, ensure_ascii=False))
    except (AuthenticationError, PermissionDeniedError):
        print(llmclient.AUTH_MESSAGE, file=sys.stderr)
        return 2
    provider.shutdown()
    return 0 if failures < args.limit else 1


if __name__ == "__main__":
    sys.exit(main())

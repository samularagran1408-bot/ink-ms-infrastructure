#!/usr/bin/env python3
"""Bloquea MCP de Figma/Notion/Datadog y subagentes extra en este repo."""
import json
import sys

BLOCKED_MCP = ("figma", "notion", "datadog")
BLOCKED_SUBAGENTS = (
    "best-of-n-runner",
    "bugbot",
    "security-review",
    "generalPurpose",
    "explore",
)


def deny(agent_message: str, user_message: str | None = None) -> None:
    payload = {
        "permission": "deny",
        "agent_message": agent_message,
    }
    if user_message:
        payload["user_message"] = user_message
    print(json.dumps(payload, ensure_ascii=False))
    sys.exit(0)


def allow() -> None:
    print(json.dumps({"permission": "allow"}))
    sys.exit(0)


def blob(data: object) -> str:
    return json.dumps(data, ensure_ascii=False).lower()


def main() -> None:
    raw = sys.stdin.read()
    try:
        data = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        allow()

    text = blob(data)
    tool = str(
        data.get("tool_name")
        or data.get("tool")
        or data.get("toolName")
        or ""
    )
    namespace = str(
        data.get("namespace")
        or data.get("server")
        or data.get("mcp_server")
        or data.get("serverIdentifier")
        or ""
    )
    subagent = str(
        data.get("subagent_type")
        or data.get("subagentType")
        or data.get("agent_type")
        or ""
    )

    combined = f"{tool} {namespace} {subagent} {text}"

    if any(name in combined for name in BLOCKED_MCP):
        deny(
            "MCP de Figma/Notion/Datadog está filtrado en este repo. "
            "Sigue con Read/Grep/Shell. El usuario puede pedir explícitamente ese MCP."
        )

    if subagent in BLOCKED_SUBAGENTS or (
        tool == "Task" and any(name in combined for name in BLOCKED_SUBAGENTS)
    ):
        deny(
            "No lances subagentes en este repo salvo que el usuario lo pida. "
            "Resuelve la tarea en este mismo agente."
        )

    allow()


if __name__ == "__main__":
    main()

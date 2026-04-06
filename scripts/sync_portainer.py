#!/usr/bin/env python3

import json
import sys
import os
from dotenv import load_dotenv
from typing import Any, Dict, Set

import requests
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

load_dotenv()

PORTAINER_URL = os.getenv("PORTAINER_URL")
PORTAINER_API_KEY = os.getenv("PORTAINER_API_KEY")

HEADERS = {
    "X-API-Key": PORTAINER_API_KEY
}


def load_hosts(path: str) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def get_existing_environments() -> Set[str]:
    response = requests.get(
        f"{PORTAINER_URL}/api/endpoints",
        headers=HEADERS,
        verify=False,
        timeout=30,
    )

    if not response.ok:
        print("Failed to fetch existing environments:")
        print(response.text)
        response.raise_for_status()

    return {env["Name"] for env in response.json()}


def create_environment(name: str, ip: str) -> None:
    payload = {
        "Name": (None, name),
        "URL": (None, f"tcp://{ip}:9001"),
        "EndpointCreationType": (None, "2"),
        "TLS": (None, "true"),
        "TLSSkipVerify": (None, "true"),
        "TLSSkipClientVerify": (None, "true"),
        "PublicURL": (None, ip),
    }

    response = requests.post(
        f"{PORTAINER_URL}/api/endpoints",
        headers=HEADERS,
        files=payload,
        verify=False,
        timeout=30,
    )

    if not response.ok:
        print(f"Failed to create environment '{name}' ({response.status_code}):")
        print(response.text)
        response.raise_for_status()

    print(f"Created environment: {name} -> {ip}:9001 (Public: {ip})")


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: python3 scripts/sync_portainer.py <portainer_hosts.json>")
        return 1

    hosts = load_hosts(sys.argv[1])
    existing = get_existing_environments()

    for name, info in hosts.items():
        ip = str(info.get("ip", "")).strip()

        if not ip:
            print(f"Skipping {name}: empty IP")
            continue

        if name in existing:
            print(f"Already exists: {name}")
            continue

        create_environment(name, ip)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
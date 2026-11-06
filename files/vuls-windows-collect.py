#!/usr/bin/env python3
"""Collect Windows hosts into the Vuls results directory.

Vuls has no WinRM of its own and the Windows nodes have no SSH, so Windows goes
through `vuls server`: a POST carrying systeminfo.exe's output and a few
headers, answered with the same result JSON an SSH scan produces. This writes
that answer into the run's results directory, where it sits
beside every Linux host's result, in the same format.

Nothing here talks to the Windows node. Puppet renders what PuppetDB already
knows into the input file, and the two things PuppetDB does not carry, the
update build revision and the hotfix list, come from the vuls_windows fact.

**The product name is the whole game, and getting it wrong is silent.** Vuls's
detection criteria are keyed on it: `{"type":"kb","kb":{"product":"Windows
Server 2022","kb_id":"5012170"}}`. Post `X-Vuls-OS-Release: 2022`, which is
what PuppetDB's os.release.full holds, and Vuls answers HTTP 200 with a
well-formed result, a parsed build, and zero findings. Measured 2026-09-16:

    X-Vuls-OS-Release      applied KBs   CVEs
    2022                             3      0
    Server 2022                      3      0
    Windows Server 2022             89      9

So the applied-KB count is the canary. A correct match derives KBs from the
build; a wrong one echoes back exactly the hotfixes that were sent. Anything
that does not clear that bar is recorded as an error on the host rather than
published as a clean zero.
"""

import argparse
import json
import os
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request

SERVER_START_TIMEOUT = 120
POST_TIMEOUT = 300


def log(message):
    print(f"vuls-windows-collect: {message}", file=sys.stderr)


def vuls_product(host):
    """The product string Vuls's criteria are keyed on, or None.

    Server 2022 Standard Evaluation, Datacenter and the rest all detect as
    "Windows Server 2022"; the edition is not part of the key. A Core
    installation is its own product because Microsoft ships it its own KBs.
    """
    release = str(host.get("release_major") or "").strip()
    installation = str(host.get("installation_type") or "").strip()
    if not release:
        return None
    if not installation.lower().startswith("server"):
        # Client Windows keys on the display version ("Windows 11 Version 24H2")
        # rather than the release, and there is none on this estate to check it
        # against. Guessing it would be the same silent zero one layer along.
        return None
    product = f"Windows Server {release}"
    if installation.lower() == "server core":
        product += " (Server Core installation)"
    return product


def systeminfo(host, product):
    """The systeminfo.exe output Vuls parses, rebuilt from what PuppetDB holds.

    Only the lines Vuls reads are included. The Hotfix(s) block matters on its
    own: a standalone out-of-band update is not in the cumulative build chain,
    so the build number alone cannot say whether it is applied.
    """
    hotfixes = host.get("hotfixes") or []
    lines = [
        f"Host Name:                 {host['certname'].split('.')[0].upper()}",
        f"OS Name:                   Microsoft {host.get('product_name') or product}",
        f"OS Version:                {host['kernel_release']} N/A Build {host['kernel_release'].split('.')[-1]}",
        "OS Manufacturer:           Microsoft Corporation",
        f"OS Configuration:          {host.get('installation_type') or 'Standalone Server'}",
        "System Type:               x64-based PC",
        f"Hotfix(s):                 {len(hotfixes)} Hotfix(s) Installed.",
    ]
    lines += [f"                           [{i:02d}]: {kb}" for i, kb in enumerate(hotfixes, 1)]
    return "\n".join(lines) + "\n"


def wait_for(port, deadline):
    while time.time() < deadline:
        with socket.socket() as probe:
            probe.settimeout(2)
            if probe.connect_ex(("127.0.0.1", port)) == 0:
                return True
        time.sleep(1)
    return False


def post(port, host, product):
    body = systeminfo(host, product).encode()
    request = urllib.request.Request(
        f"http://127.0.0.1:{port}/vuls",
        data=body,
        headers={
            "Content-Type": "text/plain",
            "X-Vuls-OS-Family": "windows",
            "X-Vuls-OS-Release": product,
            "X-Vuls-Kernel-Version": f"{host['kernel_release']}.{host['ubr']}",
            "X-Vuls-Server-Name": host["certname"],
        },
    )
    with urllib.request.urlopen(request, timeout=POST_TIMEOUT) as response:
        return json.loads(response.read())


def check(result, host):
    """Return the errors this result should carry, empty when it looks sound."""
    applied = len((result.get("windowsKB") or {}).get("applied") or [])
    sent = len(host.get("hotfixes") or [])
    if applied > sent:
        return []
    return [
        f"Vuls matched no KBs beyond the {sent} hotfix(es) sent (applied={applied}), so the "
        f"product name {result.get('release')!r} did not match its detection data. Findings "
        "for this host are not trustworthy and are almost certainly an undercount."
    ]


def newest_results_dir(root):
    """This run's results directory, the newest run directory, which the scan and report just wrote.

    Safe because the unit runs scan, report, then this, stopping on failure: if
    the scan produced no directory the unit never reaches here.
    """
    dirs = [os.path.join(root, d) for d in os.listdir(root)]
    dirs = [d for d in dirs if os.path.isdir(d) and not os.path.islink(d)]
    return max(dirs, key=os.path.getmtime) if dirs else None


def collect(config, vuls_config, results_dir, port, vuls_bin):
    try:
        with open(config, encoding="utf-8") as handle:
            hosts = json.load(handle)
    except (OSError, ValueError) as err:
        log(f"cannot read {config}: {err}")
        return 1
    if not hosts:
        log("no Windows hosts to collect")
        return 0

    server = subprocess.Popen(
        [vuls_bin, "server", "-config", vuls_config,
         "-results-dir", results_dir, "-listen", f"127.0.0.1:{port}"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    written = 0
    try:
        if not wait_for(port, time.time() + SERVER_START_TIMEOUT):
            log(f"vuls server did not listen on 127.0.0.1:{port} within {SERVER_START_TIMEOUT}s")
            return 1
        for host in hosts:
            certname = host.get("certname", "?")
            product = vuls_product(host)
            if product is None:
                log(f"{certname}: no Vuls product name for "
                    f"{host.get('installation_type')!r} {host.get('release_major')!r}; skipped")
                continue
            try:
                result = post(port, host, product)
            except (urllib.error.URLError, ValueError, OSError) as err:
                log(f"{certname}: POST failed: {err}")
                continue
            result = result[0] if isinstance(result, list) else result

            # Server mode is never told the address, so the result comes back
            # with no ipv4Addrs, and anything downstream that keys a host on
            # its address gets an empty one. PuppetDB knows the address and it
            # is already in this file.
            if host.get("ipaddress") and not result.get("ipv4Addrs"):
                result["ipv4Addrs"] = [host["ipaddress"]]

            problems = check(result, host)
            if problems:
                log(f"{certname}: {problems[0]}")
            result["errors"] = list(result.get("errors") or []) + problems

            path = os.path.join(results_dir, f"{certname}.json")
            tmp = f"{path}.tmp"
            with open(tmp, "w", encoding="utf-8") as handle:
                json.dump(result, handle)
            os.replace(tmp, path)
            written += 1
            cves = len(result.get("scannedCves") or {})
            applied = len((result.get("windowsKB") or {}).get("applied") or [])
            log(f"{certname}: {cves} CVEs, {applied} KBs applied, product {product!r}")
    finally:
        server.terminate()
        try:
            server.wait(timeout=30)
        except subprocess.TimeoutExpired:
            server.kill()

    log(f"{written} of {len(hosts)} Windows host(s) written to {results_dir}")
    return 0 if written else 1


def main():
    parser = argparse.ArgumentParser(description="Collect Windows hosts into a Vuls results directory.")
    parser.add_argument("--config", default="/etc/vuls/windows.json")
    parser.add_argument("--vuls-config", default="/etc/vuls/config.toml")
    parser.add_argument("--results-dir", default="/var/lib/vuls/results")
    parser.add_argument("--vuls", default="/usr/local/bin/vuls")
    parser.add_argument("--port", type=int, default=5515)
    args = parser.parse_args()

    if not os.path.isdir(args.results_dir):
        log(f"results directory {args.results_dir} does not exist")
        return 1
    run = newest_results_dir(args.results_dir)
    if run is None:
        log(f"no result directories under {args.results_dir}")
        return 1
    return collect(args.config, args.vuls_config, run, args.port, args.vuls)


if __name__ == "__main__":
    sys.exit(main())

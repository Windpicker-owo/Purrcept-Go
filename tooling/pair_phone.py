# /// script
# requires-python = ">=3.11"
# dependencies = ["qrcode==8.2"]
# ///
"""Display Engine's existing short-lived phone invitation as a local QR code.

Run with ``uv run tooling/pair_phone.py``. This tool only reads the invitation file;
Engine still owns invitation creation, expiry and consumption. A loopback-only page
uses an unguessable path, no access logs, no external assets and no cached responses.
QR bytes remain in memory rather than leaving a second invitation artifact on disk.
The browser polls for file changes so expired or consumed invitations leave the page.
"""

import argparse
import html
import json
import math
import re
import secrets
import time
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

import qrcode
import qrcode.exceptions
import qrcode.image.svg


def invitation_fragment(path: Path, now: float) -> str:
    """Read at most one bounded invitation and render it without disclosing parsing failures.

    The PC clock is only a presentation gate; Engine's monotonic deadline remains
    authoritative. Unlinking/replacing the source updates the next page poll.
    """
    try:
        with path.open("rb") as source:
            raw = source.read(4097)
        if len(raw) > 4096:
            raise ValueError("oversized")
        value = json.loads(raw)
        if (
            not isinstance(value, dict)
            or type(value.get("v")) is not int
            or value["v"] != 1
        ):
            raise ValueError("unsupported")
        address = value["url"]
        fingerprint = value["certificate_sha256"]
        invitation = value["invitation"]
        expiry = value["expires_at"]
        if not isinstance(address, str):
            raise TypeError("address")
        url = urlsplit(address)
        if (
            url.scheme != "https"
            or not url.hostname
            or url.username
            or url.password
            or url.path not in ("", "/")
            or url.query
            or url.fragment
        ):
            raise ValueError("address")
        if not isinstance(fingerprint, str) or not re.fullmatch(
            r"[a-fA-F0-9]{64}", fingerprint
        ):
            raise ValueError("fingerprint")
        if not isinstance(invitation, str) or not re.fullmatch(
            r"[A-Za-z0-9_-]{16,256}", invitation
        ):
            raise ValueError("invitation")
        if type(expiry) not in (int, float) or not math.isfinite(expiry) or expiry <= 0:
            raise ValueError("expiry")
        if expiry <= now:
            return "<p>邀请已过期。请在电脑重新开启 Phone 配对窗口。</p><p>Invitation expired. Reopen pairing in Engine.</p>"

        # A fixed compact payload keeps the QR stable between polls. Only public invitation fields
        # are encoded; unrelated local-file fields cannot accidentally become part of the QR.
        payload = {
            key: value[key]
            for key in ("v", "url", "certificate_sha256", "invitation", "expires_at")
        }
        qr = qrcode.QRCode(border=4, error_correction=qrcode.constants.ERROR_CORRECT_M)
        qr.add_data(json.dumps(payload, ensure_ascii=True, separators=(",", ":")))
        qr.make(fit=True)
        svg = qr.make_image(image_factory=qrcode.image.svg.SvgPathFillImage).to_string(
            encoding="unicode"
        )
        return (
            f"<h2>{html.escape(address)}</h2>{svg}"
            "<p>手机点击「扫码配对」，核对电脑后连接。<br>Tap Scan to pair on your phone, then confirm this computer.</p>"
            f"<p>证书指纹 / Certificate fingerprint<br><code>{fingerprint.upper()}</code></p>"
            "<p>短时邀请，请勿分享二维码。 / Keep this short-lived QR private.</p>"
        )
    except FileNotFoundError:
        return "<p>等待 Engine 配对邀请。请先启动 Engine 并开启 Phone 配对。</p><p>Waiting for an Engine invitation; a consumed invitation also disappears here.</p>"
    except (
        OSError,
        ValueError,
        KeyError,
        TypeError,
        qrcode.exceptions.DataOverflowError,
    ):
        # Never include raw JSON or exception text: the local source contains a pairing secret.
        return "<p>无法读取有效邀请，请检查 Engine 的邀请文件设置。</p><p>Cannot read a valid invitation. Check Engine's invitation-file setting.</p>"


def make_server(path: Path) -> tuple[ThreadingHTTPServer, str]:
    """Bind a fresh loopback port and capability path; callers own serve_forever/server_close.

    Browsers may only fetch the exact capability routes with the expected loopback
    Host. Access logging is disabled because request paths grant access to the QR.
    """
    prefix = "/" + secrets.token_urlsafe(24) + "/"

    class Display(BaseHTTPRequestHandler):
        def log_message(self, format: str, *args: object) -> None:
            """Do not retain capability paths in HTTP access or error logs."""

        def do_GET(self) -> None:
            """Serve the in-memory page or current invitation fragment without caching."""
            host, port = self.server.server_address[:2]
            if self.headers.get("Host") != f"{host}:{port}":
                self.send_error(403)
                return
            if self.path == prefix:
                body = f"""<!doctype html><html lang="zh"><meta charset="utf-8">
<meta name="referrer" content="no-referrer"><title>Purrcept · 手机配对</title>
<style>body{{font:16px system-ui;margin:32px auto;padding:0 24px;max-width:650px;text-align:center;color:#15171a;background:#f2f4f7}}
svg{{display:block;width:100%;max-width:520px;height:auto;margin:auto}}code{{overflow-wrap:anywhere}}p{{line-height:1.6}}</style>
<h1>Purrcept · 手机配对</h1><main id="invitation">正在读取邀请… / Loading invitation…</main>
<script src="{prefix}app.js"></script></html>"""
                content_type = "text/html; charset=utf-8"
            elif self.path == prefix + "state":
                body = invitation_fragment(path, time.time())
                content_type = "text/html; charset=utf-8"
            elif self.path == prefix + "app.js":
                # Clear a previous QR on read failure; stale secrets must not linger after expiry.
                body = """const target = document.getElementById('invitation'); let previous = '';
async function update() {
  try { const r = await fetch('state', {cache:'no-store'});
    if (!r.ok) throw new Error();
    const next = await r.text(); if (previous !== next) { target.innerHTML = next; previous = next; }
  } catch { previous = ''; target.textContent = '连接已关闭，请重新打开配对工具。 / Pairing display disconnected.'; }
  setTimeout(update, 1000);
} update();"""
                content_type = "application/javascript; charset=utf-8"
            else:
                self.send_error(404)
                return
            encoded = body.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(encoded)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("Referrer-Policy", "no-referrer")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header(
                "Content-Security-Policy",
                "default-src 'none'; script-src 'self'; connect-src 'self'; style-src 'unsafe-inline'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'",
            )
            self.end_headers()
            self.wfile.write(encoded)

    server = ThreadingHTTPServer(("127.0.0.1", 0), Display)
    return server, prefix


def main() -> None:
    """Open the local display until Ctrl+C, without starting Engine or changing its pairing state."""
    parser = argparse.ArgumentParser(description="在电脑显示 Purrcept 手机配对二维码。")
    parser.add_argument(
        "--invitation",
        type=Path,
        default=Path(__file__).resolve().parents[2]
        / "purrcept_engine/.purrcept/phone-invitation.json",
    )
    args = parser.parse_args()
    server, prefix = make_server(args.invitation.resolve())
    try:
        url = f"http://127.0.0.1:{server.server_port}{prefix}"
        if not webbrowser.open(url):
            raise SystemExit("浏览器未能打开，请设置默认浏览器后重试。")
        print("配对窗口已打开。请保持本工具运行，手机扫描二维码；关闭时按 Ctrl+C。")
        server.serve_forever(poll_interval=0.25)
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()

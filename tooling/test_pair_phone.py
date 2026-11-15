"""Exercise local QR presentation, invitation lifetime and loopback HTTP boundaries with fake secrets."""

import http.client
import json
import tempfile
import threading
import time
import unittest
from pathlib import Path
from unittest.mock import patch

import qrcode
from pair_phone import invitation_fragment, make_server


class PairPhoneTests(unittest.TestCase):
    """No real invitation, device, Engine state or external network is used."""

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / "invitation.json"
        self.value = {
            "v": 1,
            "url": "https://192.0.2.1:8766",
            "certificate_sha256": "ab" * 32,
            "invitation": "fake_invitation_for_test_only",
            "expires_at": time.time() + 120,
        }
        self.path.write_text(json.dumps(self.value), encoding="utf-8")

    def test_qr_uses_only_public_invitation_fields(self):
        self.value["token"] = "unrelated-secret-must-not-be-encoded"
        self.path.write_text(json.dumps(self.value), encoding="utf-8")
        original = qrcode.QRCode.add_data
        with patch.object(
            qrcode.QRCode, "add_data", autospec=True, side_effect=original
        ) as add_data:
            body = invitation_fragment(self.path, time.time())
        self.assertIn("<svg", body)
        self.assertIn(self.value["url"], body)
        self.assertIn(self.value["certificate_sha256"].upper(), body)
        self.assertNotIn(self.value["invitation"], body)
        self.assertNotIn(self.value["token"], body)
        self.assertEqual(add_data.call_count, 1)
        encoded = json.loads(add_data.call_args.args[1])
        self.assertNotIn("token", encoded)
        self.assertEqual(encoded["invitation"], self.value["invitation"])

    def test_expired_missing_and_consumed_files_remove_qr(self):
        self.assertIn("<svg", invitation_fragment(self.path, time.time()))
        expired = invitation_fragment(self.path, self.value["expires_at"] + 1)
        self.assertNotIn("<svg", expired)
        self.assertIn("expired", expired)
        self.path.unlink()
        self.assertNotIn("<svg", invitation_fragment(self.path, time.time()))

    def test_invalid_invitation_never_echoes_secret_or_exception(self):
        for changed in (
            {"v": 2},
            {"url": "http://example.com"},
            {"certificate_sha256": "oops"},
            {"expires_at": False},
            {"invitation": "short"},
        ):
            self.path.write_text(json.dumps(self.value | changed), encoding="utf-8")
            body = invitation_fragment(self.path, time.time())
            self.assertNotIn("<svg", body)
            self.assertNotIn(self.value["invitation"], body)
        self.path.write_text('{"secret":"do-not-echo"', encoding="utf-8")
        self.assertNotIn("do-not-echo", invitation_fragment(self.path, time.time()))

    def test_live_server_has_no_cache_or_public_route_and_reloads_source(self):
        server, prefix = make_server(self.path)
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()
        client = http.client.HTTPConnection("127.0.0.1", server.server_port, timeout=3)
        try:
            self.assertEqual(server.server_address[0], "127.0.0.1")
            client.request("GET", prefix + "state")
            reply = client.getresponse()
            self.assertEqual(reply.status, 200)
            self.assertEqual(reply.getheader("Cache-Control"), "no-store")
            self.assertEqual(reply.getheader("Referrer-Policy"), "no-referrer")
            self.assertIn(b"<svg", reply.read())
            self.path.unlink()
            client.request("GET", prefix + "state")
            self.assertNotIn(b"<svg", client.getresponse().read())
            client.request("GET", "/")
            self.assertEqual(client.getresponse().status, 404)
            client.close()
            client = http.client.HTTPConnection(
                "127.0.0.1", server.server_port, timeout=3
            )
            client.request("GET", prefix, headers={"Host": "attacker.example"})
            self.assertEqual(client.getresponse().status, 403)
        finally:
            client.close()
            server.shutdown()
            server.server_close()
            worker.join(timeout=3)


if __name__ == "__main__":
    unittest.main()

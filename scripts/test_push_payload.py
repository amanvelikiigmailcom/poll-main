"""Exercise the actual Foundation-only APNs decoder without building the app."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PushPayloadTest(unittest.TestCase):
    def test_native_payload_projection(self):
        source = (ROOT / 'app/ios/Runner/PushTapBridge.swift').read_text()
        decoder = 'enum PushTapPayload {' + source.split('enum PushTapPayload {', 1)[1]
        assertions = r'''
let expected = ["type": "friend_request", "recipientId": "owner", "eventId": "event-1", "actorId": "friend"]
assert(PushTapPayload.decode(expected) == expected)
assert(PushTapPayload.decode(["data": expected]) == expected)
assert(PushTapPayload.decode(["data": "{\"type\":\"vote_received\",\"recipientId\":\"owner\"}"]) == ["type": "vote_received", "recipientId": "owner"])
assert(PushTapPayload.decode(["type": " vote_received "]) == ["type": "vote_received"])
assert(PushTapPayload.decode(["aps": ["alert": "plain notification"]]) == nil)
assert(PushTapPayload.decode(["type": "friend_request", "recipientId": 42]) == nil)
assert(PushTapPayload.decode(["type": "friend_request", "recipientId": ""]) == nil)
assert(PushTapPayload.decode(["type": "friend_request", "actorId": "bad?id"]) == nil)
assert(PushTapPayload.decode(["type": "friend_request", "recipientId": "owner\n"]) == nil)
assert(PushTapPayload.decode(["data": "broken-json"]) == nil)
assert(PushTapPayload.decode(["type": ""]) == nil)
assert(PushTapPayload.decode(["type": "vote_received", "voterId": "PRIVATE", "phone": "PRIVATE"]) == ["type": "vote_received"])
'''
        with tempfile.TemporaryDirectory(prefix='flyprox-push-decoder-') as folder:
            script = Path(folder) / 'main.swift'
            script.write_text('import Foundation\n' + decoder + assertions)
            result = subprocess.run(['xcrun', 'swift', str(script)], capture_output=True, text=True, timeout=90)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()

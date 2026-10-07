import http.client
import json
import threading
import unittest
from hypothesis import given, settings, strategies as st
from urllib.parse import quote
from src.greeting import create_server


class HttpContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = create_server()
        cls.thread = threading.Thread(target=cls.server.serve_forever)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()

    def request(self, path, method="GET"):
        conn = http.client.HTTPConnection(*self.server.server_address, timeout=5)
        try:
            conn.request(method, path)
            response = conn.getresponse()
            self.assertTrue(response.getheader("Content-Type").startswith("application/json"))
            return response.status, json.loads(response.read())
        finally:
            conn.close()

    def test_success(self):
        for name, expected in [("Ada", "Ada"), ("  Ada Lovelace  ", "Ada Lovelace"), ('A"B', 'A"B'), ("Zoë", "Zoë")]:
            with self.subTest(name=name):
                self.assertEqual(self.request("/greet?name=" + quote(name)),
                                 (200, {"greeting": "Hello, " + expected + "!"}))

    def test_rejection_and_routing(self):
        for query in ["", "?name=", "?name=%20%20"]:
            self.assertEqual(self.request("/greet" + query),
                             (400, {"error": "A nonempty name is required"}))
        for path, method in [("/other", "GET"), ("/greet?name=Ada", "POST")]:
            self.assertEqual(self.request(path, method), (404, {"error": "Not found"}))

    @settings(max_examples=100, deadline=None)
    @given(
        middle=st.text(alphabet='aZ0 \t\r\n\0"\\&+%/éλ界😀', max_size=64),
        left=st.text(alphabet=" \t\r\n", max_size=12),
        right=st.text(alphabet=" \t\r\n", max_size=12),
        suffix=st.text(alphabet="ab09", max_size=32),
        method=st.sampled_from(["POST", "PUT", "DELETE", "PATCH", "OPTIONS"]),
    )
    def test_generated_http_contract(self, middle, left, right, suffix, method):
        # The expected core is constructed before padding, independently of strip.
        core = "A" + middle + "Z"
        self.assertEqual(
            self.request("/greet?name=" + quote(left + core + right, safe="")),
            (200, {"greeting": "Hello, " + core + "!"}),
        )
        self.assertEqual(
            self.request("/greet?name=" + quote(left, safe="")),
            (400, {"error": "A nonempty name is required"}),
        )
        self.assertEqual(
            self.request("/missing-" + suffix + "?name=Ada"),
            (404, {"error": "Not found"}),
        )
        self.assertEqual(
            self.request("/greet?name=Ada", method),
            (404, {"error": "Not found"}),
        )

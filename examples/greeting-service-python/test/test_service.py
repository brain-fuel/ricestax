import http.client
import json
import threading
import unittest
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
        for name in ["Ada", "  Ada Lovelace  ", 'A"B', "Zoë"]:
            with self.subTest(name=name):
                self.assertEqual(self.request("/greet?name=" + quote(name)),
                                 (200, {"greeting": "Hello, " + name.strip() + "!"}))

    def test_rejection_and_routing(self):
        for query in ["", "?name=", "?name=%20%20"]:
            self.assertEqual(self.request("/greet" + query),
                             (400, {"error": "A nonempty name is required"}))
        for path, method in [("/other", "GET"), ("/greet?name=Ada", "POST")]:
            self.assertEqual(self.request(path, method), (404, {"error": "Not found"}))

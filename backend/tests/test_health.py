import unittest
from unittest.mock import patch, AsyncMock
from starlette.testclient import TestClient
from app.main import app


class TestHealthEndpoint(unittest.TestCase):
    @patch("app.main.init_db", new_callable=AsyncMock)
    @patch("app.main.init_redis", new_callable=AsyncMock)
    @patch("app.main.close_db", new_callable=AsyncMock)
    @patch("app.main.close_redis", new_callable=AsyncMock)
    def test_health_check_returns_ok(self, mock_close_redis, mock_close_db, mock_init_redis, mock_init_db):
        with TestClient(app) as client:
            response = client.get("/health")
            self.assertEqual(response.status_code, 200)
            data = response.json()
            self.assertEqual(data["status"], "healthy")
            self.assertIn("version", data)
            self.assertIn("environment", data)


if __name__ == "__main__":
    unittest.main()


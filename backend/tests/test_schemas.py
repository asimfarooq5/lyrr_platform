import unittest
from app.schemas.auth import UserCreate, LoginRequest, TokenResponse, DeviceInfo
from app.schemas.book import BookCreate
from app.schemas.sync import SyncPushRequest


class TestSchemas(unittest.TestCase):
    def test_user_create_validation(self):
        user_data = {
            "email": "reader@example.com",
            "password": "Password123!",
            "phone": "+237690000000",
        }
        user = UserCreate(**user_data)
        self.assertEqual(user.email, "reader@example.com")
        self.assertEqual(user.phone, "+237690000000")

    def test_user_login_validation(self):
        login_data = {
            "username": "reader@example.com",
            "password": "Password123!",
            "device_info": {"device_name": "iPhone 15", "device_type": "ios"},
        }
        login = LoginRequest(**login_data)
        self.assertEqual(login.username, "reader@example.com")
        self.assertIsNotNone(login.device_info)
        self.assertEqual(login.device_info.device_type, "ios")

    def test_token_response_schema(self):
        token_data = {
            "access_token": "token_abc_123",
            "refresh_token": "refresh_xyz_456",
            "token_type": "bearer",
            "expires_in": 3600,
        }
        token = TokenResponse(**token_data)
        self.assertEqual(token.access_token, "token_abc_123")
        self.assertEqual(token.token_type, "bearer")

    def test_book_create_schema(self):
        book_data = {
            "title": "A Tale of Two Cities",
            "author": "Charles Dickens",
            "description": "Historical novel",
            "language": "en",
        }
        book = BookCreate(**book_data)
        self.assertEqual(book.title, "A Tale of Two Cities")
        self.assertEqual(book.language, "en")

    def test_sync_push_schema(self):
        sync_data = {
            "device_id": "device_ios_001",
            "items": [],
        }
        sync_req = SyncPushRequest(**sync_data)
        self.assertEqual(len(sync_req.items), 0)
        self.assertEqual(sync_req.device_id, "device_ios_001")


if __name__ == "__main__":
    unittest.main()


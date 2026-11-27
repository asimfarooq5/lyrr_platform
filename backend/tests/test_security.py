import unittest
from app.core.security import (
    get_password_hash,
    verify_password,
    create_access_token,
    create_refresh_token,
    decode_token,
)


class TestSecurity(unittest.TestCase):
    def test_password_hashing_and_verification(self):
        password = "SecurePassword123!@#"
        hashed = get_password_hash(password)
        
        self.assertNotEqual(password, hashed)
        self.assertTrue(verify_password(password, hashed))
        self.assertFalse(verify_password("WrongPassword123", hashed))

    def test_access_token_creation_and_payload(self):
        token_data = {"sub": "user_abc_123", "role": "reader"}
        token = create_access_token(token_data)
        
        self.assertIsInstance(token, str)
        payload = decode_token(token)
        self.assertIsNotNone(payload)
        self.assertEqual(payload["sub"], "user_abc_123")
        self.assertEqual(payload["role"], "reader")
        self.assertIn("exp", payload)

    def test_refresh_token_creation_and_payload(self):
        token_data = {"sub": "user_xyz_789"}
        token = create_refresh_token(token_data)
        
        self.assertIsInstance(token, str)
        payload = decode_token(token)
        self.assertIsNotNone(payload)
        self.assertEqual(payload["sub"], "user_xyz_789")
        self.assertEqual(payload["type"], "refresh")


if __name__ == "__main__":
    unittest.main()

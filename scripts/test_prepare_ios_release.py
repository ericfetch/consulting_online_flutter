import unittest

from prepare_ios_release import next_build_number, verify_app


class ReleaseVersionTests(unittest.TestCase):
    def test_existing_build_numbers_increase(self):
        for previous, expected in [
            ("42", "43"), ("1.2", "1.3"), ("1.2.99", "1.3.0"),
            ("1.99.99", "2.0.0"), ("9999", "9999.1"),
            ("9999.99", "9999.99.1"),
        ]:
            with self.subTest(previous=previous):
                self.assertEqual(next_build_number(previous), expected)

    def test_does_not_reuse_android_build_or_mask_failed_lookup(self):
        for invalid in ["2026092901", "", "null", "None", "0", "1.100", "1.2.3.4", "9999.99.99"]:
            with self.subTest(invalid=invalid):
                with self.assertRaises(ValueError):
                    next_build_number(invalid)

    def test_existing_app_must_match(self):
        app = {"id": "6808095729", "attributes": {"bundleId": "com.consulting.consultingOnlineApp"}}
        verify_app(app, "6808095729", "com.consulting.consultingOnlineApp")
        verify_app({"data": app}, "6808095729", "com.consulting.consultingOnlineApp")
        with self.assertRaises(ValueError):
            verify_app(app, "6808095729", "com.other.app")
        with self.assertRaises(ValueError):
            verify_app(app, "123", "com.consulting.consultingOnlineApp")


if __name__ == "__main__":
    unittest.main()

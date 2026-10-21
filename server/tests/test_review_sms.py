from __future__ import annotations

import unittest

from app.config import settings
from app.integrations import review_sms_accepted


class ReviewSmsTest(unittest.TestCase):
    def setUp(self) -> None:
        self.phones = settings.mp_review_phones
        self.code = settings.mp_review_code
        settings.mp_review_phones = "13800001001,13600001111"
        settings.mp_review_code = "123456"

    def tearDown(self) -> None:
        settings.mp_review_phones = self.phones
        settings.mp_review_code = self.code

    def test_only_listed_phones_accept_fixed_code(self) -> None:
        self.assertTrue(review_sms_accepted("13800001001", "123456"))
        self.assertTrue(review_sms_accepted("13600001111", "123456"))
        self.assertFalse(review_sms_accepted("13800138000", "123456"))
        self.assertFalse(review_sms_accepted("13800001001", "000000"))

    def test_blank_code_disables_bypass(self) -> None:
        settings.mp_review_code = ""
        self.assertFalse(review_sms_accepted("13800001001", "123456"))

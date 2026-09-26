import unittest
from unittest.mock import AsyncMock, patch

from app.assistant import (
    MAX_QUESTION_CHARS,
    _extract_answer,
    generate_answer,
    offline_answer,
    safety_answer,
    validate_question,
)


class AssistantSafetyTests(unittest.TestCase):
    def test_rejects_empty_and_oversized_questions(self) -> None:
        with self.assertRaisesRegex(ValueError, "too short"):
            validate_question("  ")
        with self.assertRaisesRegex(ValueError, "too long"):
            validate_question("س" * (MAX_QUESTION_CHARS + 1))

    def test_removes_control_characters_without_logging_question(self) -> None:
        self.assertEqual(validate_question("ما معنى\nالنوم الآمن؟"), "ما معنى النوم الآمن؟")

    def test_emergency_question_is_answered_without_model(self) -> None:
        answer = safety_answer("طفلي مش بيتنفس، أعمل إيه؟")
        self.assertIsNotNone(answer)
        self.assertIn("الطوارئ", answer)

    def test_medication_question_does_not_get_a_dose(self) -> None:
        answer = safety_answer("ما جرعة الدواء لحديث الولادة؟")
        self.assertIsNotNone(answer)
        self.assertIn("لا أستطيع تحديد جرعة", answer)

    def test_extracts_string_and_multimodal_provider_content(self) -> None:
        self.assertEqual(
            _extract_answer(
                {"choices": [{"message": {"content": "  إجابة مختصرة  "}}]}
            ),
            "إجابة مختصرة",
        )
        self.assertEqual(
            _extract_answer(
                {
                    "choices": [
                        {
                            "message": {
                                "content": [
                                    {"type": "text", "text": "جزء أول"},
                                    {"type": "text", "text": " وجزء ثانٍ"},
                                ]
                            }
                        }
                    ]
                }
            ),
            "جزء أول وجزء ثانٍ",
        )

    def test_offline_fallback_answers_common_newborn_question(self) -> None:
        answer = offline_answer("كيف أجهز مكان نوم آمن؟")
        self.assertIn("على ظهره", answer)
        self.assertIn("وسائد", answer)

    def test_offline_fallback_matches_attached_arabic_sleep_prefix(self) -> None:
        answer = offline_answer("ما النصائح الآمنة لنوم حديث الولادة؟")
        self.assertIn("إرشادات النوم الآمن", answer)

    def test_offline_fallback_stays_conservative_for_unknown_question(self) -> None:
        answer = offline_answer("هل هذا طبيعي؟")
        self.assertIn("الرد الإرشادي", answer)
        self.assertIn("لا أستطيع التشخيص", answer)


class AssistantProviderFallbackTests(unittest.IsolatedAsyncioTestCase):
    async def test_provider_quota_returns_a_complete_local_answer(self) -> None:
        class FakeResponse:
            status_code = 429

        with patch("app.assistant.provider_is_configured", return_value=True):
            with patch(
                "app.assistant.AI_API_URL",
                "https://example.test/v1/chat/completions",
            ):
                with patch(
                    "app.assistant._provider_response",
                    new=AsyncMock(return_value=FakeResponse()),
                ):
                    answer = await generate_answer("كيف أجهز مكان نوم آمن؟")

        self.assertIn("إرشادات النوم الآمن", answer)
        self.assertIn("على ظهره", answer)


if __name__ == "__main__":
    unittest.main()

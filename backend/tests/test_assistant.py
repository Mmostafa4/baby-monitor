import unittest

from app.assistant import (
    MAX_QUESTION_CHARS,
    _extract_answer,
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

    def test_offline_fallback_stays_conservative_for_unknown_question(self) -> None:
        answer = offline_answer("هل هذا طبيعي؟")
        self.assertIn("إرشادات عامة محدودة", answer)
        self.assertIn("لا أستطيع التشخيص", answer)


if __name__ == "__main__":
    unittest.main()

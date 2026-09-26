from __future__ import annotations

import os
import re
from typing import Any
from urllib.parse import urlparse


MAX_QUESTION_CHARS = 900
MAX_ANSWER_CHARS = 6_000

AI_API_URL = os.getenv("BABY_MONITOR_AI_API_URL", "").strip()
AI_API_KEY = os.getenv("BABY_MONITOR_AI_API_KEY", "").strip()
AI_MODEL = os.getenv("BABY_MONITOR_AI_MODEL", "").strip()

# The local fallback keeps the beta useful while an external provider is not
# configured. It is deliberately a small, fixed guidance set; it is not
# presented as a medical diagnosis or as a replacement for a text model.
OFFLINE_ASSISTANT_VERSION = "local-safe-v1"


class AssistantUnavailable(RuntimeError):
    """The optional text-model provider is not ready for this deployment."""


class AssistantRateLimited(RuntimeError):
    """The optional text-model provider asked us to slow down."""


class AssistantProviderError(RuntimeError):
    """The optional text-model provider returned an unusable response."""


_CONTROL_CHARACTERS = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")


def validate_question(value: Any) -> str:
    if not isinstance(value, str):
        raise ValueError("Question must be text.")

    question = " ".join(_CONTROL_CHARACTERS.sub(" ", value).split())
    if len(question) < 3:
        raise ValueError("Question is too short.")
    if len(question) > MAX_QUESTION_CHARS:
        raise ValueError("Question is too long.")
    return question


def safety_answer(question: str) -> str | None:
    """Return a fixed answer for high-risk questions without calling a model."""
    normalized = " ".join(question.casefold().split())
    emergency_terms = (
        "لا يتنفس",
        "مش بيتنفس",
        "صعوبة في التنفس",
        "صعوبة تنفس",
        "ضيق التنفس",
        "ضيق نفس",
        "ازرقاق",
        "أزرق",
        "تشنج",
        "فاقد الوعي",
        "لا يستجيب",
        "نزيف شديد",
        "قيء أخضر",
        "قيء دموي",
        "دم في القيء",
    )
    fever_question = (
        ("حرارة" in normalized or "حمى" in normalized)
        and any(value in normalized for value in ("38", "٣٨", "۳۸"))
    )
    if any(term in normalized for term in emergency_terms) or fever_question:
        return (
            "قد تكون هذه حالة طارئة. لا تنتظري رد المساعد ولا تعتمدي على التطبيق؛ "
            "اتصلي برقم الطوارئ المحلي أو توجهي لأقرب قسم طوارئ الآن. إذا كان الطفل "
            "لا يتنفس أو لا يستجيب، اطلبي الإسعاف فورًا واتّبعي تعليمات عامل الطوارئ."
        )

    medication_terms = (
        "جرعة",
        "دواء",
        "باراسيتامول",
        "بنادول",
        "إيبوبروفين",
        "ايبوبروفين",
        "مضاد حيوي",
    )
    if any(term in normalized for term in medication_terms):
        return (
            "لا أستطيع تحديد جرعة أو وصف دواء لطفل عبر التطبيق. الجرعة تعتمد على "
            "العمر والوزن والتركيز والحالة الطبية؛ تواصلي مع طبيب الأطفال أو الصيدلي "
            "المعتمد، ولا تعطي دواءً للرضيع دون توجيه طبي. إذا كانت هناك صعوبة تنفس، "
            "ازرقاق، تشنج، عدم استجابة أو حرارة 38°م فأعلى قبل عمر 3 أشهر، اطلبي "
            "الرعاية العاجلة فورًا."
        )
    return None


def offline_answer(question: str) -> str:
    """Return useful, conservative guidance when the provider cannot answer.

    This is intentionally deterministic and does not pretend to be a medical
    diagnosis. It keeps the private beta responsive while provider quota or
    connectivity is unavailable.
    """
    normalized = " ".join(question.casefold().split())

    if any(term in normalized for term in ("نوم آمن", "ينام", "النوم", "نوم", "سرير")):
        return (
            "إرشادات النوم الآمن:\n"
            "• ضعي الطفل على ظهره في كل مرة للنوم، على سطح ثابت ومستوٍ.\n"
            "• اجعلي مكان النوم خاليًا من الوسائد والبطاطين الثقيلة والألعاب ومصدّات السرير.\n"
            "• يفضّل أن يكون الطفل في نفس الغرفة، لكن على سطح نوم منفصل ومخصص له.\n"
            "• تجنبي التدخين والحرارة الزائدة، ولا تنامي والطفل على أريكة أو كرسي.\n"
            "إذا لاحظتِ صعوبة تنفس أو تغيرًا في اللون أو عدم استجابة، اطلبي الطوارئ فورًا. "
            "هذه إرشادات عامة ولا تغني عن طبيب الأطفال."
        )

    if any(term in normalized for term in ("رضاعة", "يرضع", "اللبن", "الحليب", "شبع", "جوع")):
        return (
            "إرشادات الرضاعة:\n"
            "• راقبي البلع والهدوء بعد الرضعة، ولا تعتمدي على البكاء وحده كعلامة جوع.\n"
            "• قدّمي الرضعة حسب إشارات الجوع والشبع، ولا تفرضي كمية أو مدة ثابتة على كل طفل.\n"
            "• راقبي الحفاضات المبللة والنشاط وزيادة الوزن في المتابعة الطبية.\n"
            "• لا تعطي ماءً أو أعشابًا أو حليبًا غير موصوف لحديث الولادة.\n"
            "إذا كان الطفل لا يرضع، خاملًا، يتقيأ باستمرار أو يقل تبوله، تواصلي مع طبيب الأطفال اليوم. "
            "لا يحدد التطبيق كمية الرضعة أو بديل الحليب."
        )

    if any(term in normalized for term in ("تجشؤ", "غازات", "انتفاخ", "مغص", "بطن")):
        return (
            "للتجشؤ والغازات:\n"
            "• احملي الطفل بوضع قائم مع دعم الرأس والرقبة بعد الرضعة.\n"
            "• ربّتي برفق، وتوقفي إذا بدا عليه ألم أو ضيق.\n"
            "• تجنبي هزّ الطفل أو الضغط على بطنه، ولا تعطي قطرات أو أعشابًا دون سؤال طبيب الأطفال.\n"
            "اطلبي تقييمًا طبيًا إذا كان البكاء شديدًا أو مستمرًا، أو صاحبه قيء متكرر، انتفاخ واضح، "
            "دم في البراز أو ضعف في الرضاعة."
        )

    if any(term in normalized for term in ("حفاض", "بول", "براز", "إمساك", "إسهال")):
        return (
            "مراقبة الحفاضات:\n"
            "• سجّلي عدد الحفاضات المبللة وشكل البراز مقارنةً بالمعتاد، خصوصًا في الأيام الأولى.\n"
            "• غيّري الحفاض بانتظام ونظفي الجلد بلطف وجففيه دون فرك.\n"
            "• لا تعطي علاجًا للإمساك أو الإسهال من نفسك.\n"
            "قلة البول، جفاف الفم، الخمول، القيء المتكرر، وجود دم أو براز أبيض أو أسود يستلزم "
            "التواصل العاجل مع طبيب الأطفال."
        )

    if any(term in normalized for term in ("الحرارة", "حراره", "درجة الحرارة", "حمى")):
        return (
            "بخصوص الحرارة:\n"
            "• قيسي الحرارة بميزان موثوق وبطريقة ثابتة، وسجّلي الرقم والوقت وطريقة القياس.\n"
            "• لا تعطي دواءً أو جرعة ولا تستخدمي كمادات شديدة البرودة دون توجيه طبي.\n"
            "• حرارة 38°م أو أكثر عند طفل أقل من 3 أشهر، أو حرارة مع خمول أو صعوبة تنفس أو رفض الرضاعة، "
            "تحتاج تقييمًا عاجلًا.\n"
            "التطبيق لا يفسر الرقم وحده ولا يستبدل الفحص الطبي."
        )

    if any(term in normalized for term in ("الصفراء", "يرقان", "اصفرار", "أصفر")):
        return (
            "بخصوص الصفراء:\n"
            "• لا يمكن تقدير شدة الصفراء بالنظر فقط؛ قد يحتاج الطفل فحصًا أو قياسًا لدى الطبيب.\n"
            "• راقبي الرضاعة والنشاط وانتشار الاصفرار إلى الساقين أو بياض العينين.\n"
            "• ظهورها خلال أول 24 ساعة، أو زيادتها سريعًا، أو وجود خمول أو ضعف رضاعة يستلزم التواصل الفوري مع الطبيب.\n"
            "لا تعرضي الطفل للشمس كعلاج ولا توقفي الرضاعة دون توجيه طبي."
        )

    if any(term in normalized for term in ("السرة", "الحبل السري", "الحبل")):
        return (
            "العناية بالسرة:\n"
            "• حافظي على السرة جافة ونظيفة واتركيها تسقط وحدها.\n"
            "• اطوي طرف الحفاض إلى أسفل حتى لا يحتك بها، ولا تضعي زيوتًا أو مساحيق أو وصفات شعبية.\n"
            "• اطلبي تقييمًا طبيًا إذا ظهر احمرار ممتد، تورم، صديد، رائحة قوية أو نزيف لا يتوقف."
        )

    if any(term in normalized for term in ("بكاء", "عيط", "يبكي", "تهدئة")):
        return (
            "عند بكاء الطفل:\n"
            "• ابدئي بالرضاعة والحفاض والتجشؤ ودرجة حرارة المكان والملابس.\n"
            "• خففي الضوء والضوضاء، واحملي الطفل بهدوء مع دعم الرأس والرقبة.\n"
            "• لا تهزي الطفل أبدًا؛ ضعيه على ظهره في مكان آمن وابتعدي دقائق إذا شعرتِ بالإرهاق.\n"
            "إذا كان البكاء غير معتاد أو مستمرًا مع قيء أو حرارة أو خمول أو تغير في اللون، تواصلي مع الطبيب أو الطوارئ."
        )

    if any(term in normalized for term in ("حمام", "استحمام", "جلد", "طفح")):
        return (
            "العناية اليومية:\n"
            "• استخدمي ماءً فاترًا وتحققي من الحرارة بيدك، ولا تتركي الطفل وحده ولو لثوانٍ.\n"
            "• جففي ثنيات الجلد بلطف وتجنبي العطور والوصفات غير الموصوفة.\n"
            "• اطلبي تقييمًا طبيًا إذا كان الطفح منتشرًا، مع فقاعات أو تورم أو حرارة أو خمول.\n"
            "لا يغني التطبيق عن تقييم طبيب الأطفال."
        )

    return (
        "الرد الإرشادي في النسخة التجريبية:\n"
        "أستطيع تقديم معلومات عامة عن النوم الآمن، الرضاعة، الحفاضات، التجشؤ والغازات، الحرارة، "
        "الصفراء، السرة وتهدئة البكاء. ابدئي بالاحتياجات الأساسية وسجّلي أي تغير في الرضاعة أو النشاط أو البول.\n"
        "لا أستطيع التشخيص أو وصف دواء أو جرعة، ولا يغني التطبيق عن طبيب الأطفال. إذا ظهرت صعوبة تنفس، "
        "ازرقاق، تشنج، عدم استجابة، نزيف شديد أو حرارة 38°م فأعلى قبل عمر 3 أشهر، توجهي للطوارئ فورًا."
    )


SYSTEM_PROMPT = """
أنت مساعد إرشادي عربي داخل تطبيق Baby Monitor لمقدمي رعاية الأطفال حديثي الولادة.
أجب بالعربية الفصحى المبسطة وباختصار وبنبرة هادئة. قدم معلومات عامة فقط، ولا تشخّص
مرضًا ولا تصف دواءً أو جرعة ولا تتنبأ بسبب بكاء الطفل من دون فحص. لا تطلب اسم الطفل
أو عنوانه أو رقم هاتفه أو أي بيانات تعريفية. إذا ذكر السؤال علامة خطر، وجّه المستخدم
للطوارئ فورًا بدل محاولة التشخيص. إذا كانت الإجابة تعتمد على عمر أو وزن أو تاريخ مرضي
غير موجود، اذكر أن طبيب الأطفال هو المرجع. لا تدّعِ أنك طبيب. اختم عند الحاجة بجملة
قصيرة تذكّر بأن التطبيق لا يغني عن الرعاية الطبية.
""".strip()


def provider_is_configured() -> bool:
    parsed_url = urlparse(AI_API_URL)
    return bool(
        AI_API_URL
        and AI_API_KEY
        and AI_MODEL
        and parsed_url.scheme == "https"
        and parsed_url.netloc
    )


def offline_assistant_available() -> bool:
    return True


def assistant_mode() -> str:
    return "provider" if provider_is_configured() else "offline"


def _provider_payload(question: str) -> dict[str, Any]:
    return {
        "model": AI_MODEL,
        "temperature": 0.2,
        "max_tokens": 550,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": question},
        ],
    }


def _extract_answer(payload: Any) -> str:
    if not isinstance(payload, dict):
        raise AssistantProviderError("Provider response is not an object.")

    choices = payload.get("choices")
    if not isinstance(choices, list) or not choices:
        raise AssistantProviderError("Provider response has no choices.")

    first = choices[0]
    if not isinstance(first, dict):
        raise AssistantProviderError("Provider response has an invalid choice.")
    message = first.get("message")
    if not isinstance(message, dict):
        raise AssistantProviderError("Provider response has no message.")
    content = message.get("content")
    if isinstance(content, str):
        answer = content.strip()
    elif isinstance(content, list):
        text_parts = [
            item.get("text", "")
            for item in content
            if isinstance(item, dict) and isinstance(item.get("text"), str)
        ]
        answer = "".join(text_parts).strip()
    else:
        answer = ""

    if not answer:
        raise AssistantProviderError("Provider response has no answer text.")
    return answer[:MAX_ANSWER_CHARS]


async def _provider_response(question: str) -> Any:
    """Call the configured provider without exposing question or answer data."""
    import httpx

    headers = {
        "Authorization": "Bearer " + AI_API_KEY,
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    timeout = httpx.Timeout(25.0, connect=5.0)
    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            return await client.post(
                AI_API_URL,
                headers=headers,
                json=_provider_payload(question),
            )
    except httpx.HTTPError as error:
        raise AssistantProviderError("Text-model provider is unreachable.") from error


async def generate_answer(question: str) -> str:
    fixed_answer = safety_answer(question)
    if fixed_answer is not None:
        return fixed_answer

    if not provider_is_configured():
        return offline_answer(question)
    parsed_url = urlparse(AI_API_URL)
    if parsed_url.scheme != "https" or not parsed_url.netloc:
        raise AssistantUnavailable("Text-model service must use HTTPS.")

    try:
        response = await _provider_response(question)
    except AssistantProviderError:
        return offline_answer(question)

    if response.status_code == 429:
        return offline_answer(question)
    if response.status_code < 200 or response.status_code >= 300:
        return offline_answer(question)

    try:
        payload = response.json()
    except ValueError:
        return offline_answer(question)
    try:
        return _extract_answer(payload)
    except AssistantProviderError:
        return offline_answer(question)

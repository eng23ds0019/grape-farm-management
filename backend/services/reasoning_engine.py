"""
Reasoning Engine — The orchestration brain of Draksha AI.
Pulls all data sources, assembles context, and calls the LLM for language generation only.
"""
import json
import re
from core.groq_provider import get_llm_provider
from core.knowledge_base import search_knowledge
from services.farm_memory import retrieve_farm_memory
from services.weather_service import get_weather, format_for_prompt
from services.disease_engine import calculate_disease_risk


def process_query(uid: str, query: str, farm_id: str = "", language: str = "en", image_base64: str = None) -> dict:
    """
    Full reasoning pipeline:
    1. Farm Memory → 2. Weather → 3. Disease Risk → 4. Crop Knowledge → 5. LLM
    Returns structured JSON response.
    """
    # Clean instruction tags from query if present
    clean_query = re.sub(r"\[Language:.*?User question\]:\s*", "", query, flags=re.IGNORECASE).strip()
    if not clean_query:
        clean_query = query

    print(f"🧠 Reasoning Engine: UID={uid[:12]}... CleanQuery='{clean_query[:60]}'")

    # ── Step 1: Farm Memory ──
    memory = retrieve_farm_memory(uid)
    farmer = memory.get("farmer", {})
    farmer_name = farmer.get("name", "Farmer")
    location = farmer.get("location", farmer.get("village", "Sangli"))
    if not location:
        location = "Sangli"

    plots = memory.get("plots", [])
    diaries = memory.get("diaries", [])
    expenses = memory.get("expenses", [])
    chats = memory.get("chats", [])

    # Find the specific plot for precise GPS coordinates
    lat = None
    lon = None
    if plots:
        target_plot = plots[0]
        if farm_id:
            for p in plots:
                if p.get("id") == farm_id or p.get("name") == farm_id or p.get("farmId") == farm_id:
                    target_plot = p
                    break
        lat = target_plot.get("latitude") or target_plot.get("lat")
        lon = target_plot.get("longitude") or target_plot.get("lon")

    # Resilient fallback to farmer profile coordinates
    if not lat or not lon:
        lat = farmer.get("latitude") or farmer.get("lat")
        lon = farmer.get("longitude") or farmer.get("lon")

    try:
        lat = float(lat) if lat is not None else None
        lon = float(lon) if lon is not None else None
    except (ValueError, TypeError):
        lat = None
        lon = None

    # ── Step 2: Weather ──
    weather = get_weather(location, lat, lon)
    weather_text = format_for_prompt(weather)

    # ── Step 3: Disease Risk Engine ──
    disease = calculate_disease_risk(weather, diaries, plots)

    # ── Step 4: Knowledge Retrieval (Using Clean Query) ──
    knowledge = search_knowledge(clean_query)

    # ── Step 5: Build Prompt ──
    crop_stage = "Unknown"
    if plots:
        crop_stage = plots[0].get("cropStage", "Unknown")
    if diaries:
        crop_stage = diaries[0].get("cropStage", crop_stage)

    diary_summary = _format_list(diaries[:5], ["date", "workType", "cropStage", "cleanedText", "originalText"])
    expense_summary = _format_list(expenses[:5], ["date", "category", "amount", "description"])
    chat_history = _format_chats(chats)

    lang_map = {
        "kn": "Kannada (ಕನ್ನಡ)",
        "kn-in": "Kannada (ಕನ್ನಡ)",
        "hi": "Hindi (हिंदी)",
        "hi-in": "Hindi (हिंदी)",
        "en": "English",
        "en-in": "English",
    }
    language_name = lang_map.get(language.lower(), "English")

    system_prompt = f"""You are Draksha AI, an elite Agritech Scientist and expert 24×7 Vineyard Manager for Indian grape farmers.
You provide precise, practical, highly accurate, and customized advice for grape cultivation and farm management.

FARMER & PLOT CONTEXT:
- Farmer Name: {farmer_name}
- Farm Location: {location}
- Selected Vineyard Plot: {farm_id if farm_id else 'Main Plot'}
- Current Growth Stage: {crop_stage}

HISTORICAL FARM ACTIVITY (Recent Diary Entries):
{diary_summary}

RECENT FARM EXPENSES:
{expense_summary}

PREVIOUS CONVERSATION HISTORY WITH FARMER:
{chat_history}

REAL-TIME WEATHER AT VINEYARD GPS COORDINATES:
{weather_text}

DISEASE COMPUTATION MONITORING:
- Current Disease Risk: {disease['diseaseRisk']} ({disease['diseaseName']})
- Risk Score: {disease['confidence']}
- Recommended Treatment: {disease['recommendedSpray']}

EXPERT GRAPE AGRONOMY KNOWLEDGE BASE:
{knowledge}

CRITICAL RESPONSE RULES:
1. DIRECT ANSWER FIRST: Directly and thoroughly answer the farmer's specific question ('{clean_query}').
2. IF QUESTION IS ABOUT FERTILIZER, WATERING, GA3, VARIETIES, PRUNING, SOIL, ROOTSTOCK, RAISINS, OR MARKET:
   - Provide exact numbers, dosages per acre, timing, chemical names, and step-by-step practical agricultural steps.
   - DO NOT turn non-disease questions into a lecture about downy/powdery mildew! Focus 100% on answering what the farmer asked.
3. IF AN IMAGE IS PROVIDED BY THE FARMER:
   - Analyze the plant tissue (leaf, fruit, stem, roots) in detail.
   - Identify symptoms, disease/pest name, confidence level, cause (weather/humidity/spray history), organic alternative, and recovery plan.
4. PERSONALIZATION: Personalize your answer using the farmer's profile, crop stage ({crop_stage}), recent sprays/diaries, and local weather.
5. LANGUAGE COMPLIANCE: Respond 100% in {language_name}.
   - If Kannada: Entire response (greeting, reasoning, dosages, steps) MUST be in Kannada script.
   - If Hindi: Entire response MUST be in Hindi script.
   - If English: Entire response MUST be in English.
6. FORMAT: Use clear Markdown with bold headers, bullet points, and numbered action steps.

OUTPUT FORMAT:
Return a JSON object containing:
{{
  "response": "Your full, complete, markdown-formatted answer.",
  "diseaseRisk": "{disease['diseaseRisk']}",
  "diseaseName": "{disease['diseaseName']}",
  "recommendedSpray": "{disease['recommendedSpray']}",
  "cropStage": "{crop_stage}"
}}"""

    user_message = f"Farmer question: {clean_query}"
    if image_base64:
        user_message += " [An image is attached to this request. Analyze the plant tissue in detail.]"

    # ── Step 6: LLM Generation ──
    llm = get_llm_provider()
    raw = llm.generate(system_prompt=system_prompt, user_message=user_message, image_base64=image_base64)

    # ── Step 7: Parse Response ──
    result = _parse_llm_response(raw, disease, crop_stage)
    print(f"✅ Reasoning complete. Risk={result['diseaseRisk']}, Spray={result['recommendedSpray'][:30]}")
    return result


def _parse_llm_response(raw: str, disease: dict, crop_stage: str) -> dict:
    """Safely parse LLM output without truncating or corrupting valid markdown text."""
    if not raw or not raw.strip():
        return {
            "response": "I am analyzing your question. Please try asking again.",
            "diseaseRisk": disease.get("diseaseRisk", "Low"),
            "diseaseName": disease.get("diseaseName", "None"),
            "recommendedSpray": disease.get("recommendedSpray", "None"),
            "cropStage": crop_stage,
        }

    clean = raw.strip()
    if clean.startswith("```"):
        clean = re.sub(r"^```(?:json)?\s*", "", clean)
        clean = re.sub(r"\s*```$", "", clean)
        clean = clean.strip()

    # Try standard json.loads
    try:
        data = json.loads(clean)
        if isinstance(data, dict) and "response" in data and str(data["response"]).strip():
            if disease.get("diseaseRisk") == "High":
                data["diseaseRisk"] = "High"
                data["diseaseName"] = disease.get("diseaseName", "Downy Mildew")
                data["recommendedSpray"] = disease.get("recommendedSpray", "Metalaxyl")
            data.setdefault("cropStage", crop_stage)
            return data
    except Exception:
        pass

    # Regex extraction for "response" key if JSON format had unescaped quotes/newlines
    match = re.search(r'"response"\s*:\s*"(.*?)"\s*,\s*"diseaseRisk"', clean, re.DOTALL)
    if not match:
        match = re.search(r'"response"\s*:\s*"(.*)"', clean, re.DOTALL)

    if match:
        extracted = match.group(1).replace("\\n", "\n").replace('\\"', '"')
        if extracted.strip():
            return {
                "response": extracted.strip(),
                "diseaseRisk": disease.get("diseaseRisk", "Low"),
                "diseaseName": disease.get("diseaseName", "None"),
                "recommendedSpray": disease.get("recommendedSpray", "None"),
                "cropStage": crop_stage,
            }

    # Fallback: The entire raw string IS the LLM's markdown response
    fallback_text = clean
    fallback_text = re.sub(r'^\s*\{\s*"response"\s*:\s*"?', '', fallback_text)
    fallback_text = re.sub(r'"?\s*,\s*"diseaseRisk".*$', '', fallback_text, flags=re.DOTALL)
    fallback_text = re.sub(r'"?\s*\}\s*$', '', fallback_text)
    fallback_text = fallback_text.replace("\\n", "\n").replace('\\"', '"').strip()

    if not fallback_text:
        fallback_text = raw.strip()

    return {
        "response": fallback_text,
        "diseaseRisk": disease.get("diseaseRisk", "Low"),
        "diseaseName": disease.get("diseaseName", "None"),
        "recommendedSpray": disease.get("recommendedSpray", "None"),
        "cropStage": crop_stage,
    }


def _format_list(items: list, fields: list) -> str:
    if not items:
        return "No recent records found."
    lines = []
    for item in items:
        parts = [f"{f}: {item.get(f, '')}" for f in fields if item.get(f)]
        lines.append(" | ".join(parts))
    return "\n".join(lines)


def _format_chats(chats: list) -> str:
    if not chats:
        return "No previous conversation history."
    lines = []
    for c in chats:
        role = c.get("role", "user")
        text = c.get("text", c.get("message", c.get("response", "")))[:200]
        lines.append(f"{role.upper()}: {text}")
    return "\n".join(lines)

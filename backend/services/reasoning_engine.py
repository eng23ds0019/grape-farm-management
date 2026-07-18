"""
Reasoning Engine — The orchestration brain of Draksha AI.
Pulls all data sources, assembles context, and calls the LLM for language generation only.
The intelligence comes from retrieval and rules. The LLM is the final voice.
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
    Full pipeline:
    1. Farm Memory → 2. Weather → 3. Disease Risk → 4. Crop Knowledge → 5. LLM
    Returns structured JSON response.
    """
    print(f"🧠 Reasoning Engine: UID={uid[:12]}... Query='{query[:60]}'")

    # ── Step 1: Farm Memory ──
    memory = retrieve_farm_memory(uid)
    farmer = memory.get("farmer", {})
    farmer_name = farmer.get("name", "Farmer")
    location = farmer.get("location", farmer.get("village", "Nashik"))
    if not location:
        location = "Nashik"

    plots = memory.get("plots", [])
    diaries = memory.get("diaries", [])
    expenses = memory.get("expenses", [])
    chats = memory.get("chats", [])

    # Find the specific plot for precise GPS coordinates
    lat = None
    lon = None
    if plots:
        target_plot = plots[0] # Default to first plot
        if farm_id:
            for p in plots:
                if p.get("id") == farm_id or p.get("name") == farm_id or p.get("farmId") == farm_id:
                    target_plot = p
                    break
        lat = target_plot.get("latitude") or target_plot.get("lat")
        lon = target_plot.get("longitude") or target_plot.get("lon")

    # Resilient fallback to farmer profile coordinates
    if not lat or not lon:
        lat = farmer.get("latitude") or farmer.get("lat") or farmer.get("latitude")
        lon = farmer.get("longitude") or farmer.get("lon") or farmer.get("longitude")

    # ── Step 2: Weather ──
    weather = get_weather(location, lat, lon)
    weather_text = format_for_prompt(weather)

    # ── Step 3: Disease Risk Engine ──
    disease = calculate_disease_risk(weather, diaries, plots)

    # ── Step 4: Knowledge Retrieval ──
    knowledge = search_knowledge(query)

    # ── Step 5: Build Prompt ──
    crop_stage = "Unknown"
    if plots:
        crop_stage = plots[0].get("cropStage", "Unknown")
    if diaries:
        crop_stage = diaries[0].get("cropStage", crop_stage)

    # Format recent diary for context
    diary_summary = _format_list(diaries[:5], ["date", "workType", "cropStage", "cleanedText", "originalText"])
    expense_summary = _format_list(expenses[:5], ["date", "category", "amount", "description"])
    chat_history = _format_chats(chats)

    system_prompt = f"""You are Draksha AI, a Principal Agritech Scientist and expert 24×7 Vineyard Manager for Indian grape farmers.
You are NOT a chatbot. You are a professional farm supervisor who knows this farmer's precise history.
Always respond in the SAME LANGUAGE as the user's question (Kannada, Hindi, or English).

FARMER PROFILE:
- Name: {farmer_name}
- Location: {location}
- Current Crop Stage: {crop_stage}

RECENT FARM ACTIVITY (last 5 diary entries):
{diary_summary}

RECENT EXPENSES:
{expense_summary}

CONVERSATION HISTORY:
{chat_history}

LIVE PRECISE WEATHER (from Plot GPS coordinates):
{weather_text}

DISEASE ENGINE RESULT (computed deterministically):
- Risk: {disease['diseaseRisk']} ({disease['diseaseName']})
- Confidence: {disease['confidence']}
- Recommended Action: {disease['recommendedSpray']}
- Reason: {disease['reason']}

AGRICULTURAL KNOWLEDGE:
{knowledge[:3000]}

RULES:
1. Act as a proactive, highly analytical farm supervisor. 
2. Combine the permanent Agricultural Knowledge with the farmer's personal activity history.
3. Analyze the situation, reason through the problem, recommend a solution, and explain WHY. Provide actionable advice.
4. Never give generic advice. Use exact plot history, weather, and crop stage.
5. Never say "I am an AI", "I am a language model", or "I don't know."
6. You MAY use Markdown formatting (bold, bullet points) to structure your response beautifully.
7. If an image is provided by the farmer, analyze it meticulously alongside the weather and history.

Return ONLY this exact JSON (no markdown fences around the JSON itself):
{{"response": "Your expert, markdown-formatted answer here. Explain your reasoning and give actionable steps.", "diseaseRisk": "{disease['diseaseRisk']}", "diseaseName": "{disease['diseaseName']}", "recommendedSpray": "{disease['recommendedSpray']}", "cropStage": "{crop_stage}"}}"""

    user_message = f"Farmer question: {query}"
    if image_base64:
        user_message += " [An image is attached to this request. Analyze it.]"

    # ── Step 6: LLM Generation ──
    llm = get_llm_provider()
    raw = llm.generate(system_prompt=system_prompt, user_message=user_message, image_base64=image_base64)

    # ── Step 7: Parse Response ──
    result = _parse_llm_response(raw, disease, crop_stage)
    print(f"✅ Reasoning complete. Risk={result['diseaseRisk']}, Spray={result['recommendedSpray'][:30]}")
    return result


def _parse_llm_response(raw: str, disease: dict, crop_stage: str) -> dict:
    """Safely parse LLM JSON output with fallback."""
    try:
        # Strip markdown fences if present
        clean = re.sub(r"```(?:json)?", "", raw).strip()
        result = json.loads(clean)
        # Override with deterministic values for critical fields
        if disease["diseaseRisk"] == "High":
            result["diseaseRisk"] = "High"
            result["diseaseName"] = disease["diseaseName"]
            result["recommendedSpray"] = disease["recommendedSpray"]
        result.setdefault("cropStage", crop_stage)
        return result
    except (json.JSONDecodeError, Exception) as e:
        print(f"⚠️  JSON parse error: {e}. Returning structured fallback.")
        # Extract meaningful text from raw if possible
        spoken = raw[:300] if len(raw) > 10 else "I processed your question. Please ask again for the complete answer."
        return {
            "response": spoken,
            "diseaseRisk": disease["diseaseRisk"],
            "diseaseName": disease["diseaseName"],
            "recommendedSpray": disease["recommendedSpray"],
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
        return "No previous conversation."
    lines = []
    for c in chats:
        role = c.get("role", "unknown")
        text = c.get("text", c.get("message", ""))[:100]
        lines.append(f"{role.upper()}: {text}")
    return "\n".join(lines)

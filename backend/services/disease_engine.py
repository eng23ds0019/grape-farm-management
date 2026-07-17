"""
Disease Prediction Engine — Deterministic Rule-Based + Confidence Scoring.
Runs BEFORE the LLM to establish ground truth risk levels.
The LLM enriches the explanation; it does not calculate the risk.
"""
import datetime
from typing import Optional


def calculate_disease_risk(weather: dict, diaries: list, plots: list) -> dict:
    """
    Evaluates disease risk using weather + spray history + crop stage.
    Returns confidence-scored prediction.
    """
    humidity = weather.get("humidity", 65)
    rainfall = weather.get("rainfall_1h", 0.0)
    temp = weather.get("temperature", 28.0)
    cloud_cover = weather.get("cloud_cover", 50)
    condition = weather.get("condition", "Clear").lower()

    # Determine crop stage
    crop_stage = "Unknown"
    if plots:
        crop_stage = plots[0].get("cropStage", "Unknown")
    if diaries:
        crop_stage = diaries[0].get("cropStage", crop_stage)

    # Days since last spray
    days_since_spray = _days_since_last_spray(diaries)

    # ─── DOWNY MILDEW RISK ───
    dm_score = 0.0
    if humidity > 85:
        dm_score += 0.40
    elif humidity > 75:
        dm_score += 0.25
    elif humidity > 65:
        dm_score += 0.10

    if rainfall > 2.0:
        dm_score += 0.25
    elif rainfall > 0.5:
        dm_score += 0.10

    if temp >= 18 and temp <= 26:
        dm_score += 0.20  # Ideal temperature for Downy Mildew

    if "rain" in condition or "cloud" in condition:
        dm_score += 0.10

    if days_since_spray > 14:
        dm_score += 0.30
    elif days_since_spray > 7:
        dm_score += 0.15

    if crop_stage in ["Flowering", "Berry Set", "Berry Growth"]:
        dm_score += 0.15  # Vulnerable stages

    # ─── POWDERY MILDEW RISK ───
    pm_score = 0.0
    if humidity > 40 and humidity < 70:  # Dry conditions favor PM
        pm_score += 0.30
    if temp >= 20 and temp <= 27:
        pm_score += 0.20
    if days_since_spray > 12:
        pm_score += 0.25
    if cloud_cover < 30:
        pm_score += 0.10

    # Pick the highest risk
    dm_score = min(dm_score, 1.0)
    pm_score = min(pm_score, 1.0)

    if dm_score >= pm_score:
        risk_level = _score_to_level(dm_score)
        return {
            "diseaseRisk": risk_level,
            "diseaseName": "Downy Mildew" if dm_score > 0.2 else "None",
            "confidence": round(dm_score, 2),
            "recommendedSpray": _get_spray("Downy Mildew", dm_score),
            "reason": f"Humidity {humidity}%, {days_since_spray} days since last spray, stage: {crop_stage}",
        }
    else:
        risk_level = _score_to_level(pm_score)
        return {
            "diseaseRisk": risk_level,
            "diseaseName": "Powdery Mildew" if pm_score > 0.2 else "None",
            "confidence": round(pm_score, 2),
            "recommendedSpray": _get_spray("Powdery Mildew", pm_score),
            "reason": f"Temp {temp}°C, {days_since_spray} days since last spray, stage: {crop_stage}",
        }


def _days_since_last_spray(diaries: list) -> int:
    """Calculate days since the most recent spray diary entry."""
    today = datetime.date.today()
    for entry in diaries:
        work_type = str(entry.get("workType", "")).lower()
        if "spray" in work_type or "ಔಷಧಿ" in work_type or "छिड़काव" in work_type:
            try:
                date_str = entry.get("date", "")
                if date_str:
                    entry_date = datetime.date.fromisoformat(date_str[:10])
                    return (today - entry_date).days
            except Exception:
                continue
    return 99  # No spray history found — assume very high risk


def _score_to_level(score: float) -> str:
    if score >= 0.70:
        return "High"
    elif score >= 0.40:
        return "Medium"
    elif score >= 0.20:
        return "Low"
    return "Negligible"


def _get_spray(disease: str, confidence: float) -> str:
    if confidence < 0.20:
        return "None"
    if disease == "Downy Mildew":
        if confidence >= 0.70:
            return "Metalaxyl 72WP @ 2.5g/L + Mancozeb 75WP @ 2g/L (URGENT — apply within 24hrs)"
        return "Metalaxyl 72WP @ 2.5g/L (preventive)"
    if disease == "Powdery Mildew":
        if confidence >= 0.70:
            return "Hexaconazole 5EC @ 1ml/L + Sulphur 80WP @ 3g/L (URGENT)"
        return "Sulphur 80WP @ 3g/L (preventive)"
    return "None"

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

    # Dynamic smart status and AI insight generation
    rain_1h = weather.get("rainfall_1h", 0.0)
    
    if dm_score >= pm_score:
        risk_level = _score_to_level(dm_score)
        disease_name = "Downy Mildew" if dm_score > 0.2 else "None"
        rec_spray = _get_spray("Downy Mildew", dm_score)
        reason = f"Humidity {humidity}%, {days_since_spray} days since last spray, stage: {crop_stage}"
        
        if risk_level in ["High", "Medium"] and disease_name != "None":
            smart_status = f"{disease_name} Risk Increasing"
            ai_insight = f"{disease_name} threat level is {risk_level}. Spraying {rec_spray} is recommended immediately."
        elif rain_1h > 0:
            smart_status = "Rain Expected Today"
            ai_insight = "Rainfall detected at your coordinates. Avoid spraying fungicides to prevent chemical wash-off."
        elif humidity > 80:
            smart_status = "High Humidity Advisory"
            ai_insight = "Relative humidity is high at your vineyard. Monitor lower leaf canopies for early signs of downy mildew."
        elif temp > 36:
            smart_status = "Heat Stress Caution"
            ai_insight = "Temperatures are high at your vineyard. Optimize irrigation timing to prevent moisture transpiration stress."
        else:
            smart_status = "Excellent Growing Conditions"
            ai_insight = "Weather and canopy micro-climate conditions are optimal for grape berry development."
            
        return {
            "diseaseRisk": risk_level,
            "diseaseName": disease_name,
            "confidence": round(dm_score, 2),
            "recommendedSpray": rec_spray,
            "reason": reason,
            "smartStatus": smart_status,
            "aiInsight": ai_insight,
        }
    else:
        risk_level = _score_to_level(pm_score)
        disease_name = "Powdery Mildew" if pm_score > 0.2 else "None"
        rec_spray = _get_spray("Powdery Mildew", pm_score)
        reason = f"Temp {temp}°C, {days_since_spray} days since last spray, stage: {crop_stage}"
        
        if risk_level in ["High", "Medium"] and disease_name != "None":
            smart_status = f"{disease_name} Risk Increasing"
            ai_insight = f"{disease_name} threat level is {risk_level}. Apply preventive spray of {rec_spray}."
        elif rain_1h > 0:
            smart_status = "Rain Expected Today"
            ai_insight = "Precipitation recorded. High humidity may follow; check ventilation inside the vine rows."
        elif humidity > 80:
            smart_status = "High Humidity Advisory"
            ai_insight = "Canopy moisture is high. Watch out for secondary infections in dense bunch zones."
        elif temp > 36:
            smart_status = "Heat Stress Caution"
            ai_insight = "Temperatures are peaking. Grape vines will reduce photosynthesis to conserve moisture."
        else:
            smart_status = "Excellent Growing Conditions"
            ai_insight = "Canopy environment is well balanced for normal growth and berry enlargement."
            
        return {
            "diseaseRisk": risk_level,
            "diseaseName": disease_name,
            "confidence": round(pm_score, 2),
            "recommendedSpray": rec_spray,
            "reason": reason,
            "smartStatus": smart_status,
            "aiInsight": ai_insight,
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

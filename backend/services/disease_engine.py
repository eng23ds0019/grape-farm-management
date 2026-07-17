class DiseaseEngine:
    @staticmethod
    def calculate_risk(weather_context: str, farm_memory: dict):
        """
        Deterministic Disease Engine.
        Predicts disease risk using hardcoded thresholds for Humidity, Temperature, and Spray History.
        This runs BEFORE the reasoning engine to provide ground truth risk scores.
        """
        
        # Example naive implementation based on rules:
        # If high humidity > 80% + rain -> high downy mildew risk
        # If no recent fungicide spray + cloudy -> high risk
        
        # Extract recent sprays from farm memory
        diaries = farm_memory.get('diaries', [])
        recent_sprays = [d for d in diaries if "spray" in str(d.get('workType', '')).lower()]
        days_since_last_spray = 100 # Default safe value
        
        # (In production, parse actual dates. Mocking logic for now)
        if len(recent_sprays) > 0:
            days_since_last_spray = 2 # Mock 2 days ago
            
        humidity = 65
        if "Humidity: 8" in weather_context or "Humidity: 9" in weather_context:
            humidity = 85
            
        risk_level = "Low"
        disease = "None"
        confidence = 0.0
        
        if humidity > 80 and days_since_last_spray > 7:
            risk_level = "High"
            disease = "Downy Mildew"
            confidence = 0.95
        elif humidity > 70 and days_since_last_spray > 5:
            risk_level = "Medium"
            disease = "Powdery Mildew"
            confidence = 0.75
            
        return {
            "diseaseRisk": risk_level,
            "diseaseName": disease,
            "confidenceScore": confidence
        }

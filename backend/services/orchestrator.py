import os
import json
import google.generativeai as genai
from services.farm_memory import FarmMemoryService
from services.crop_expert import CropExpertService
from services.disease_engine import DiseaseEngine

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")

try:
    genai.configure(api_key=GEMINI_API_KEY)
    generation_config = {
        "temperature": 0.2,
        "top_p": 0.95,
        "top_k": 64,
        "max_output_tokens": 1024,
        "response_mime_type": "application/json",
    }
    model = genai.GenerativeModel(
        model_name="gemini-1.5-flash",
        generation_config=generation_config,
    )
except Exception as e:
    print(f"Failed to initialize Gemini: {e}")


class DrakshaOrchestratorService:
    @staticmethod
    def process_voice_query(uid: str, query: str, weather_context: str):
        """
        The central Reasoning Engine pipeline for Draksha AI.
        Retrieves Memory -> Knowledge -> Weather -> Disease Risk -> LLM.
        """
        
        # 1. Retrieve Farm Memory from Firestore
        memory = FarmMemoryService.retrieve_memory(uid)
        farmer_name = memory.get('farmer', {}).get('name', 'Farmer')
        
        # 2. Retrieve Plot Intelligence (assume taking the first plot for simplicity now)
        plots = memory.get('plots', [])
        plot_stage = plots[0].get('cropStage', 'Unknown') if plots else 'Unknown'
        
        # 3. Retrieve Crop Knowledge (Pinecone)
        knowledge = CropExpertService.retrieve_knowledge(query)
        
        # 4. Disease Engine (Deterministic)
        disease_evaluation = DiseaseEngine.calculate_risk(weather_context, memory)
        
        # 5. Reasoning Engine (LLM Context Assembly)
        prompt = f"""
        You are Draksha AI, an expert Grape Farming AI Manager in India. 
        Answer in the same language as the user's query (e.g. Kannada, English, Hindi).
        
        USER QUERY: {query}
        
        --- FARM MEMORY ---
        Farmer Name: {farmer_name}
        Current Crop Stage: {plot_stage}
        Recent Diaries: {str(memory.get('diaries', [])[:3])}
        Recent Expenses: {str(memory.get('expenses', [])[:3])}
        
        --- WEATHER & DISEASE ENGINE ---
        Weather: {weather_context}
        Computed Disease Risk: {disease_evaluation['diseaseRisk']} ({disease_evaluation['diseaseName']})
        
        --- CROP KNOWLEDGE ---
        {knowledge}
        
        --- RULES ---
        1. Act as a proactive farm supervisor. 
        2. DO NOT ACT LIKE A CHATBOT. Never say "I don't know". Never say "I am an AI". 
        3. If you genuinely do not have the answer in your knowledge or memory, say: "I only know about your farm and grape cultivation right now. I don't have the answer to that, but I will improve to give the answer in the future."
        4. If disease risk is High or Medium, recommend the exact spray.
        
        Return ONLY this JSON format exactly:
        {{
          "response": "Your spoken response. Be concise, expert, and conversational. Do not use markdown like asterisks.",
          "diseaseRisk": "{disease_evaluation['diseaseRisk']}",
          "diseaseName": "{disease_evaluation['diseaseName']}",
          "recommendedSpray": "Fungicide name or None"
        }}
        """

        try:
            response = model.generate_content(prompt)
            raw_text = response.text.strip()
            
            # Remove potential markdown wrappers
            if raw_text.startswith("```json"):
                raw_text = raw_text[7:]
            if raw_text.endswith("```"):
                raw_text = raw_text[:-3]
                
            result = json.loads(raw_text)
            
            # Override disease risk with our deterministic engine to ensure safety thresholds are respected
            if disease_evaluation['diseaseRisk'] == 'High':
                result['diseaseRisk'] = 'High'
                result['diseaseName'] = disease_evaluation['diseaseName']
                
            return result
            
        except Exception as e:
            print(f"Orchestration LLM Error: {e}")
            return {
                "response": "I could not reach the reasoning engine. Please check your backend connection.",
                "diseaseRisk": "Unknown",
                "diseaseName": "Unknown",
                "recommendedSpray": "Unknown"
            }

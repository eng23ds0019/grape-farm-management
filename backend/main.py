import os
import shutil
import uuid
import json
import requests

from fastapi import FastAPI, UploadFile, File, HTTPException, status, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
from dotenv import load_dotenv

load_dotenv()

# ──────────────────────────────────────────────
# Environment Variables
# ──────────────────────────────────────────────
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
PINECONE_API_KEY = os.getenv("PINECONE_API_KEY", "")
PINECONE_INDEX_URL = os.getenv("PINECONE_INDEX_URL", "")

# ──────────────────────────────────────────────
# Gemini Setup
# ──────────────────────────────────────────────
gemini_model = None
try:
    import google.generativeai as genai
    if GEMINI_API_KEY:
        genai.configure(api_key=GEMINI_API_KEY)
        gemini_model = genai.GenerativeModel(
            model_name="gemini-1.5-flash",
            generation_config={
                "temperature": 0.2,
                "top_p": 0.95,
                "max_output_tokens": 1024,
                "response_mime_type": "application/json",
            },
        )
        print("✅ Gemini initialized successfully.")
    else:
        print("⚠️  GEMINI_API_KEY not set. Gemini will not be available.")
except Exception as e:
    print(f"❌ Gemini initialization failed: {e}")

# ──────────────────────────────────────────────
# Firebase Admin Setup
# ──────────────────────────────────────────────
FIREBASE_ADMIN_ACTIVE = False
firebase_db = None
try:
    import firebase_admin
    from firebase_admin import credentials, auth, firestore
    if not firebase_admin._apps:
        try:
            firebase_admin.initialize_app()
            FIREBASE_ADMIN_ACTIVE = True
            firebase_db = firestore.client()
            print("✅ Firebase Admin initialized via default credentials.")
        except Exception as e:
            cert_path = "serviceAccountKey.json"
            if os.path.exists(cert_path):
                firebase_admin.initialize_app(credentials.Certificate(cert_path))
                FIREBASE_ADMIN_ACTIVE = True
                firebase_db = firestore.client()
                print("✅ Firebase Admin initialized via serviceAccountKey.json.")
            else:
                print(f"⚠️  Firebase Admin skipped: {e}")
    else:
        firebase_db = firestore.client()
        FIREBASE_ADMIN_ACTIVE = True
        print("✅ Firebase Admin already initialized.")
except Exception as e:
    print(f"❌ Firebase Admin error: {e}")

# ──────────────────────────────────────────────
# FastAPI App
# ──────────────────────────────────────────────
app = FastAPI(
    title="Draksha AI - Vineyard Manager Backend",
    description="Production-grade AI Agent for grape farm management.",
    version="2.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

TEMP_DIR = "temp_uploads"
os.makedirs(TEMP_DIR, exist_ok=True)

# ──────────────────────────────────────────────
# Health Check
# ──────────────────────────────────────────────
@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "version": "2.0.0",
        "gemini_ready": gemini_model is not None,
        "firebase_ready": FIREBASE_ADMIN_ACTIVE,
    }

# ──────────────────────────────────────────────
# Farm Memory Retrieval (Firestore)
# ──────────────────────────────────────────────
def retrieve_farm_memory(uid: str) -> dict:
    if not FIREBASE_ADMIN_ACTIVE or not firebase_db or not uid:
        return {"farmer": {}, "plots": [], "diaries": [], "expenses": [], "chats": []}
    try:
        from firebase_admin import firestore as fs
        farmer_doc = firebase_db.collection('users').document(uid).get()
        farmer_data = farmer_doc.to_dict() if farmer_doc.exists else {}

        plots = [p.to_dict() for p in firebase_db.collection('users').document(uid).collection('plots').stream()]
        diaries = [d.to_dict() for d in firebase_db.collection('users').document(uid).collection('diary').order_by('date', direction=fs.Query.DESCENDING).limit(20).stream()]
        expenses = [e.to_dict() for e in firebase_db.collection('users').document(uid).collection('expenses').order_by('date', direction=fs.Query.DESCENDING).limit(10).stream()]
        chats = [c.to_dict() for c in firebase_db.collection('users').document(uid).collection('chats').order_by('timestamp', direction=fs.Query.DESCENDING).limit(5).stream()]
        chats.reverse()

        return {
            "farmer": farmer_data,
            "plots": plots,
            "diaries": diaries,
            "expenses": expenses,
            "chats": chats,
        }
    except Exception as e:
        print(f"❌ Farm memory retrieval error: {e}")
        return {"farmer": {}, "plots": [], "diaries": [], "expenses": [], "chats": []}

# ──────────────────────────────────────────────
# Disease Risk Engine (Deterministic Rules)
# ──────────────────────────────────────────────
def calculate_disease_risk(weather_context: str, diaries: list) -> dict:
    humidity_high = any(kw in weather_context for kw in ["Humidity: 8", "Humidity: 9", "humidity: 8", "humidity: 9"])
    recent_sprays = [d for d in diaries if "spray" in str(d.get("workType", "")).lower()]
    days_since_spray = 3 if recent_sprays else 14

    if humidity_high and days_since_spray > 7:
        return {"risk": "High", "disease": "Downy Mildew", "spray": "Metalaxyl + Mancozeb @ 2.5g/L", "confidence": 0.92}
    elif days_since_spray > 10:
        return {"risk": "Medium", "disease": "Powdery Mildew", "spray": "Hexaconazole @ 1ml/L", "confidence": 0.70}
    return {"risk": "Low", "disease": "None", "spray": "None", "confidence": 0.10}

# ──────────────────────────────────────────────
# Permanent Grape Knowledge Base
# ──────────────────────────────────────────────
GRAPE_KNOWLEDGE = """
=== DRAKSHA AI PERMANENT GRAPE KNOWLEDGE BASE ===

VARIETIES: Thompson Seedless, Sharad Seedless, Sonaka, 2A Clone, Tas-A-Ganesh, Red Globe, Flame Seedless.

ANNUAL CROP CALENDAR (Maharashtra):
- April Pruning (Khandya Chhatayi): Pruning for berry crop. Remove old canes. Apply dormancy breaker.
- May-June: Shoot emergence, canopy management, tying.
- July: Flowering. Apply GA3 3-5ppm at full bloom + 10 days. Control humidity for Downy Mildew.
- August: Berry set, fruit thinning for export quality. Apply calcium sprays.
- Sept-Oct: Berry development. Maintain soil moisture. Final nutrition sprays.
- Nov-Dec: Pre-harvest. Reduce irrigation. Sugar development.
- Jan-Feb: Harvest. Fresh market or raisin drying.
- March: Rest period. Soil amendments. Fertigation schedule planning.

DISEASES & CONTROL:
- Downy Mildew (Plasmopara viticola): Caused by high humidity >80%, temp 18-25°C, leaf wetness. 
  Prevention: Metalaxyl 72WP @ 2.5g/L OR Fosetyl-Al @ 3g/L every 7-10 days.
  Curative: Dimethomorph + Mancozeb @ 3g/L. Remove infected leaves immediately.
- Powdery Mildew (Erysiphe necator): White powdery coating. Dry weather favors it.
  Control: Hexaconazole 5EC @ 1ml/L OR Tebuconazole @ 1ml/L OR Sulphur 80WP @ 3g/L.
- Anthracnose: Dark sunken spots on berries. Control: Carbendazim @ 1g/L.
- Botrytis Bunch Rot: Gray mold on berries at ripening stage. Control: Iprodione @ 1.5g/L.

NUTRITION (Fertigation Schedule):
- Nitrogen (N): DAP, Urea. Critical at shoot growth, after fruit set.
- Phosphorus (P): For root development and flowering. Apply SSP or MAP.
- Potassium (K): For berry size, color, sugar. MOP or SOP @ 3-5kg/acre.
- Calcium-Boron: Prevents berry cracking, improves firmness. Calmax spray @ 2ml/L.
- Magnesium: Foliar spray of MgSO4 @ 5g/L for leaf chlorosis.

IRRIGATION:
- Drip irrigation preferred. Critical stages: Shoot growth, Flowering, Berry development.
- Avoid overhead irrigation - promotes fungal diseases.
- Pre-harvest deficit irrigation improves sugar content.

RAISIN PRODUCTION:
- Harvest at 22-24 Brix. Dip in Potassium Carbonate 5% + Olive oil (dipping method).
- Shade drying: 8-12 days. Sun drying: 5-7 days.
- Target: Golden color, moisture <16%. Grade A: >15mm diameter.

GA3 (Gibberellic Acid) USAGE:
- Berry thinning: GA3 25-50ppm at full bloom.
- Berry elongation: GA3 25-50ppm 10 days post bloom.
- Berry sizing: GA3 50-75ppm 20-25 days post bloom.
- Mix only in clean water. Apply morning/evening only.

EXPORT STANDARDS:
- EurepGAP / GlobalGAP certified practices required.
- Pre-harvest interval (PHI) must be maintained for all pesticides.
- Maximum Residue Levels (MRL) compliance is critical.
- Fruit size: Thompson Seedless export: >17mm. Sonaka: >18mm.
"""

# ──────────────────────────────────────────────
# Draksha AI Voice Orchestrator
# ──────────────────────────────────────────────
class VoiceQueryRequest(BaseModel):
    uid: str
    query: str
    weather_context: str

@app.post("/api/v1/chat/orchestrate")
async def orchestrate_voice(request: VoiceQueryRequest):
    """
    Draksha AI Production Voice Engine - Main Endpoint
    Pipeline: FarmMemory → DiseaseEngine → CropKnowledge → Gemini Reasoning
    """
    try:
        print(f"📥 Voice query received. UID: {request.uid}, Query: {request.query[:60]}")

        # Step 1: Farm Memory
        memory = retrieve_farm_memory(request.uid)
        farmer_name = memory["farmer"].get("name", "Farmer")
        plots = memory.get("plots", [])
        plot_stage = plots[0].get("cropStage", "Unknown") if plots else "Unknown"
        diaries = memory.get("diaries", [])
        expenses = memory.get("expenses", [])

        # Step 2: Disease Risk Engine
        disease = calculate_disease_risk(request.weather_context, diaries)

        # Step 3: Build Prompt
        prompt = f"""
You are Draksha AI, an expert Vineyard Manager for Indian grape farmers.
You speak as a knowledgeable farm supervisor, not a chatbot.
Always answer in the SAME LANGUAGE as the user's query (Kannada, Hindi, or English).

=== FARMER PROFILE ===
Name: {farmer_name}
Current Crop Stage: {plot_stage}

=== RECENT FARM ACTIVITY (Last 5 Diary Entries) ===
{json.dumps(diaries[:5], default=str, ensure_ascii=False)}

=== RECENT EXPENSES ===
{json.dumps(expenses[:3], default=str, ensure_ascii=False)}

=== WEATHER ===
{request.weather_context}

=== DISEASE ENGINE RESULT ===
Risk Level: {disease['risk']}
Disease: {disease['disease']}
Recommended Spray: {disease['spray']}
Confidence: {disease['confidence']}

=== PERMANENT GRAPE KNOWLEDGE ===
{GRAPE_KNOWLEDGE}

=== USER QUESTION ===
{request.query}

=== STRICT RULES ===
1. You are a proactive farm supervisor. Never say "I am an AI" or "I don't know."
2. Always use farm memory to personalize the answer.
3. If disease risk is High or Medium, proactively warn the farmer and recommend exact spray.
4. If you genuinely cannot find the answer in farm data or knowledge, say:
   "I know about your farm and grape cultivation. I don't have the specific answer right now, but I will improve."
5. Be concise. Speak conversationally. No markdown. No asterisks. No bullet points in spoken text.

Return ONLY this exact JSON (no markdown, no code blocks):
{{"response": "Your spoken answer here", "diseaseRisk": "{disease['risk']}", "diseaseName": "{disease['disease']}", "recommendedSpray": "{disease['spray']}"}}
"""

        # Step 4: Gemini Reasoning
        if gemini_model:
            gemini_response = gemini_model.generate_content(prompt)
            raw = gemini_response.text.strip()
            # Strip markdown fences if present
            if raw.startswith("```"):
                raw = raw.split("```")[1]
                if raw.startswith("json"):
                    raw = raw[4:]
            result = json.loads(raw.strip())
            print(f"✅ Gemini responded successfully.")
            return result
        else:
            # Fallback if Gemini key not set
            return {
                "response": f"Hello {farmer_name}. The reasoning engine is starting up. Your farm is at {plot_stage} stage. Please try again in a moment.",
                "diseaseRisk": disease["risk"],
                "diseaseName": disease["disease"],
                "recommendedSpray": disease["spray"],
            }

    except json.JSONDecodeError as je:
        print(f"❌ JSON parse error from Gemini: {je}")
        return {
            "response": "I understood your question but had trouble formatting my answer. Please ask again.",
            "diseaseRisk": "Low",
            "diseaseName": "None",
            "recommendedSpray": "None",
        }
    except Exception as e:
        print(f"❌ Orchestration error: {e}")
        return {
            "response": "I am having trouble reaching the reasoning engine right now. Please check your internet connection and try again.",
            "diseaseRisk": "Low",
            "diseaseName": "None",
            "recommendedSpray": "None",
        }

# ──────────────────────────────────────────────
# Password Reset Endpoint
# ──────────────────────────────────────────────
class ResetPasswordRequest(BaseModel):
    new_password: str

@app.post("/api/v1/auth/reset-password")
async def reset_password(payload: ResetPasswordRequest, authorization: str = Header(None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid Authorization header.")
    id_token = authorization.split("Bearer ")[1]
    if not FIREBASE_ADMIN_ACTIVE:
        return {"success": True, "message": "Mock mode: Password reset validated."}
    try:
        from firebase_admin import auth
        decoded_token = auth.verify_id_token(id_token)
        phone_number = decoded_token.get("phone_number")
        if not phone_number:
            raise HTTPException(status_code=400, detail="Token does not contain a verified phone number.")
        email = f"{phone_number}@dailyfarm.app"
        user = auth.get_user_by_email(email)
        auth.update_user(user.uid, password=payload.new_password)
        return {"success": True, "message": f"Password for {phone_number} updated."}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# ──────────────────────────────────────────────
# OCR Document Extraction (Lightweight Placeholder)
# ──────────────────────────────────────────────
@app.post("/api/v1/extract")
async def extract_document(file: UploadFile = File(...)):
    file_id = str(uuid.uuid4())
    ext = os.path.splitext(file.filename or "file.jpg")[1] or ".jpg"
    temp_path = os.path.join(TEMP_DIR, f"{file_id}{ext}")
    try:
        with open(temp_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        return {
            "success": True,
            "confidence": 0.95,
            "document_type": "invoice",
            "data": {
                "shop_name": "Placeholder - Cloud OCR coming soon",
                "buyer_name": "Farmer",
                "invoice_number": f"INV-{file_id[:6].upper()}",
                "date": "2024-01-01",
                "products": [],
                "total_amount": "0.00"
            },
            "validation_errors": []
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)

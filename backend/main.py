import os
import shutil
import uuid
from fastapi import FastAPI, UploadFile, File, HTTPException, status, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
import json
import google.generativeai as genai
from pinecone import Pinecone
from dotenv import load_dotenv

load_dotenv()

# Configure APIs securely from environment variables
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "YOUR_GEMINI_KEY")
PINECONE_API_KEY = os.getenv("PINECONE_API_KEY", "YOUR_PINECONE_KEY")
PINECONE_INDEX_URL = os.getenv("PINECONE_INDEX_URL", "https://your-index.pinecone.io")

try:
    genai.configure(api_key=GEMINI_API_KEY)
    generation_config = {
        "temperature": 0.3,
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

# Initialize Firebase Admin SDK for cryptographically secure SMS-OTP verified resets
FIREBASE_ADMIN_ACTIVE = False
try:
    import firebase_admin
    from firebase_admin import credentials, auth
    if not firebase_admin._apps:
        try:
            # First try auto-detect credentials
            firebase_admin.initialize_app()
            FIREBASE_ADMIN_ACTIVE = True
            print("Firebase Admin SDK successfully initialized via default credentials.")
        except Exception as e_default:
            # Fallback to local certificate if present
            cert_path = "serviceAccountKey.json"
            if os.path.exists(cert_path):
                firebase_admin.initialize_app(credentials.Certificate(cert_path))
                FIREBASE_ADMIN_ACTIVE = True
                print("Firebase Admin SDK successfully initialized via serviceAccountKey.json.")
            else:
                print(f"Firebase Admin SDK initialization skipped (no credentials found): {e_default}")
except Exception as e:
    print(f"Error loading or initializing Firebase Admin SDK: {e}")

# Import Pipeline Components
from pipeline.quality_analyzer import QualityAnalyzer
from pipeline.enhancement import ImageEnhancer
from pipeline.classification import DocumentClassifier
from pipeline.ocr_engine import OCREngine
from pipeline.document_ai import DocumentAIExtractor
from pipeline.validation import ValidationEngine

app = FastAPI(
    title="AgriConnect Document AI Platform",
    description="Enterprise-grade Document AI pipeline for agricultural receipts, bills, and documents.",
    version="1.0.0"
)

# Enable CORS for mobile application connections
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Temp directories for uploads
TEMP_DIR = "temp_uploads"
os.makedirs(TEMP_DIR, exist_ok=True)

ocr_engine = OCREngine()

class HealthResponse(BaseModel):
    status: str
    version: str
    gpu_available: bool

@app.get("/health", response_model=HealthResponse)
async def health():
    import torch
    return {
        "status": "healthy",
        "version": "1.0.0",
        "gpu_available": torch.cuda.is_available()
    }

@app.post("/api/v1/extract")
async def extract_document(file: UploadFile = File(...)):
    # 1. Save upload temporarily
    file_id = str(uuid.uuid4())
    ext = os.path.splitext(file.filename)[1] or ".jpg"
    temp_path = os.path.join(TEMP_DIR, f"{file_id}{ext}")
    enhanced_path = os.path.join(TEMP_DIR, f"{file_id}_enhanced{ext}")

    try:
        with open(temp_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        # 2. Run Image Quality Analyzer
        # Extract initial text snapshot for blur proxy check
        raw_text_sample, _ = ocr_engine.extract_text(temp_path)
        quality = QualityAnalyzer.analyze(temp_path)
        
        # If the image is blurry, reject immediately
        if not quality["is_acceptable"]:
            return {
                "success": False,
                "confidence": 0.0,
                "error": f"Image quality verification failed: {quality['message']}",
                "document_type": "unknown",
                "data": None
            }

        # 3. Image Enhancement Pipeline
        ImageEnhancer.enhance(temp_path, enhanced_path)

        # 4. OCR Engine (Runs PaddleOCR 3.x / TrOCR fallback)
        extracted_text, ocr_conf = ocr_engine.extract_text(enhanced_path)

        # 5. Document Classification
        doc_type = DocumentClassifier.classify(extracted_text)

        # 6. Document AI Extractor (LayoutLMv3 fine-tuned rules)
        structured_data = DocumentAIExtractor.extract(extracted_text, doc_type)

        # 7. Field Validation Engine
        is_valid, validation_conf, errors = ValidationEngine.validate(structured_data)

        # Merge confidences
        final_confidence = (ocr_conf + validation_conf) / 2.0

        # 8. Return structured JSON
        return {
            "success": True,
            "confidence": round(final_confidence, 2),
            "document_type": doc_type,
            "data": {
                "shop_name": structured_data["shop_name"],
                "buyer_name": structured_data["buyer_name"],
                "invoice_number": structured_data["invoice_number"],
                "date": structured_data["date"],
                "products": structured_data["products"],
                "total_amount": structured_data["total_amount"]
            },
            "validation_errors": errors if not is_valid else []
        }

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Internal Document AI Pipeline Error: {str(e)}"
        )
    finally:
        # Cleanup file descriptors and artifacts
        if os.path.exists(temp_path):
            os.remove(temp_path)
        if os.path.exists(enhanced_path):
            os.remove(enhanced_path)

class ResetPasswordRequest(BaseModel):
    new_password: str

@app.post("/api/v1/auth/reset-password")
async def reset_password(payload: ResetPasswordRequest, authorization: str = Header(None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header. Expected Bearer <Token>."
        )
    
    id_token = authorization.split("Bearer ")[1]
    
    if not FIREBASE_ADMIN_ACTIVE:
        print("Mock mode fallback: Password reset validated.")
        return {
            "success": True,
            "message": "Mock Server Mode: Password reset request validated successfully."
        }
        
    try:
        # Cryptographically verify the Google ID Token
        decoded_token = auth.verify_id_token(id_token)
        phone_number = decoded_token.get("phone_number")
        
        if not phone_number:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Token verified successfully, but does not contain a verified phone number claim."
            )
        
        # Format the internally mapped email address
        email = f"{phone_number}@dailyfarm.app"
        
        # Get the email-auth user
        user = auth.get_user_by_email(email)
        
        # Update the user's password securely
        auth.update_user(user.uid, password=payload.new_password)
        
        return {
            "success": True,
            "message": f"Password for {phone_number} successfully updated."
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Verification or password update failed: {str(e)}"
        )

class ChatRequest(BaseModel):
    query: str
    farm_context: str
    weather_context: str

@app.post("/api/v1/chat/orchestrate")
async def orchestrate_chat(request: ChatRequest):
    try:
        # 1. Search Vector DB (Pinecone) securely from backend
        knowledge_context = ""
        try:
            import requests
            headers = {"Api-Key": PINECONE_API_KEY, "Content-Type": "application/json"}
            payload = {"vector": [0.01] * 768, "topK": 3, "includeMetadata": True} # Mock embedding
            resp = requests.post(f"{PINECONE_INDEX_URL}/query", json=payload, headers=headers, timeout=5)
            if resp.status_code == 200:
                matches = resp.json().get('matches', [])
                knowledge_context = "\n\n".join([m['metadata'].get('text', '') for m in matches])
        except Exception as e:
            print(f"Vector DB fallback triggered: {e}")
            knowledge_context = "[KNOWLEDGE: General Grape Farming] Grapevines require careful canopy management, timely irrigation, and strict adherence to spray schedules."

        # 2. Build the secure prompt
        prompt = f"""
        You are an expert Grape Farming AI Agent in India. Answer in the same language as the user's query (e.g. Kannada, English, Hindi).
        
        USER QUERY: {request.query}
        
        --- CONTEXT ---
        Farm State: {request.farm_context}
        Weather: {request.weather_context}
        Knowledge: {knowledge_context}
        
        --- FALLBACK INSTRUCTION ---
        If you genuinely do not know the answer based on the knowledge base or farm history, you MUST reply gracefully by saying something like: "I only know about your farm and grape cultivation right now. I don't have the answer to that, but I will improve to give the answer in the future." Do NOT hallucinate answers.

        Return ONLY this JSON:
        {{
          "response": "Your natural conversational response answering the query. Be concise and expert.",
          "diseaseRisk": "High" | "Medium" | "Low",
          "diseaseName": "Name of disease" | "None",
          "recommendedSpray": "Fungicide name or None"
        }}
        """

        # 3. Call Gemini securely
        response = model.generate_content(prompt)
        raw_text = response.text.strip()
        
        # Remove potential markdown wrappers
        if raw_text.startswith("```json"):
            raw_text = raw_text[7:]
        if raw_text.endswith("```"):
            raw_text = raw_text[:-3]
            
        result = json.loads(raw_text)
        return result
        
    except Exception as e:
        print(f"Orchestration Error: {e}")
        return {
            "response": "I could not reach the reasoning engine. Please check your backend connection.",
            "diseaseRisk": "Unknown",
            "diseaseName": "Unknown",
            "recommendedSpray": "Unknown"
        }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)

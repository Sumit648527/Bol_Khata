"""
Voice Service - FastAPI Application
Handles speech-to-text transcription and natural language understanding
"""
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
import logging
from typing import Optional

# Load environment variables
load_dotenv()

from app.models import ProcessVoiceResponse, ErrorResponse
from app.services.audio_handler import AudioHandler
from app.services.asr_service import ASRService
from app.services.nlu_service import NLUService
from app.services.translation_service import TranslationService

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Bol-Khata Voice Service",
    description="Voice-first financial ledger - Speech processing service",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize services
audio_handler = AudioHandler()
asr_service = ASRService()
nlu_service = NLUService()
translation_service = TranslationService()


@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "service": "Bol-Khata Voice Service",
        "status": "running",
        "version": "1.0.0"
    }


@app.get("/health")
async def health_check():
    """Detailed health check"""
    return {
        "status": "healthy",
        "services": {
            "audio_handler": "ok",
            "asr_service": "ok",
            "nlu_service": "ok"
        }
    }


@app.post("/process-voice", response_model=ProcessVoiceResponse)
async def process_voice(
    audio: UploadFile = File(..., description="Audio file (WAV/MP3)"),
    language: str = Form(..., description="Language code (hi/ta/bn)"),
    user_id: str = Form(..., description="User ID")
):
    """
    Process voice input and extract transaction details
    
    Flow:
    1. Transcribe audio in original language
    2. Translate to English
    3. Extract entities from English translation
    
    Args:
        audio: Audio file containing transaction speech
        language: Language code (hi=Hindi, gu=Gujarati, ta=Tamil, bn=Bengali)
        user_id: Authenticated user ID
    
    Returns:
        ProcessVoiceResponse with extracted transaction details
    """
    try:
        logger.info(f"Processing voice request for user: {user_id}, language: {language}")
        
        # Step 1: Validate and read audio file
        audio_bytes = await audio_handler.validate_and_read(audio)
        logger.info(f"Audio validated: {len(audio_bytes)} bytes")
        
        # Step 2: Transcribe audio using ASR (in original language)
        transcription_result = await asr_service.transcribe(audio_bytes, language)
        logger.info(f"Original transcription: {transcription_result.text} (confidence: {transcription_result.confidence})")
        
        # Step 3: Translate to English
        english_translation, translation_confidence = await translation_service.translate_to_english(
            transcription_result.text,
            language
        )
        logger.info(f"English translation: {english_translation} (confidence: {translation_confidence})")
        
        # Step 4: Extract entities from English translation
        extraction_result = await nlu_service.extract_entities(english_translation)
        logger.info(f"Extracted: name={extraction_result.name}, amount={extraction_result.amount}, "
                   f"type={extraction_result.transaction_type}, confidence={extraction_result.confidence}")
        
        # Step 5: Save audio temporarily for banking service
        import base64
        audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')
        
        # Step 6: Return response with both original and English
        return ProcessVoiceResponse(
            name=extraction_result.name,
            amount=extraction_result.amount,
            type=extraction_result.transaction_type,
            confidence=extraction_result.confidence * translation_confidence,  # Combined confidence
            transcription=transcription_result.text,  # Original language
            english_translation=english_translation,  # English translation
            audio_data=audio_base64
        )
        
    except ValueError as e:
        logger.error(f"Validation error: {str(e)}")
        raise HTTPException(status_code=400, detail=str(e))
    
    except Exception as e:
        logger.error(f"Error processing voice: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Error processing voice input: {str(e)}"
        )


@app.post("/process-text")
async def process_text(request: dict):
    """
    Process text input directly (for testing without audio)
    
    Args:
        request: {"text": "transaction text", "language": "hi"}
    
    Returns:
        Extracted transaction details
    """
    try:
        text = request.get("text", "")
        language = request.get("language", "hi")
        
        if not text:
            raise HTTPException(status_code=400, detail="Text is required")
        
        logger.info(f"Processing text: {text} (language: {language})")
        
        # If text is not in English, translate it first
        if language != "en":
            english_text, translation_confidence = await translation_service.translate_to_english(text, language)
            logger.info(f"Translated to English: {english_text}")
        else:
            english_text = text
            translation_confidence = 1.0
        
        # Extract entities using NLU (only takes english_text)
        extraction_result = await nlu_service.extract_entities(english_text)
        
        return {
            "name": extraction_result.name,
            "amount": extraction_result.amount,
            "type": extraction_result.transaction_type,
            "confidence": extraction_result.confidence * translation_confidence,
            "transcription": text,
            "english_translation": english_text
        }
        
    except Exception as e:
        logger.error(f"Error processing text: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

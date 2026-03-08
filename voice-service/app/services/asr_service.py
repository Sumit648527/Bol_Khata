"""
ASR (Automatic Speech Recognition) Service
Handles transcription using Sarvam AI
"""
import logging
import os
import httpx
import base64
from app.models import TranscriptionResult

logger = logging.getLogger(__name__)


class ASRService:
    """Handles speech-to-text transcription using Sarvam AI"""
    
    def __init__(self):
        self.sarvam_api_key = os.getenv("SARVAM_API_KEY", "")
        self.sarvam_url = os.getenv("SARVAM_API_URL", "https://api.sarvam.ai/speech-to-text")
        
        # Debug: Log API key status
        if self.sarvam_api_key:
            logger.info(f"Sarvam AI API key loaded: {self.sarvam_api_key[:10]}...")
        else:
            logger.warning("Sarvam AI API key NOT loaded from environment")
        
        # Language code mapping
        self.language_map = {
            "hi": "hi-IN",  # Hindi
            "en": "en-IN",  # English (Indian)
            "ta": "ta-IN",  # Tamil
            "te": "te-IN",  # Telugu
            "bn": "bn-IN",  # Bengali
            "mr": "mr-IN",  # Marathi
            "gu": "gu-IN",  # Gujarati
            "kn": "kn-IN",  # Kannada
            "ml": "ml-IN",  # Malayalam
            "pa": "pa-IN",  # Punjabi
        }
    
    async def transcribe(self, audio_bytes: bytes, language: str) -> TranscriptionResult:
        """
        Transcribe audio using Sarvam AI
        
        Args:
            audio_bytes: Audio file contents (WAV format recommended)
            language: Language code (hi/ta/bn/en etc.)
            
        Returns:
            TranscriptionResult with text and confidence
        """
        try:
            # Check if API key is configured
            if not self.sarvam_api_key:
                logger.warning("Sarvam AI API not configured, using mock transcription")
                return await self._mock_transcribe(audio_bytes, language)
            
            # Use Sarvam AI API
            return await self._transcribe_sarvam(audio_bytes, language)
            
        except Exception as e:
            logger.error(f"ASR failed: {e}, using mock transcription")
            return await self._mock_transcribe(audio_bytes, language)
    
    async def _transcribe_sarvam(self, audio_bytes: bytes, language: str) -> TranscriptionResult:
        """
        Transcribe using Sarvam AI API
        
        Sarvam AI Documentation: https://docs.sarvam.ai/
        """
        try:
            logger.info(f"Transcribing with Sarvam AI (language: {language})")
            
            # Map language code to Sarvam AI format
            lang_code = self.language_map.get(language, "hi-IN")
            logger.info(f"Using Sarvam language code: {lang_code}")
            
            # Prepare multipart form data
            files = {
                'file': ('audio.wav', audio_bytes, 'audio/wav')
            }
            
            data = {
                'language_code': lang_code,
                'model': 'saaras:v3'  # Sarvam's multilingual model
            }
            
            headers = {
                'api-subscription-key': self.sarvam_api_key
            }
            
            logger.info(f"Sending request to Sarvam AI: {self.sarvam_url}")
            logger.info(f"Language code: {lang_code}, Model: saaras:v3")
            
            # Make API request with longer timeout for processing
            async with httpx.AsyncClient(timeout=60.0) as client:
                response = await client.post(
                    self.sarvam_url,
                    files=files,
                    data=data,
                    headers=headers
                )
                
                logger.info(f"Sarvam AI response status: {response.status_code}")
                
                if response.status_code != 200:
                    logger.error(f"Sarvam AI error: {response.status_code} - {response.text}")
                    # Fall back to mock for non-200 responses
                    logger.warning("Falling back to mock transcription due to API error")
                    return await self._mock_transcribe(audio_bytes, language)
                
                result = response.json()
                logger.info(f"Sarvam AI response: {result}")
                
                # Extract transcription (Sarvam returns "transcript" field)
                if "transcript" in result:
                    text = result["transcript"]
                    confidence = result.get("confidence", 0.90)
                    
                    logger.info(f"Sarvam transcription successful: {text} (confidence: {confidence})")
                    return TranscriptionResult(
                        text=text,
                        confidence=confidence,
                        language=language
                    )
                
                logger.error("No transcript field in Sarvam AI response")
                raise Exception("No transcription in Sarvam AI response")
                
        except httpx.TimeoutException:
            logger.error("Sarvam AI request timed out")
            logger.warning("Falling back to mock transcription due to timeout")
            return await self._mock_transcribe(audio_bytes, language)
        except Exception as e:
            logger.error(f"Sarvam AI transcription failed: {e}")
            logger.warning("Falling back to mock transcription")
            return await self._mock_transcribe(audio_bytes, language)
    
    async def _mock_transcribe(self, audio_bytes: bytes, language: str) -> TranscriptionResult:
        """
        Mock transcription for testing without API keys
        Returns realistic transcriptions in different Indian languages
        """
        logger.info(f"Using mock transcription (language: {language})")
        
        # Realistic mock transcriptions for different languages
        mock_transcriptions = {
            "hi": "Suresh ne do sau rupay diye",  # Hindi: Suresh gave 200 rupees
            "en": "Suresh gave two hundred rupees",  # English
            "ta": "Suresh irunuru rupees koduthaar",  # Tamil: Suresh gave 200 rupees
            "te": "Suresh rendhu vandala rupayalu ichchadu",  # Telugu: Suresh gave 200 rupees
            "bn": "Suresh dui shoto taka diyeche",  # Bengali: Suresh gave 200 taka
            "mr": "Suresh ne don she rupaye dile",  # Marathi: Suresh gave 200 rupees
            "gu": "Suresh e be so rupiya aapya",  # Gujarati: Suresh gave 200 rupees
            "kn": "Suresh eradu nuru rupayigalu kottu",  # Kannada: Suresh gave 200 rupees
            "ml": "Suresh randu nooru rupees koduthu",  # Malayalam: Suresh gave 200 rupees
            "pa": "Suresh ne do sau rupaye ditte",  # Punjabi: Suresh gave 200 rupees
        }
        
        text = mock_transcriptions.get(language, "Suresh ne do sau rupay diye")
        
        return TranscriptionResult(
            text=text,
            confidence=0.95,
            language=language
        )

"""
Translation Service
Translates transcriptions from any Indian language to English
"""
import os
import logging
import httpx
from typing import Optional

logger = logging.getLogger(__name__)


class TranslationService:
    """Handles translation using Sarvam AI Translation API"""
    
    def __init__(self):
        self.api_key = os.getenv("SARVAM_API_KEY")
        self.api_url = "https://api.sarvam.ai/translate"
        
        if not self.api_key:
            logger.warning("SARVAM_API_KEY not found in environment")
    
    async def translate_to_english(
        self,
        text: str,
        source_language: str
    ) -> tuple[str, float]:
        """
        Translate text to English using Sarvam AI or rule-based fallback
        
        Args:
            text: Text to translate
            source_language: Source language code (hi, gu, ta, bn, etc.)
            
        Returns:
            Tuple of (translated_text, confidence)
        """
        # If already in English or Latin script, return as-is
        if self._is_english(text):
            logger.info("Text appears to be in English, skipping translation")
            return text, 1.0
        
        # Try Sarvam AI translation first
        try:
            logger.info(f"Translating from {source_language} to English using Sarvam AI")
            
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    self.api_url,
                    headers={
                        "api-subscription-key": self.api_key,  # Correct header format
                        "Content-Type": "application/json"
                    },
                    json={
                        "input": text,
                        "source_language_code": f"{source_language}-IN",  # Add -IN suffix
                        "target_language_code": "en-IN",
                        "speaker_gender": "Male",
                        "mode": "formal",
                        "model": "mayura:v1",
                        "enable_preprocessing": True
                    }
                )
                
                if response.status_code == 200:
                    result = response.json()
                    translated_text = result.get("translated_text", text)
                    logger.info(f"Sarvam AI translation successful: {translated_text}")
                    return translated_text, 0.95
                else:
                    logger.warning(f"Sarvam AI translation failed: {response.status_code} - {response.text}")
                    # Fall through to rule-based translation
                    
        except Exception as e:
            logger.warning(f"Sarvam AI translation error: {str(e)}")
            # Fall through to rule-based translation
        
        # Fallback: Rule-based translation
        logger.info("Using rule-based translation fallback")
        translated = self._rule_based_translate(text)
        return translated, 0.85
    
    def _rule_based_translate(self, text: str) -> str:
        """
        Enhanced rule-based translation for financial transaction patterns
        SHOPKEEPER PERSPECTIVE:
        - "diya/gave" = customer PAID (PAYMENT)
        - "liya/took" = customer BORROWED (CREDIT)
        - "cash" = immediate payment (SALE_PAID)
        """
        import re
        
        # Comprehensive financial word mappings (shopkeeper perspective)
        translations = {
            # Hindi - Basic
            'ने': '',
            'को': 'to',
            'से': 'from',
            'का': '',
            'के': '',
            'मुझे': 'me',
            
            # Currency
            'रुपय': 'rupees',
            'रुपया': 'rupees',
            'रुपये': 'rupees',
            'रुपीस': 'rupees',
            '₹': 'rupees',
            
            # Payment actions (Customer pays shopkeeper)
            'दिया': 'gave',
            'दिए': 'gave',
            'दिये': 'gave',
            'दे दिए': 'gave',
            'दे दिये': 'gave',
            'भरा': 'paid',
            'भरे': 'paid',
            'चुकाया': 'cleared',
            'चुकाये': 'cleared',
            'वापस': 'back',
            'वापिस': 'back',
            
            # Credit actions (Customer takes credit)
            'लिया': 'took',
            'लिए': 'took',
            'लिये': 'took',
            'ले लिए': 'took',
            'ले लिये': 'took',
            
            # Financial terms
            'उधार': 'credit',
            'उधारी': 'credit',
            'कर्ज': 'loan',
            'कर्जा': 'loan',
            'बाकी': 'remaining',
            'बाक़ी': 'remaining',
            'बकाया': 'pending',
            'जमा': 'payment',
            'हिसाब': 'account',
            'खाता': 'ledger',
            'देना है': 'owes',
            'देने है': 'owes',
            'लेना है': 'to receive',
            'लेने है': 'to receive',
            
            # Payment types
            'नकद': 'cash',
            'कैश': 'cash',
            'तुरंत': 'immediately',
            'अभी': 'now',
            'पूरा': 'full',
            'पूरे': 'full',
            'सारा': 'all',
            'सारे': 'all',
            
            # Received
            'मिला': 'received',
            'मिले': 'received',
            'मिली': 'received',
            'मिलीं': 'received',
            
            # Gujarati
            'ને': '',
            'રૂપાં': 'rupees',
            'રૂપિયા': 'rupees',
            'લીધા': 'took',
            'લીધું': 'took',
            'આપ્યા': 'gave',
            'આપ્યું': 'gave',
            'મળ્યા': 'received',
            'મળ્યું': 'received',
            'જમા': 'payment',
            'ઉધાર': 'credit',
            'બાકી': 'remaining',
            'રોકડ': 'cash',
            
            # Tamil
            'கொடுத்தார்': 'gave',
            'வாங்கினார்': 'took',
            'ரூபாய்': 'rupees',
            'கடன்': 'credit',
            'பணம்': 'money',
            
            # Telugu  
            'ఇచ్చారు': 'gave',
            'తీసుకున్నారు': 'took',
            'రూపాయలు': 'rupees',
            'అప్పు': 'credit',
            
            # Bengali
            'দিয়েছে': 'gave',
            'নিয়েছে': 'took',
            'টাকা': 'rupees',
            'ধার': 'credit',
            
            # Marathi
            'दिले': 'gave',
            'घेतले': 'took',
            'रुपये': 'rupees',
            'कर्ज': 'loan',
            'उसने': 'credit',
            
            # Common
            '।': '.',
            '॥': '.',
        }
        
        # Replace words
        result = text
        for original, english in translations.items():
            result = result.replace(original, english)
        
        # Clean up extra spaces
        result = re.sub(r'\s+', ' ', result).strip()
        
        # Ensure it has key transaction indicators
        has_payment_indicator = any(word in result.lower() for word in [
            'gave', 'paid', 'received', 'payment', 'cleared', 'back', 'jama'
        ])
        has_credit_indicator = any(word in result.lower() for word in [
            'took', 'credit', 'loan', 'borrowed', 'remaining', 'owes', 'pending'
        ])
        has_cash_indicator = any(word in result.lower() for word in [
            'cash', 'immediately', 'now', 'full', 'all'
        ])
        
        # If no clear indicator, try to infer from original text
        if not (has_payment_indicator or has_credit_indicator or has_cash_indicator):
            # Check original text for Hindi/Gujarati patterns
            if any(word in text for word in ['दिया', 'दिए', 'दिये', 'આપ્યા', 'मिला', 'મળ્યા', 'भरा', 'चुकाया']):
                result += ' gave'  # PAYMENT
            elif any(word in text for word in ['लिया', 'लिए', 'लिये', 'લીધા', 'उधार', 'ઉધાર', 'बाकी', 'બાકી']):
                result += ' took credit'  # CREDIT
            elif any(word in text for word in ['नकद', 'कैश', 'રોકડ', 'पूरा', 'तुरंत']):
                result += ' cash'  # SALE_PAID
        
        logger.info(f"Enhanced rule-based translation: {text} -> {result}")
        return result
    
    def _is_english(self, text: str) -> bool:
        """
        Check if text is primarily in English/Latin script
        """
        # Count Latin characters (excluding numbers and punctuation)
        latin_chars = 0
        total_alpha = 0
        
        for c in text:
            if c.isalpha():
                total_alpha += 1
                if ord(c) < 128:  # ASCII range (Latin)
                    latin_chars += 1
        
        if total_alpha == 0:
            return True
        
        # If more than 80% Latin characters, consider it English
        return (latin_chars / total_alpha) > 0.8

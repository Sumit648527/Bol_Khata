"""
NLU (Natural Language Understanding) Service
Extracts entities from ENGLISH translations only
"""
import re
import logging
from typing import Optional
from app.models import EntityExtractionResult

logger = logging.getLogger(__name__)


class NLUService:
    """Handles entity extraction from English text"""
    
    def __init__(self):
        # SHOPKEEPER PERSPECTIVE - Three Transaction Types:
        # SALE_PAID = Customer bought and paid immediately (cash diya, paid in full)
        # SALE_CREDIT = Customer took goods on credit (increases customer's debt)
        # PAYMENT_RECEIVED = Customer paid back previous credit (reduces customer's debt)
        
        # SALE_PAID patterns - immediate payment
        self.sale_paid_patterns = [
            # Cash payment variations
            r"([A-Za-z]+)\s+(?:ne|ko)?\s*(?:₹)?(\d+)\s+(?:rupees?|rs\.?|rupay|rupaye)\s+(?:cash|nakad|turant|abhi)\s+(?:diye|diya|de\s+diye|paid)",
            r"([A-Za-z]+)\s+(?:paid|diye|diya)\s+(?:₹)?(\d+)\s+(?:rupees?|rs\.?|rupay|rupaye)\s+(?:cash|nakad|immediately|turant|abhi)",
            # Full payment
            r"([A-Za-z]+)\s+(?:ne)?\s*(?:₹)?(\d+)\s+(?:rupees?|rs\.?|rupay|rupaye)\s+(?:poora|pura|full|completely|saara)\s+(?:diye|diya|paid)",
            # Bought and paid
            r"([A-Za-z]+)\s+(?:bought|purchased|ne|liya)\s+(?:₹)?(\d+)\s+(?:rupees?|rs\.?|rupay|rupaye)\s+(?:ka|worth)?\s*(?:and\s+)?(?:paid|diye|cash)",
            # Sold with cash
            r"sold\s+(?:₹)?(\d+)\s+(?:rupees?|rs\.?|rupay|rupaye)\s+(?:to|ko)\s+([A-Za-z]+)\s+(?:cash|nakad|paid)",
            # Simple cash pattern
            r"([A-Za-z]+)\s+(?:₹)?(\d+)\s+(?:rupees?|rs\.?|rupay|rupaye)\s+cash",
        ]
        
        # SALE_CREDIT patterns - credit sale (udhaar)
        self.credit_patterns = [
            # Udhaar/Credit variations
            r"([A-Za-z]+)\s+(?:ne|ko)?\s*(?:₹)?(\d+)\s+(?:rupees?|rs\.?|rupay|rupaye)\s+(?:ka)?\s*(?:udhaar|udhar|credit|loan|karza)\s+(?:liye|liya|le\s+liye)?",
            r"([A-Za-z]+)\s+(?:ne)?\s*(?:₹)?(\d+)\s+(?:rupees?|rs\.?|rupay|rupaye)\s+(?:udhaar|udhar|credit)\s+(?:pe|par|on)\s+(?:liye|liya)",
            # Took/borrowed
            r"([A-Za-z]+)\s+(?:ne)?\s*(?:took|taken|borrowed|got|liye|liya|le\s+liye)\s+(?:₹)?(\d+)\s+(?:rupees?|rs\.?|rupay|rupaye)",
            # Gave credit
            r"gave\s+([A-Za-z]+)\s+(?:₹)?(\d+)\s+(?:rupees?|rs\.?|rupay|rupaye)\s+(?:credit|udhaar|udhar|loan)?",
            # Baaki/remaining
            r"([A-Za-z]+)\s+(?:ka|ke)?\s*(?:₹)?(\d+)\s+(?:rupees?|rs\.?|rupay|rupaye)\s+(?:baaki|baki|remaining|pending)",
            # Dena hai (owes)
            r"([A-Za-z]+)\s+(?:ko|ne)?\s*(?:₹)?(\d+)\s+(?:rupees?|rs\.?|rupay|rupaye)\s+(?:dena|dene)\s+(?:hai|hain|he)",
        ]
        
        # PAYMENT_RECEIVED patterns - payment of previous credit
        self.payment_patterns = [
            # Gave/paid back
            r"([A-Za-z]+)\s+(?:ne)?\s*(?:gave|paid|returned|diye|diya|de\s+diye)\s+(?:me\s+)?(?:₹)?(\d+)\s+(?:rupees?|rs\.?|rupay|rupaye)",
            # Received from
            r"received\s+(?:₹)?(\d+)\s+(?:rupees?|rs\.?|rupay|rupaye)\s+from\s+([A-Za-z]+)",
            r"([A-Za-z]+)\s+(?:se)?\s*(?:₹)?(\d+)\s+(?:rupees?|rs\.?|rupay|rupaye)\s+(?:mila|mile|mili|received)",
            # Payment/jama
            r"([A-Za-z]+)\s+(?:ne)?\s*(?:₹)?(\d+)\s+(?:rupees?|rs\.?|rupay|rupaye)\s+(?:payment|paid|jama|bhara)\s+(?:kiye|kiya|diye)?",
            # Cleared/settled
            r"([A-Za-z]+)\s+(?:ne)?\s*(?:₹)?(\d+)\s+(?:rupees?|rs\.?|rupay|rupaye)\s+(?:clear|cleared|settle|settled|chukaye|chukaya)",
            # Wapas diye (returned)
            r"([A-Za-z]+)\s+(?:ne)?\s*(?:₹)?(\d+)\s+(?:rupees?|rs\.?|rupay|rupaye)\s+(?:wapas|vapas|back)\s+(?:diye|diya|kiye)",
        ]
        
        # Enhanced keywords for fallback (shopkeeper perspective)
        self.sale_paid_keywords = [
            "cash", "nakad", "paid in full", "immediately", "turant", "abhi",
            "cash diya", "de diye", "poora", "pura", "full payment", "saara"
        ]
        
        self.credit_keywords = [
            "credit", "loan", "borrowed", "took", "udhaar", "udhar", "udhaar", 
            "liye", "liya", "karza", "baaki", "baki", "remaining", "pending",
            "dena hai", "dene hai", "owes", "khata"
        ]
        
        self.payment_keywords = [
            "gave", "paid", "payment", "returned", "received", "diya", "diye",
            "jama", "mila", "mile", "clear", "cleared", "settle", "settled",
            "wapas", "vapas", "back", "bhara", "chukaye", "chukaya"
        ]
    
    async def extract_entities(
        self,
        english_text: str
    ) -> EntityExtractionResult:
        """
        Extract entities from English translation
        
        Args:
            english_text: English translated text
            
        Returns:
            EntityExtractionResult with name, amount, type, confidence
        """
        # Try regex patterns first
        result = self._extract_with_regex(english_text)
        if result:
            logger.info("Entities extracted using regex patterns")
            return result
        
        # Fallback to keyword-based extraction
        result = self._extract_with_keywords(english_text)
        if result:
            logger.info("Entities extracted using keywords")
            return result
        
        # All methods failed
        raise ValueError("Could not extract transaction details from English translation")
    
    def _extract_with_regex(self, text: str) -> Optional[EntityExtractionResult]:
        """
        Extract entities using English regex patterns
        """
        text_lower = text.lower()
        
        # Try SALE_PAID patterns first (immediate payment)
        for pattern in self.sale_paid_patterns:
            match = re.search(pattern, text_lower, re.IGNORECASE)
            if match:
                groups = match.groups()
                if len(groups) == 2:
                    # Check which group is the name (non-digit)
                    if groups[0].isdigit():
                        amount = float(groups[0])
                        name = groups[1].capitalize()
                    else:
                        name = groups[0].capitalize()
                        amount = float(groups[1])
                    
                    return EntityExtractionResult(
                        name=name,
                        amount=amount,
                        transaction_type="SALE_PAID",
                        confidence=0.95
                    )
        
        # Try SALE_CREDIT patterns
        for pattern in self.credit_patterns:
            match = re.search(pattern, text_lower, re.IGNORECASE)
            if match:
                # Handle different group orders
                groups = match.groups()
                if len(groups) == 2:
                    # Check which group is the name (non-digit)
                    if groups[0].isdigit():
                        amount = float(groups[0])
                        name = groups[1].capitalize()
                    else:
                        name = groups[0].capitalize()
                        amount = float(groups[1])
                    
                    return EntityExtractionResult(
                        name=name,
                        amount=amount,
                        transaction_type="SALE_CREDIT",
                        confidence=0.95
                    )
        
        # Try PAYMENT_RECEIVED patterns
        for pattern in self.payment_patterns:
            match = re.search(pattern, text_lower, re.IGNORECASE)
            if match:
                groups = match.groups()
                if len(groups) == 2:
                    # Check which group is the name
                    if groups[0].isdigit():
                        amount = float(groups[0])
                        name = groups[1].capitalize()
                    else:
                        name = groups[0].capitalize()
                        amount = float(groups[1])
                    
                    return EntityExtractionResult(
                        name=name,
                        amount=amount,
                        transaction_type="PAYMENT_RECEIVED",
                        confidence=0.95
                    )
        
        return None
    
    def _extract_with_keywords(self, text: str) -> Optional[EntityExtractionResult]:
        """
        Extract entities using keyword-based approach
        """
        words = text.split()
        text_lower = text.lower()
        
        # Extract amount
        amount = None
        for word in words:
            digits = re.search(r'\d+', word)
            if digits:
                amount = float(digits.group())
                break
        
        if not amount:
            return None
        
        # Extract name (first capitalized word that's not a keyword)
        name = None
        skip_words = ['i', 'me', 'my', 'gave', 'received', 'from', 'to', 'the', 'a', 'an']
        
        for word in words:
            word_clean = word.strip('.,!?')
            if word_clean.lower() in skip_words:
                continue
            if any(kw in word_clean.lower() for kw in self.sale_paid_keywords + self.credit_keywords + self.payment_keywords):
                continue
            if re.search(r'\d', word_clean):
                continue
            if word_clean and word_clean[0].isupper():
                name = word_clean
                break
        
        if not name:
            # Try to find any word that looks like a name
            for word in words:
                word_clean = word.strip('.,!?')
                if len(word_clean) > 2 and word_clean.isalpha():
                    name = word_clean.capitalize()
                    break
        
        if not name:
            name = "Customer"
        
        # Determine transaction type (check SALE_PAID first, then others)
        has_sale_paid = any(kw in text_lower for kw in self.sale_paid_keywords)
        has_credit = any(kw in text_lower for kw in self.credit_keywords)
        has_payment = any(kw in text_lower for kw in self.payment_keywords)
        
        if has_sale_paid:
            transaction_type = "SALE_PAID"
        elif has_payment:
            transaction_type = "PAYMENT_RECEIVED"
        elif has_credit:
            transaction_type = "SALE_CREDIT"
        else:
            return None
        
        return EntityExtractionResult(
            name=name,
            amount=amount,
            transaction_type=transaction_type,
            confidence=0.80
        )

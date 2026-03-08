"""
Data models for Voice Service
"""
from pydantic import BaseModel, Field
from typing import Optional


class TranscriptionResult(BaseModel):
    """Result from ASR service"""
    text: str = Field(..., description="Transcribed text")
    confidence: float = Field(..., ge=0.0, le=1.0, description="Confidence score")
    language: str = Field(..., description="Language code")


class EntityExtractionResult(BaseModel):
    """Result from NLU entity extraction"""
    name: str = Field(..., description="Customer name")
    amount: float = Field(..., gt=0, description="Transaction amount")
    transaction_type: str = Field(..., description="CREDIT or PAYMENT")
    confidence: float = Field(..., ge=0.0, le=1.0, description="Extraction confidence")


class ProcessVoiceResponse(BaseModel):
    """Response from /process-voice endpoint"""
    name: str = Field(..., description="Extracted customer name")
    amount: float = Field(..., description="Transaction amount")
    type: str = Field(..., description="Transaction type (CREDIT/PAYMENT)")
    confidence: float = Field(..., description="Overall confidence score")
    transcription: str = Field(..., description="Original transcribed text")
    english_translation: str = Field(..., description="English translation of transcription")
    audio_data: Optional[str] = Field(None, description="Base64 encoded audio data")


class ErrorResponse(BaseModel):
    """Error response model"""
    error: str = Field(..., description="Error message")
    detail: Optional[str] = Field(None, description="Detailed error information")

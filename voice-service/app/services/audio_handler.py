"""
Audio Handler Service
Validates and processes audio files
"""
from fastapi import UploadFile
import logging

logger = logging.getLogger(__name__)

ALLOWED_FORMATS = ["audio/wav", "audio/mpeg", "audio/mp3"]
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB


class AudioHandler:
    """Handles audio file validation and processing"""
    
    async def validate_and_read(self, file: UploadFile) -> bytes:
        """
        Validate audio file format and size, then read contents
        
        Args:
            file: Uploaded audio file
            
        Returns:
            Audio file contents as bytes
            
        Raises:
            ValueError: If file format or size is invalid
        """
        # Check content type
        if file.content_type not in ALLOWED_FORMATS:
            raise ValueError(
                f"Unsupported audio format: {file.content_type}. "
                f"Supported formats: {', '.join(ALLOWED_FORMATS)}"
            )
        
        # Read file contents
        audio_bytes = await file.read()
        
        # Check file size
        if len(audio_bytes) == 0:
            raise ValueError("Empty audio file")
        
        if len(audio_bytes) > MAX_FILE_SIZE:
            raise ValueError(
                f"Audio file too large: {len(audio_bytes)} bytes. "
                f"Maximum size: {MAX_FILE_SIZE} bytes"
            )
        
        logger.info(f"Audio file validated: {file.filename}, "
                   f"type: {file.content_type}, size: {len(audio_bytes)} bytes")
        
        return audio_bytes

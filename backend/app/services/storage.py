import os
import uuid
import logging
import asyncio
import tempfile
from typing import Optional
from app.core.settings import settings

logger = logging.getLogger(__name__)

class StorageService:
    """
    Service wrapper for Google Cloud Storage.
    Offloads synchronous GCS blocking operations to worker threads via asyncio.to_thread.
    Enforces GCS bucket configuration in production; falls back to local temp folder in development/testing.
    """
    def __init__(self, bucket_name: Optional[str] = None) -> None:
        self.bucket_name = bucket_name or settings.GCS_BUCKET_NAME
        self.is_production = not settings.DEBUG
        
        if not self.bucket_name:
            if self.is_production:
                logger.error("GCS_BUCKET_NAME is not set, but DEBUG=False (Production/Staging). Application startup failed.")
                raise ValueError("GCS_BUCKET_NAME environment variable is required in production.")
            else:
                # Local development/testing fallback directory
                self.local_fallback_dir = os.path.join(tempfile.gettempdir(), "edupulse_mock_storage")
                os.makedirs(self.local_fallback_dir, exist_ok=True)
                logger.warning(
                    f"GCS_BUCKET_NAME is not configured. Falling back to local temporary directory: {self.local_fallback_dir}"
                )
                self.client = None
        else:
            from google.cloud import storage
            # GCS Client is loaded in production
            self.client = storage.Client()
            logger.info(f"Initialized Google Cloud Storage service with bucket: {self.bucket_name}")

    async def upload(self, contents: bytes, path: str, content_type: str) -> None:
        """
        Uploads file bytes to storage path.
        """
        if self.client:
            def _sync_upload():
                bucket = self.client.bucket(self.bucket_name)
                blob = bucket.blob(path)
                blob.upload_from_string(contents, content_type=content_type)
            await asyncio.to_thread(_sync_upload)
        else:
            # Local fallback for dev/test
            def _local_upload():
                full_path = os.path.join(self.local_fallback_dir, path)
                os.makedirs(os.path.dirname(full_path), exist_ok=True)
                with open(full_path, "wb") as f:
                    f.write(contents)
            await asyncio.to_thread(_local_upload)

    async def download(self, path: str) -> bytes:
        """
        Downloads and returns file bytes from storage path.
        """
        if self.client:
            def _sync_download():
                bucket = self.client.bucket(self.bucket_name)
                blob = bucket.blob(path)
                if not blob.exists():
                    raise FileNotFoundError(f"Object '{path}' not found in GCS bucket '{self.bucket_name}'.")
                return blob.download_as_bytes()
            return await asyncio.to_thread(_sync_download)
        else:
            # Local fallback for dev/test
            def _local_download():
                full_path = os.path.join(self.local_fallback_dir, path)
                if not os.path.exists(full_path):
                    raise FileNotFoundError(f"Local mock storage file not found: {full_path}")
                with open(full_path, "rb") as f:
                    return f.read()
            return await asyncio.to_thread(_local_download)

    async def delete(self, path: str) -> None:
        """
        Deletes object at storage path.
        """
        if self.client:
            def _sync_delete():
                bucket = self.client.bucket(self.bucket_name)
                blob = bucket.blob(path)
                if blob.exists():
                    blob.delete()
            await asyncio.to_thread(_sync_delete)
        else:
            # Local fallback for dev/test
            def _local_delete():
                full_path = os.path.join(self.local_fallback_dir, path)
                if os.path.exists(full_path):
                    os.remove(full_path)
            await asyncio.to_thread(_local_delete)

    async def exists(self, path: str) -> bool:
        """
        Checks if object exists at storage path.
        """
        if self.client:
            def _sync_exists():
                bucket = self.client.bucket(self.bucket_name)
                blob = bucket.blob(path)
                return blob.exists()
            return await asyncio.to_thread(_sync_exists)
        else:
            # Local fallback for dev/test
            def _local_exists():
                full_path = os.path.join(self.local_fallback_dir, path)
                return os.path.exists(full_path)
            return await asyncio.to_thread(_local_exists)

    def download_sync(self, path: str) -> bytes:
        """
        Synchronously downloads file bytes.
        """
        if self.client:
            bucket = self.client.bucket(self.bucket_name)
            blob = bucket.blob(path)
            if not blob.exists():
                raise FileNotFoundError(f"Object '{path}' not found in GCS bucket '{self.bucket_name}'.")
            return blob.download_as_bytes()
        else:
            full_path = os.path.join(self.local_fallback_dir, path)
            if not os.path.exists(full_path):
                raise FileNotFoundError(f"Local mock storage file not found: {full_path}")
            with open(full_path, "rb") as f:
                return f.read()

_storage_service_instance = None

def get_storage_service() -> StorageService:
    """
    Dependency provider yielding the StorageService singleton.
    """
    global _storage_service_instance
    if _storage_service_instance is None:
        _storage_service_instance = StorageService()
    return _storage_service_instance

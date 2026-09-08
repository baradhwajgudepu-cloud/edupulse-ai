"""
Canonical Normalization Helpers for EduPulse AI
Provides deterministic normalization for subject column headers and student identification.
"""

import re
from typing import Optional


def normalize_subject_header(header: Optional[str]) -> str:
    """
    Normalizes a subject column header from spreadsheets into a clean, canonical key.
    Handles variations like:
      Mathematics, MATHEMATICS,  mathematics
      Mathematics (Max 100), Mathematics (MAX 100), Mathematics(Max 100)
      Mathematics - Max 100, Mathematics - Max: 100
      Science - Max 50, English (Max. 100), Social Studies [100]
    """
    if header is None:
        return ""
    text = str(header).strip()
    if not text:
        return ""

    # 1. Remove bracketed / parenthesized max marks patterns:
    # e.g. (Max 100), (MAX: 100), (100 Marks), [Max 50], {Max 100}, (100), [100]
    text = re.sub(
        r'[\(\[\{]\s*(?:max\.?|maximum)?\s*(?:marks?)?\s*:?\s*\d+(?:\.\d+)?\s*(?:marks?|pts?|points)?\s*[\)\]\}]',
        '',
        text,
        flags=re.IGNORECASE
    )

    # 2. Remove trailing / attached max marks patterns like ' - Max 100', ' - Max: 100', ' Max 100', ': Max 100', '/ 100'
    text = re.sub(
        r'[\s\-_:/|]+\b(?:max\.?|maximum)\s*(?:marks?)?\s*:?\s*\d+(?:\.\d+)?\b.*$',
        '',
        text,
        flags=re.IGNORECASE
    )
    text = re.sub(
        r'[\s\-_:/|]+\d+(?:\.\d+)?\s*(?:marks?|pts?|points)\b.*$',
        '',
        text,
        flags=re.IGNORECASE
    )

    # 3. Strip any remaining empty brackets/parentheses
    text = re.sub(r'[\(\[\{]\s*[\)\]\}]', '', text)

    # 4. Collapse repeated whitespace and convert to lowercase
    text = re.sub(r'\s+', ' ', text).strip().lower()

    # 5. Remove all non-alphanumeric characters for canonical alphanumeric comparison
    cleaned = re.sub(r'[^a-z0-9]', '', text)
    return cleaned


def format_subject_header(subject_name: str, max_marks: float) -> str:
    """
    Standardized header generation for subject columns in export/template workbooks.
    Example: 'Mathematics (Max 100)' or 'Science (Max 50)'
    """
    clean_name = str(subject_name or 'Subject').strip()
    marks_str = str(int(max_marks)) if max_marks == int(max_marks) else str(max_marks)
    return f"{clean_name} (Max {marks_str})"

"""
stride_register.md Test Suite
Execution: pytest tests/test_threat_model.py -v
"""

from pathlib import Path
import pytest

# Path to your ASCII/Markdown Threat Register
REGISTER_PATH = Path("docs/threat-model/STRIDE_REGISTER.md")

# Required STRIDE Category Identifiers
STRIDE_CODES = ["S —", "T —", "R —", "I —", "D —", "E —"]

def test_register_file_exists():
    """Requirement: STRIDE_REGISTER.md must exist in the docs folder."""
    assert REGISTER_PATH.exists(), (
        f"Critical Failure: {REGISTER_PATH} not found. "
        "You must create docs/threat-model/STRIDE_REGISTER.md "
        "and document at least one threat per STRIDE category."
    )

def test_register_has_content():
    """Requirement: Register must contain actual data rows (excluding headers/separators)."""
    text = REGISTER_PATH.read_text()
    
    # Filter for lines that look like table rows but aren't headers or separators
    data_rows = [
        line for line in text.splitlines() 
        if line.strip().startswith("|") 
        and "---" not in line 
        and "Week" not in line
    ]
    
    assert len(data_rows) >= 6, (
        f"Security Gap: Expected at least 6 threat rows, but found {len(data_rows)}. "
        "Ensure every STRIDE category is addressed."
    )

@pytest.mark.parametrize("code", STRIDE_CODES)
def test_each_stride_category_present(code):
    """Requirement: Every single letter of STRIDE must be represented in the document."""
    text = REGISTER_PATH.read_text()
    assert code in text, (
        f"Missing Category: STRIDE category '{code}' not found in {REGISTER_PATH}. "
        "Add a documented threat for this category to pass the CI gate."
    )

def test_minimum_row_count_grows_each_week():
    """
    Requirement: The register must grow as the project complexity increases.
    
    Target Progression:
    - Week 1: Minimum 6 rows
    - Week 2: Minimum 12 rows
    - Week 3: Minimum 18 rows
    
    Current Target (Week 1): 6
    """
    text = REGISTER_PATH.read_text()
    count = sum(
        1 for line in text.splitlines() 
        if line.strip().startswith("|") 
        and "---" not in line 
        and "Week" not in line
    )
    
    # Update this value as you progress through your 16-week roadmap
    WEEK_1_MINIMUM = 6
    assert count >= WEEK_1_MINIMUM, f"Audit Failure: Expected >= {WEEK_1_MINIMUM} rows, found {count}."
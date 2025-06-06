# software/assembler/test/conftest.py
import pytest
import os
from pathlib import Path # <--- ADD THIS IMPORT

# Example of a fixture if needed later:
# @pytest.fixture
# def sample_fixture():
#     return "sample_value"

# Fixture to provide the base directory for test files
@pytest.fixture
def test_files_dir():
    # Use Path for modern path manipulation
    base_dir = Path(os.path.dirname(__file__)) # Path object for the directory of conftest.py
    return base_dir / "test_files"           # Use / operator to join, returns a Path object
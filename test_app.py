import os
import pytest
from unittest.mock import patch, MagicMock

import tempfile
import db
import ai

@pytest.fixture(autouse=True)
def setup_db():
    # Use a temporary file for the DB
    temp_db = tempfile.NamedTemporaryFile(delete=False)
    temp_db.close()

    db.DB_PATH = temp_db.name
    db.init_db()
    yield

    # Cleanup
    os.unlink(temp_db.name)

def test_db_settings():
    db.set_api_key('test_key_123')
    assert db.get_api_key() == 'test_key_123'

    db.set_api_key('new_key_456')
    assert db.get_api_key() == 'new_key_456'

def test_db_history():
    assert len(db.get_history()) == 0

    db.add_history("Challenge 1", "Solution 1")
    history = db.get_history()

    assert len(history) == 1
    assert history[0]['challenge'] == "Challenge 1"
    assert history[0]['solution'] == "Solution 1"

    db.add_history("Challenge 2", "Solution 2")
    history = db.get_history()
    assert len(history) == 2

    # Delete the first one
    db.delete_history(history[0]['id'])
    history_after_delete = db.get_history()
    assert len(history_after_delete) == 1

@patch('ai.genai.GenerativeModel')
@patch('ai.genai.configure')
def test_generate_challenge(mock_configure, mock_model_class):
    # Setup mock
    mock_model_instance = MagicMock()
    mock_response = MagicMock()
    mock_response.text = "Mocked Challenge Text"
    mock_model_instance.generate_content.return_value = mock_response
    mock_model_class.return_value = mock_model_instance

    # Call function
    api_key = "fake_api_key"
    result = ai.generate_challenge(api_key)

    # Assertions
    mock_configure.assert_called_once_with(api_key=api_key)
    mock_model_class.assert_called_once_with('gemini-1.5-flash')
    mock_model_instance.generate_content.assert_called_once()
    assert result == "Mocked Challenge Text"

def test_generate_challenge_no_key():
    with pytest.raises(ValueError, match="API Key is missing."):
        ai.generate_challenge("")

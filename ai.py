import google.generativeai as genai

PROMPT = """
You are an expert business consultant. Generate a complex, realistic business case challenge for a user to solve.
The case should involve a fictional company facing a strategic, operational, or financial dilemma.
Provide enough context and data (can be qualitative or quantitative) for the user to formulate a detailed solution.
Keep the challenge concise but detailed enough to be engaging (around 200-300 words).
Format the output with a clear title, background, and the specific problem statement.
"""

def generate_challenge(api_key: str) -> str:
    """Generates a business challenge using Google's Generative AI."""
    if not api_key:
        raise ValueError("API Key is missing.")

    genai.configure(api_key=api_key)

    try:
        model = genai.GenerativeModel('gemini-1.5-flash')
        response = model.generate_content(PROMPT)
        return response.text
    except Exception as e:
        raise Exception(f"Failed to generate challenge: {str(e)}")

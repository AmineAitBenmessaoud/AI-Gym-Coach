"""Test script to list available Gemini models"""
from dotenv import load_dotenv
import os
import google.generativeai as genai

# Load environment variables
basedir = os.path.abspath(os.path.dirname(__file__))
load_dotenv(os.path.join(basedir, '.env'))

# Configure API
api_key = os.getenv('GEMINI_API_KEY')
print(f"API Key loaded: {api_key[:10]}...{api_key[-4:] if api_key else 'NOT FOUND'}")

if not api_key:
    print("ERROR: GEMINI_API_KEY not found in environment!")
    exit(1)

genai.configure(api_key=api_key)

print("\n" + "="*60)
print("Available Gemini Models:")
print("="*60)

try:
    for model in genai.list_models():
        if 'generateContent' in model.supported_generation_methods:
            print(f"\n✓ {model.name}")
            print(f"  Display Name: {model.display_name}")
            print(f"  Description: {model.description}")
            print(f"  Supported Methods: {', '.join(model.supported_generation_methods)}")
except Exception as e:
    print(f"\nERROR: {str(e)}")
    print("\nThis could mean:")
    print("1. Invalid API key")
    print("2. API key doesn't have proper permissions")
    print("3. Network/firewall issue")
    print("\nVerify your API key at: https://aistudio.google.com/app/apikey")

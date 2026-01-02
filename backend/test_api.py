"""
Test script for AI Gym Coach Backend
Run this to test the API endpoints
"""

import requests
import json

BASE_URL = "http://localhost:5000"

def test_health():
    """Test health endpoint"""
    print("\n" + "="*50)
    print("Testing /health endpoint...")
    print("="*50)
    
    try:
        response = requests.get(f"{BASE_URL}/health")
        print(f"Status Code: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        return response.status_code == 200
    except Exception as e:
        print(f"Error: {e}")
        return False


def test_analyze_poses():
    """Test pose analysis endpoint"""
    print("\n" + "="*50)
    print("Testing /analyze-poses endpoint...")
    print("="*50)
    
    # Sample pose data (squat position)
    test_data = {
        "poses": [
            {
                "landmarks": {
                    "nose": {"x": 320, "y": 100, "z": 0, "confidence": 0.95},
                    "leftShoulder": {"x": 280, "y": 180, "z": 0, "confidence": 0.92},
                    "rightShoulder": {"x": 360, "y": 180, "z": 0, "confidence": 0.93},
                    "leftHip": {"x": 290, "y": 320, "z": 0, "confidence": 0.91},
                    "rightHip": {"x": 350, "y": 320, "z": 0, "confidence": 0.90},
                    "leftKnee": {"x": 280, "y": 450, "z": 0, "confidence": 0.88},
                    "rightKnee": {"x": 360, "y": 450, "z": 0, "confidence": 0.89},
                    "leftAnkle": {"x": 270, "y": 580, "z": 0, "confidence": 0.85},
                    "rightAnkle": {"x": 370, "y": 580, "z": 0, "confidence": 0.86}
                }
            }
        ],
        "exercise": "squat"
    }
    
    try:
        response = requests.post(
            f"{BASE_URL}/analyze-poses",
            json=test_data,
            headers={'Content-Type': 'application/json'}
        )
        print(f"Status Code: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        return response.status_code == 200
    except Exception as e:
        print(f"Error: {e}")
        return False


def test_real_time_feedback():
    """Test real-time feedback endpoint"""
    print("\n" + "="*50)
    print("Testing /real-time-feedback endpoint...")
    print("="*50)
    
    test_data = {
        "poses": [
            {
                "landmarks": {
                    "leftShoulder": {"x": 280, "y": 180, "z": 0, "confidence": 0.92},
                    "rightShoulder": {"x": 360, "y": 180, "z": 0, "confidence": 0.93},
                    "leftHip": {"x": 290, "y": 320, "z": 0, "confidence": 0.91},
                    "rightHip": {"x": 350, "y": 320, "z": 0, "confidence": 0.90}
                }
            }
        ],
        "exercise": "plank"
    }
    
    try:
        response = requests.post(
            f"{BASE_URL}/real-time-feedback",
            json=test_data,
            headers={'Content-Type': 'application/json'}
        )
        print(f"Status Code: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        return response.status_code == 200
    except Exception as e:
        print(f"Error: {e}")
        return False


if __name__ == "__main__":
    print("\n" + "="*50)
    print("AI GYM COACH BACKEND TEST SUITE")
    print("="*50)
    print(f"Testing backend at: {BASE_URL}")
    
    results = {
        "Health Check": test_health(),
        "Analyze Poses": test_analyze_poses(),
        "Real-time Feedback": test_real_time_feedback()
    }
    
    print("\n" + "="*50)
    print("TEST RESULTS SUMMARY")
    print("="*50)
    
    for test_name, passed in results.items():
        status = "✓ PASSED" if passed else "✗ FAILED"
        print(f"{test_name}: {status}")
    
    all_passed = all(results.values())
    print("\n" + "="*50)
    if all_passed:
        print("🎉 ALL TESTS PASSED!")
    else:
        print("⚠️  SOME TESTS FAILED")
    print("="*50 + "\n")

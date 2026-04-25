import requests
import redis
import os
import time

API_URL = "http://localhost:8000/api/upload"
REDIS_URL = os.getenv("REDIS_URL", "redis://default:kzCqjkZEEp79AyqjmP3oOivR8L68BsnS@redis-13872.c289.us-west-1-2.ec2.cloud.redislabs.com:13872")

def test_api():
    # Wait a bit for the server to start
    time.sleep(2)
    
    # 1. Send request
    payload = {
        "isbn": "1234567890123",
        "cloudinary_url": "https://res.cloudinary.com/demo/image/upload/sample.glb"
    }
    print(f"Sending POST to {API_URL} with payload: {payload}")
    try:
        response = requests.post(API_URL, json=payload)
        print(f"Response Status: {response.status_code}")
        print(f"Response JSON: {response.json()}")
    except Exception as e:
        print(f"Error making request: {e}")
        return

    # 2. Check redis directly
    print("\nChecking Redis directly...")
    try:
        r = redis.from_url(REDIS_URL, decode_responses=True)
        val = r.get("ISBN:1234567890123")
        print(f"Value in Redis for 'ISBN:1234567890123': {val}")
        if val == payload["cloudinary_url"]:
            print("SUCCESS! Data correctly stored in Redis via FastAPI.")
        else:
            print("FAILED! Data in Redis doesn't match.")
        
        # Cleanup
        r.delete("ISBN:1234567890123")
    except Exception as e:
        print(f"Error checking redis: {e}")

if __name__ == "__main__":
    test_api()

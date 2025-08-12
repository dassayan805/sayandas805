import requests
import pandas as pd
import json
import schedule
import time
import os
from sf_file_upload import sf_file_upload

# API endpoint
API_URL = 'https://mocki.io/v1/e7300227-32bf-425d-8175-7f62bd4d9f57'
dir_path = os.path.abspath(os.path.dirname(__file__))
json_folder = os.path.abspath(os.path.join(dir_path, "..", "json"))


def fetch_data():
    try:
        response = requests.get(API_URL)
        response.raise_for_status()  # Raise an error for bad status codes
        data = response.json()
        return data
    except requests.exceptions.RequestException as e:
        print(f"Error fetching data: {e}")
        return []

def save_json(data):
    if not data:
        return
    JSON_FILE_name = "data_" + str(int(time.time())) + ".json"
    JSON_FILE = os.path.join(json_folder, JSON_FILE_name)  # json file path

    # Check if the JSON file exists
    if os.path.exists(JSON_FILE):
        os.remove(JSON_FILE)
    
    with open(JSON_FILE,'w') as f:
        json.dump(data,f,indent=4)

    # Call Snowflake upload
    sf = sf_file_upload()
    sf.file_upload(JSON_FILE)
    print("JSON upload complete")


def job():
    data = fetch_data()
    save_json(data)

# Schedule the job every 5 minutes
schedule.every(5).minutes.do(job)

# Initial run
job()

# Keep the script running
while True:
    schedule.run_pending()
    time.sleep(1)

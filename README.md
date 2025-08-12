# 📊 Social Media Analytics Pipeline
This repository demonstrates a complete end-to-end data pipeline for ingesting, processing, and visualizing social media data using Snowflake.

🔧 Key Components

Python Scripts

Connect to social media APIs
Extract and transform data
Load data files into a Snowflake staging area

SnowSQL Scripts

Set up automated data ingestion using Snowpipe
Configure Streams, Tasks, and Stored Procedures
Manage real-time processing from raw data to final target tables

Streamlit Dashboard
Visualize the processed data in an interactive dashboard
Enables quick insights from the ingested social media content

✅ What This Project Shows
This repo serves as a blueprint for building a fully automated data pipeline within Snowflake, from API integration to analytics-ready dashboards. It's a practical example of how modern data engineering tools can be orchestrated to support real-time social media analytics.

---

## 📌 Setup & Installation

### Install Dependencies
Ensure you have Python installed, then run:

```
pip install -r requirements.txt
```

🚀 Steps to Run the Project
1️⃣ Deploy Snowflake Database & Objects
Before running any scripts, set up the database, tables, and necessary objects in Snowflake:
-- Run this in Snowflake
```
Snowflake/Snowflake_setup.sql
```

2️⃣ Generate JSON Data
Run the JSON data generator script manually:
```
python src/json_gen.py
```
Or deploy it via Kubernetes:
```
kubectl apply -f kube_deployment.yaml
```
This will generate JSON files to be uploaded to Snowflake.

3️⃣ Files upload to Snowflake
Once JSON files are generated, sf_file_upload.py is called to upload them.

This script loads data from JSON files into Snowflake.

4️⃣ Validate Data
To ensure data integrity, run the validation SQL script inside Snowflake:
-- Run this in Snowflake
```
Snowflake/Validation_script.sql
```

5️⃣ Visualize Data Using Streamlit
Launch the analytics dashboard:
```
streamlit run src/Snowflake_dashboard.py
```
This will open an interactive web-based dashboard to explore the data.

📂 Project Structure
```
📦 Project Root
├── 📂 config                  # Configurations (e.g., Snowflake credentials)
│   ├── config.ini
├── 📂 json                    # JSON data files
│   ├── data_XXXX.json
├── 📂 src                     # Source scripts
│   ├── Snowflake_dashboard.py  # Streamlit dashboard
│   ├── json_gen.py             # Generates JSON data
│   ├── sf_file_upload.py       # Uploads JSON data to Snowflake
├── 🐳 dockerfile               # Docker container setup
├── 📄 kube_deployment.yaml     # Kubernetes deployment config
├── 📂 Snowflake                # SQL scripts for Snowflake setup & validation
│   ├── Snowflake_setup.sql
│   ├── Validation_script.sql
├── 📄 requirements.txt         # Python dependencies
└── 📄 README.md                # Project documentation
```
🛠️ Future Enhancements
Automate validation checks in Python.

Expand dashboard with filters and export options.

💡 Notes
Ensure Snowflake credentials are set up in config/config.ini.

Kubernetes deployment requires a configured cluster.

Streamlit should be run locally or deployed as a web app.

This README provides **clear step-by-step instructions** for setup, execution, and troubleshooting. 
Let me know if you'd like any modifications! 🚀
Happy coding! 🚀

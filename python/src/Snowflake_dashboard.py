import streamlit as st
import pandas as pd
import plotly.express as px
import snowflake.connector
import configparser
import os

# Streamlit page config
st.set_page_config(page_title="Social Media Dashboard", layout="wide")

# Load configuration
config_file = "config.ini"
dir_path = os.path.abspath(os.path.dirname(__file__))
config_path = os.path.abspath(os.path.join(dir_path, "..", "config", config_file))

config = configparser.ConfigParser()
config.read(config_path)

# Snowflake connection
@st.cache_resource
def get_snowflake_connection():
    return snowflake.connector.connect(
        user=config.get("SNOWFLAKE_CONN", "user"),
        password=config.get("SNOWFLAKE_CONN", "pass"),
        account=config.get("SNOWFLAKE_CONN", "account"),
        warehouse=config.get("SNOWFLAKE_CONN", "warehouse"),
        database="sb_project_db",
        schema="raw_data"
    )

# Load data
@st.cache_data
def load_data():
    conn = get_snowflake_connection()
    query = """
    SELECT u.USER_ID, u.USER_NAME, u.USER_CITY, 
           p.POST_ID, p.POST_TITLE, p.process_ts
    FROM sb_users u
    JOIN sb_processed_data p ON u.USER_ID = p.USER_ID
    """
    df = pd.read_sql(query, conn)
    conn.close()

    # Convert column names to lowercase for consistency
    df.columns = df.columns.str.lower()

    # Ensure process_ts is datetime
    df["process_ts"] = pd.to_datetime(df["process_ts"], errors="coerce")
    df = df.dropna(subset=["process_ts"])

    return df

# Load data into DataFrame
df = load_data()

# Streamlit UI
st.title("📊 Social Media Analytics Dashboard")

# KPI Metrics
st.subheader("📌 Key Metrics")
col1, col2, col3 = st.columns(3)
col1.metric("Total Users", df["user_id"].nunique())
col2.metric("Total Posts", df["post_id"].count())
col3.metric("Active Cities", df["user_city"].nunique())

# User Filter
selected_user = st.selectbox("🔍 Filter by User", ["All"] + sorted(df["user_name"].unique()))
if selected_user != "All":
    df = df[df["user_name"] == selected_user]

# Posts Over Time
st.subheader("📅 Posts Over Time")
fig_time = px.histogram(
    df, 
    x="process_ts", 
    title="Posts Trend Over Time", 
    nbins=10, 
    color="user_name"
)
st.plotly_chart(fig_time, use_container_width=True)

# Users by City
st.subheader("🌍 Users by City")
city_data = df.groupby("user_city")["user_id"].nunique().reset_index()
fig_city = px.bar(
    city_data, 
    x="user_city", 
    y="user_id", 
    title="Users per City", 
    color="user_city"
)
st.plotly_chart(fig_city, use_container_width=True)

# Recent Posts Table
st.subheader("📝 Recent Posts")
st.dataframe(
    df[["post_id", "post_title", "user_name", "user_city", "process_ts"]]
    .sort_values("process_ts", ascending=False)
)

st.write("📢 This dashboard provides an overview of user activity and post trends!")

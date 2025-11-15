import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go

st.set_page_config(page_title="Climate Analysis Dashboard", layout="wide")

# -------------------------------
# Load Data
# -------------------------------
FILENAME = "climate_agri_top5_countries.csv"   # <--- YOUR FILE NAME

@st.cache_data
def load_data():
    df = pd.read_csv(FILENAME)
    # Automatically deduplicate column names
    cols = pd.Series(df.columns)
    for dup in cols[cols.duplicated()].unique():
        cols[cols[cols == dup].index.values[1:]] = [f"{dup}_{i}" for i in range(1, sum(cols == dup))]
    df.columns = cols
    return df

try:
    df = load_data()
except Exception as e:
    st.error(f"Could not load {FILENAME}. Error: {e}")
    st.stop()

# -------------------------------
# Dashboard Title
# -------------------------------
st.title("🌍 Climate Analysis Dashboard")
st.write("This dashboard provides climate and agricultural insights based on our dataset.")

# -------------------------------
# Dataset Preview
# -------------------------------
st.header("📄 Dataset Preview")
st.dataframe(df)

# -------------------------------
# Summary Statistics
# -------------------------------
st.header("📊 Summary Statistics")
st.write(df.describe())

# -------------------------------
# Numeric Distributions
# -------------------------------
numeric_cols = df.select_dtypes(include=["float64", "int64"]).columns

if len(numeric_cols) > 0:
    st.header("📈 Numeric Column Distributions")
    for col in numeric_cols:
        st.subheader(f"Distribution of {col}")
        fig = px.histogram(df, x=col, title=f"Distribution of {col}")
        st.plotly_chart(fig, use_container_width=True)

# -------------------------------
# Correlation Heatmap
# -------------------------------
if len(numeric_cols) > 1:
    st.header("🔥 Correlation Heatmap of Numeric Variables")
    corr = df[numeric_cols].corr()
    fig = px.imshow(
        corr,
        text_auto=True,
        color_continuous_scale="Viridis",
        title="Correlation Heatmap"
    )
    st.plotly_chart(fig, use_container_width=True)

# -------------------------------
# Categorical Summary
# -------------------------------
cat_cols = df.select_dtypes(include=["object"]).columns

if len(cat_cols) > 0:
    st.header("🔠 Categorical Value Counts")
    for col in cat_cols:
        st.subheader(f"Value Counts for {col}")
        st.write(df[col].value_counts())

# -------------------------------
# Scatter Plot Selector
# -------------------------------
if len(numeric_cols) >= 2:
    st.header("📉 Custom Scatter Plot")

    x_col = st.selectbox("X-axis Variable", numeric_cols)
    y_col = st.selectbox("Y-axis Variable", numeric_cols)

    fig = px.scatter(
        df,
        x=x_col,
        y=y_col,
        title=f"{x_col} vs {y_col}",
        trendline="ols"
    )
    st.plotly_chart(fig, use_container_width=True)

# -------------------------------
# Line Chart (If Time Column Exists)
# -------------------------------
time_candidates = [c for c in df.columns if "year" in c.lower() or "date" in c.lower()]

if len(time_candidates) > 0:
    time_col = time_candidates[0]

    st.header(f"📅 Line Chart Over Time: {time_col}")

    fig = px.line(
        df,
        x=time_col,
        y=numeric_cols[0],
        title=f"{numeric_cols[0]} Over Time"
    )
    st.plotly_chart(fig, use_container_width=True)

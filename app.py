import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go

# -------------------------------------
# Page Config + Custom Styling
# -------------------------------------
st.set_page_config(page_title="🌍 Climate Explorer", layout="wide")

st.markdown("""
<style>
/* Make the app more modern */
.reportview-container, .main, .block-container {
    padding-top: 1rem;
    padding-bottom: 2rem;
}
h1, h2, h3 {
    font-weight: 800;
}
div[data-testid="stMetricValue"] {
    font-size: 28px;
}
.fun-card {
    padding: 20px;
    border-radius: 16px;
    background: rgba(0, 150, 255, 0.08);
    border: 1px solid rgba(0,0,0,0.1);
}
</style>
""", unsafe_allow_html=True)

# -------------------------------
# Data
# -------------------------------
FILENAME = "climate_agri_top5_countries.csv"

@st.cache_data
def load_data():
    df = pd.read_csv(FILENAME)
    cols = pd.Series(df.columns)
    for dup in cols[cols.duplicated()].unique():
        cols[cols[cols == dup].index.values[1:]] = [f"{dup}_{i}" for i in range(1, sum(cols == dup))]
    df.columns = cols
    return df

try:
    df = load_data()
except Exception as e:
    st.error(f"❌ Could not load {FILENAME}. Error: {e}")
    st.stop()

# -------------------------------
# Title
# -------------------------------
st.title("🌍 Climate Intelligence Dashboard")
st.caption("A colorful, interactive look at climate + agriculture relationships.")

# -------------------------------
# Sidebar Filters
# -------------------------------
st.sidebar.header("🔍 Filters")

cat_cols = df.select_dtypes(include=["object"]).columns
numeric_cols = df.select_dtypes(include=["float64", "int64"]).columns

# Sidebar category filter
if len(cat_cols) > 0:
    chosen_cat = st.sidebar.selectbox("Filter by Category Column:", ["None"] + list(cat_cols))
    if chosen_cat != "None":
        uniq_vals = df[chosen_cat].unique()
        choice_vals = st.sidebar.multiselect("Choose Values:", uniq_vals, default=uniq_vals)
        df = df[df[chosen_cat].isin(choice_vals)]

# -------------------------------
# Summary Metrics
# -------------------------------
st.subheader("📌 Key Metrics")

col1, col2, col3 = st.columns(3)

with col1:
    st.metric("Total Rows", len(df), help="After filters")

with col2:
    st.metric("Numeric Columns", len(numeric_cols))

with col3:
    st.metric("Categorical Columns", len(cat_cols))

# -------------------------------
# TABS (Cleaner layout)
# -------------------------------
tab1, tab2, tab3, tab4, tab5 = st.tabs(
    ["📄 Dataset", "📊 Stats", "📈 Visuals", "🔥 Correlation", "🔠 Categories"]
)

# ---- Tab 1: Dataset preview ----
with tab1:
    st.header("📄 Dataset Preview")
    st.dataframe(df, use_container_width=True)

# ---- Tab 2: Summary Stats ----
with tab2:
    st.header("📊 Summary Statistics")
    st.write(df.describe())

# ---- Tab 3: Visuals ----
with tab3:
    st.header("📈 Numerical Distributions")

    for col in numeric_cols:
        fig = px.histogram(
            df, x=col, 
            title=f"Histogram of {col}",
            animation_frame=None,
            opacity=0.7,
            color_discrete_sequence=px.colors.qualitative.Set2
        )
        st.plotly_chart(fig, use_container_width=True)

    # Scatter plot tool
    if len(numeric_cols) >= 2:
        st.subheader("🎯 Custom Scatter Plot")

        x_axis = st.selectbox("X-axis", numeric_cols)
        y_axis = st.selectbox("Y-axis", numeric_cols, index=1)
        color_by = st.selectbox("Color By (optional)", ["None"] + list(cat_cols))

        fig = px.scatter(
            df, x=x_axis, y=y_axis,
            color=None if color_by == "None" else color_by,
            size_max=10,
            opacity=0.8,
            trendline="ols"
        )
        st.plotly_chart(fig, use_container_width=True)

# ---- Tab 4: Correlation Heatmap ----
with tab4:
    if len(numeric_cols) > 1:
        st.header("🔥 Correlation Heatmap")

        corr = df[numeric_cols].corr()

        fig = px.imshow(
            corr,
            text_auto=True,
            color_continuous_scale="Turbo",
            title="Correlation Matrix"
        )
        st.plotly_chart(fig, use_container_width=True)

# ---- Tab 5: Categorical ----
with tab5:
    st.header("🔠 Categorical Value Counts")

    for col in cat_cols:
        with st.expander(f"Values for {col}"):
            st.write(df[col].value_counts())

# Importing necessary libraries
import pandas as pd # for data manipulation and analysis
import numpy as np # for data manipulation and analysis
import matplotlib.pyplot as plt # for data visualization
# Load the dataset
file_path = "The Final Project.xlsx"

fact = pd.read_excel(file_path, sheet_name="FactCampaignPerformance")
campaign = pd.read_excel(file_path, sheet_name="DimCampaignMeta")
channel = pd.read_excel(file_path, sheet_name="DimChannelRates")
audience = pd.read_excel(file_path, sheet_name="DimTargetAudience")
date_dim = pd.read_excel(file_path, sheet_name="DimDate")
region = pd.read_excel(file_path, sheet_name="DimRegion")

# Merge the datasets

merged_data = (
    fact.merge(campaign, on="CampaignID")
        .merge(channel, on="ChannelID")
        .merge(audience, on="TargetAudienceID")
        .merge(region, on="RegionID")
)

# Explorations

print(merged_data.head())
print(merged_data.info())
print(merged_data.describe())
print(merged_data.isnull().sum())

# overall performance 

total_cost = merged_data["Cost (₹)"].sum()
total_revenue = merged_data["Revenue (₹)"].sum()
roas = total_revenue / total_cost
print("Total Cost:", total_cost)
print("Total Revenue:", total_revenue)
print("ROAS:", round(roas,2))

# Campaign Analysis

campaign_performance = (
    merged_data.groupby("CampaignName")
    .agg({
        "Cost (₹)":"sum",
        "Revenue (₹)":"sum",
        "Leads":"sum",
        "Enrollments":"sum"
    })
    .sort_values("Revenue (₹)", ascending=False)
)
print(campaign_performance)

#visualization

campaign_performance["Revenue (₹)"].plot(
    kind="bar",
    figsize=(10,5)
)
plt.title("Revenue by Campaign")
plt.ylabel("Revenue")
plt.show()

# channel analysis

channel_performance = (
    merged_data.groupby("Channel")
    .agg({
        "Cost (₹)":"sum",
        "Revenue (₹)":"sum",
        "Clicks":"sum",
        "Impressions":"sum"
    })
)
print(channel_performance)
channel_performance["Revenue (₹)"].plot(
    kind="bar",
    figsize=(8,5)
)
plt.title("Revenue by Channel")
plt.show()

# Regional Analysis

region_performance = (
    merged_data.groupby("Region")
    .agg({
        "Revenue (₹)":"sum",
        "Cost (₹)":"sum",
        "Enrollments":"sum"
    })
)
print(region_performance)
region_performance["Revenue (₹)"].sort_values().plot(
    kind="barh",
    figsize=(8,5)
)
plt.title("Revenue by Region")
plt.show()

# CTR Analysis

ctr_channel = (
    merged_data.groupby("Channel")["CTR"]
    .mean()
    .sort_values(ascending=False)
)
print(ctr_channel)
ctr_channel.plot(kind="bar")
plt.title("Average CTR by Channel")
plt.show()

# ROAS By Campaign

campaign_roas = (
    merged_data.groupby("CampaignName")
    .apply(lambda x: x["Revenue (₹)"].sum() /
                     x["Cost (₹)"].sum())
)
print(campaign_roas)
campaign_roas.sort_values().plot(
    kind="barh",
    figsize=(8,5)
)
plt.title("ROAS by Campaign")
plt.show()

# Monthly revenue trend

monthly_revenue = (
    merged_data.groupby(["Date (Year)", "Date (Month Index)"])
    ["Revenue (₹)"]
    .sum()
)

monthly_revenue.plot(figsize=(12,5))

plt.title("Monthly Revenue Trend")
plt.ylabel("Revenue")
plt.show()

# Audience analysis

audience_perf = (
    merged_data.groupby("TargetAudience")
    .agg({
        "Revenue (₹)":"sum",
        "Enrollments":"sum",
        "Leads":"sum"
    })
)
print(audience_perf)

# correlation analysis

numeric_cols = [
    "Impressions",
    "Clicks",
    "Leads",
    "Applications",
    "Enrollments",
    "Cost (₹)",
    "Revenue (₹)",
    "CTR",
    "ROAS"
]

corr = merged_data[numeric_cols].corr()
print(corr)

# Charts 
#cost vs revenue By Region
region_summary = (
    merged_data.groupby("Region")
      .agg({
          "Cost (₹)": "sum",
          "Revenue (₹)": "sum"
      })
)
region_summary.plot(kind="bar")
plt.title("Cost vs Revenue By Region")
plt.ylabel("Amount (₹)")
plt.tight_layout()
plt.show()

#COst vs Revenue By platform
platform_summary = (
    merged_data.groupby("Channel")
      .agg({
          "Cost (₹)": "sum",
          "Revenue (₹)": "sum"
      })
)
platform_summary.plot(kind="bar")
plt.title("Cost vs Revenue By Platform")
plt.ylabel("Amount (₹)")
plt.tight_layout()
plt.show()

# Cross-Channel Acquisition Funnel
funnel = (
    merged_data.groupby("Channel")
      [["Impressions",
        "Clicks",
        "Leads",
        "Applications",
        "Enrollments"]]
      .sum()
)
funnel.T.plot(marker="o")
plt.title("Cross-Channel Acquisition Funnel")
plt.ylabel("Volume")
plt.tight_layout()
plt.show()

# Metrics By Campaign Name
campaign_metrics = (
    merged_data.groupby("CampaignName")
      [["Leads",
        "Applications",
        "Enrollments"]]
      .sum()
)
campaign_metrics.plot(kind="bar")
plt.title("Metrics By Campaign Name")
plt.tight_layout()
plt.show()

#Campaign Financial Efficiency & ROAS
campaign_roas = (
    merged_data.groupby("CampaignName")
      .apply(
          lambda x:
          x["Revenue (₹)"].sum() /
          x["Cost (₹)"].sum()
      )
)
campaign_roas.sort_values().plot(kind="barh")
plt.title("Campaign Financial Efficiency & ROAS")
plt.xlabel("ROAS")
plt.tight_layout()
plt.show()

#Channel Spending Distribution
channel_spend = (
    merged_data.groupby("Channel")["Cost (₹)"]
      .sum()
)
plt.figure(figsize=(8,8))
plt.pie(
    channel_spend,
    labels=channel_spend.index,
    autopct="%1.1f%%"
)
centre_circle = plt.Circle((0,0),0.65,fc="white")
plt.gca().add_artist(centre_circle)
plt.title("Channel Spending Distribution")
plt.show()

#Key Performance Ratios (CTR, CPC, CPL)
ratios = (
    merged_data.groupby("Channel")
      [["CTR","CPC","CPL"]]
      .mean()
)
ratios.plot(kind="bar")
plt.title("Key Performance Ratios")
plt.tight_layout()
plt.show()

#Audience Engagement Matrix
audience_matrix = (
    merged_data.groupby("TargetAudience")
      [["Clicks",
        "Leads",
        "Enrollments"]]
      .sum()
)
audience_matrix.plot(kind="bar")
plt.title("Audience Engagement Matrix")
plt.tight_layout()
plt.show()

#Audience Engagement Matrix
audience_matrix = (
    merged_data.groupby("TargetAudience")
      [["Clicks",
        "Leads",
        "Enrollments"]]
      .sum()
)
audience_matrix.plot(kind="bar")
plt.title("Audience Engagement Matrix")
plt.tight_layout()
plt.show()

#Creative Asset Performance
creative_perf = (
    merged_data.groupby("CreativeAsset")
      [["Clicks",
        "Leads",
        "Revenue (₹)"]]
      .sum()
)
creative_perf["Revenue (₹)"].plot(kind="bar")
plt.title("Creative Asset Performance")
plt.tight_layout()
plt.show()

#Monthly Performance Trends
monthly = (
    merged_data.groupby(
        ["Date (Year)",
         "Date (Month Index)"]
    )
    [["Revenue (₹)",
      "Cost (₹)"]]
    .sum()
)
monthly.plot(marker="o")
plt.title("Monthly Performance Trends")
plt.ylabel("Amount (₹)")
plt.tight_layout()
plt.show()

#Revenue Share Pie Chart
revenue_share = (
    merged_data.groupby("Channel")["Revenue (₹)"]
      .sum()
)
plt.figure(figsize=(8,8))
plt.pie(
    revenue_share,
    labels=revenue_share.index,
    autopct="%1.1f%%"
)
plt.title("Sum of Revenue")
plt.show()

"""
Dashboard Visualizations Generator
Creates charts and graphs for PowerBI/Tableau import

Author: Data Analyst Assessment
Date: 2026-01-29
"""

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
from datetime import datetime

# Set style
sns.set_style("whitegrid")
sns.set_palette("husl")
plt.rcParams['figure.figsize'] = (14, 8)
plt.rcParams['font.size'] = 10

# Load data
print("Loading data...")
customers = pd.read_csv('../data/customers.csv')
subscriptions = pd.read_csv('../data/subscriptions.csv')
events = pd.read_csv('../data/events.csv')

# Convert dates
customers['signup_date'] = pd.to_datetime(customers['signup_date'], errors='coerce')
subscriptions['start_date'] = pd.to_datetime(subscriptions['start_date'])
subscriptions['end_date'] = pd.to_datetime(subscriptions['end_date'], errors='coerce')
events['event_date'] = pd.to_datetime(events['event_date'])

# ============================================================================
# VISUALIZATION 1: MRR TREND OVER TIME
# ============================================================================

print("Creating MRR trend visualization...")

# Calculate monthly MRR
date_range = pd.date_range(start='2023-01', end='2023-12', freq='MS')
mrr_data = []

for date in date_range:
    month_end = date + pd.DateOffset(months=1) - pd.DateOffset(days=1)
    active_subs = subscriptions[
        (subscriptions['start_date'] <= month_end) &
        ((subscriptions['end_date'].isna()) | (subscriptions['end_date'] > date))
    ]
    mrr = active_subs['monthly_price'].sum()
    customer_count = active_subs['customer_id'].nunique()
    mrr_data.append({
        'month': date.strftime('%Y-%m'),
        'mrr': mrr,
        'customers': customer_count
    })

mrr_df = pd.DataFrame(mrr_data)

fig, ax1 = plt.subplots(figsize=(14, 6))

color = 'tab:blue'
ax1.set_xlabel('Month', fontsize=12)
ax1.set_ylabel('MRR ($)', color=color, fontsize=12)
ax1.plot(mrr_df['month'], mrr_df['mrr'], color=color, linewidth=2, marker='o', label='MRR')
ax1.tick_params(axis='y', labelcolor=color)
ax1.grid(True, alpha=0.3)

ax2 = ax1.twinx()
color = 'tab:orange'
ax2.set_ylabel('Active Customers', color=color, fontsize=12)
ax2.plot(mrr_df['month'], mrr_df['customers'], color=color, linewidth=2, marker='s', label='Customers')
ax2.tick_params(axis='y', labelcolor=color)

plt.title('MRR and Customer Growth Trend', fontsize=14, fontweight='bold')
plt.xticks(rotation=45)
plt.tight_layout()
plt.savefig('../dashboard/mrr_trend.png', dpi=300, bbox_inches='tight')
print("✓ MRR trend saved")
plt.close()

# ============================================================================
# VISUALIZATION 2: FUNNEL CONVERSION
# ============================================================================

print("Creating funnel visualization...")

# Build funnel data
funnel_data = {
    'Signup': events[events['event_type'] == 'signup']['customer_id'].nunique(),
    'Trial Start': events[events['event_type'] == 'trial_start']['customer_id'].nunique(),
    'Activated': events[events['event_type'] == 'activated']['customer_id'].nunique(),
    'Paid': subscriptions['customer_id'].nunique(),
}

stages = list(funnel_data.keys())
values = list(funnel_data.values())
conversion_rates = [100]
for i in range(1, len(values)):
    rate = (values[i] / values[0]) * 100
    conversion_rates.append(rate)

fig, ax = plt.subplots(figsize=(12, 6))
colors = plt.cm.Blues(np.linspace(0.4, 0.9, len(stages)))

bars = ax.barh(stages, values, color=colors, edgecolor='black', linewidth=1.5)

# Add value labels
for i, (bar, value, rate) in enumerate(zip(bars, values, conversion_rates)):
    ax.text(value + 20, bar.get_y() + bar.get_height()/2, 
            f'{value} ({rate:.1f}%)', 
            va='center', fontsize=11, fontweight='bold')

ax.set_xlabel('Number of Customers', fontsize=12)
ax.set_title('Customer Acquisition Funnel', fontsize=14, fontweight='bold')
ax.grid(axis='x', alpha=0.3)
plt.tight_layout()
plt.savefig('../dashboard/funnel_chart.png', dpi=300, bbox_inches='tight')
print("✓ Funnel chart saved")
plt.close()

# ============================================================================
# VISUALIZATION 3: CHURN ANALYSIS
# ============================================================================

print("Creating churn visualization...")

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6))

# Churn by status
status_counts = subscriptions['status'].value_counts()
colors_pie = ['#2ecc71', '#e74c3c']
ax1.pie(status_counts, labels=status_counts.index, autopct='%1.1f%%', 
        colors=colors_pie, startangle=90, textprops={'fontsize': 11})
ax1.set_title('Subscription Status Distribution', fontsize=12, fontweight='bold')

# Churn by segment
segment_churn = subscriptions.merge(customers[['customer_id', 'segment']], on='customer_id')
segment_churn['segment'] = segment_churn['segment'].fillna('Unknown')
churn_by_segment = segment_churn.groupby('segment')['status'].apply(
    lambda x: (x == 'canceled').sum() / len(x) * 100
).sort_values(ascending=False)

ax2.bar(range(len(churn_by_segment)), churn_by_segment.values, color='#e74c3c', edgecolor='black')
ax2.set_xticks(range(len(churn_by_segment)))
ax2.set_xticklabels(churn_by_segment.index, rotation=45, ha='right')
ax2.set_ylabel('Churn Rate (%)', fontsize=11)
ax2.set_title('Churn Rate by Segment', fontsize=12, fontweight='bold')
ax2.grid(axis='y', alpha=0.3)

plt.tight_layout()
plt.savefig('../dashboard/churn_analysis.png', dpi=300, bbox_inches='tight')
print("✓ Churn analysis saved")
plt.close()

# ============================================================================
# VISUALIZATION 4: ACQUISITION SOURCE PERFORMANCE
# ============================================================================

print("Creating source performance visualization...")

# Get signup events with source
signup_events = events[events['event_type'] == 'signup']

# Merge with subscriptions to get conversion
source_performance = []
for source in signup_events['source'].unique():
    source_customers = signup_events[signup_events['source'] == source]['customer_id'].unique()
    signups = len(source_customers)
    paid = subscriptions[subscriptions['customer_id'].isin(source_customers)]['customer_id'].nunique()
    conversion = (paid / signups * 100) if signups > 0 else 0
    
    # Calculate MRR from this source
    source_mrr = subscriptions[
        (subscriptions['customer_id'].isin(source_customers)) & 
        (subscriptions['status'] == 'active')
    ]['monthly_price'].sum()
    
    source_performance.append({
        'source': source,
        'signups': signups,
        'paid': paid,
        'conversion_rate': conversion,
        'mrr': source_mrr
    })

source_df = pd.DataFrame(source_performance).sort_values('conversion_rate', ascending=False)

fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(14, 10))

# Signups by source
ax1.bar(source_df['source'], source_df['signups'], color='#3498db', edgecolor='black')
ax1.set_ylabel('Signups', fontsize=11)
ax1.set_title('Signups by Source', fontsize=12, fontweight='bold')
ax1.grid(axis='y', alpha=0.3)

# Conversion rate by source
ax2.bar(source_df['source'], source_df['conversion_rate'], color='#2ecc71', edgecolor='black')
ax2.set_ylabel('Conversion Rate (%)', fontsize=11)
ax2.set_title('Conversion Rate by Source', fontsize=12, fontweight='bold')
ax2.grid(axis='y', alpha=0.3)

# MRR by source
ax3.bar(source_df['source'], source_df['mrr'], color='#9b59b6', edgecolor='black')
ax3.set_ylabel('Active MRR ($)', fontsize=11)
ax3.set_title('Active MRR by Source', fontsize=12, fontweight='bold')
ax3.grid(axis='y', alpha=0.3)

# Paid customers by source
ax4.bar(source_df['source'], source_df['paid'], color='#e67e22', edgecolor='black')
ax4.set_ylabel('Paid Customers', fontsize=11)
ax4.set_title('Paid Customers by Source', fontsize=12, fontweight='bold')
ax4.grid(axis='y', alpha=0.3)

plt.tight_layout()
plt.savefig('../dashboard/source_performance.png', dpi=300, bbox_inches='tight')
print("✓ Source performance saved")
plt.close()

# ============================================================================
# VISUALIZATION 5: SEGMENT PERFORMANCE
# ============================================================================

print("Creating segment performance visualization...")

# Prepare segment data
segment_data = customers.merge(subscriptions, on='customer_id', how='left')
segment_data['segment'] = segment_data['segment'].fillna('Unknown')

segment_metrics = segment_data[segment_data['status'] == 'active'].groupby('segment').agg({
    'customer_id': 'nunique',
    'monthly_price': ['sum', 'mean']
}).round(2)

segment_metrics.columns = ['customers', 'total_mrr', 'arpc']
segment_metrics = segment_metrics.sort_values('total_mrr', ascending=False)

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6))

# MRR by segment
ax1.bar(range(len(segment_metrics)), segment_metrics['total_mrr'], color='#1abc9c', edgecolor='black')
ax1.set_xticks(range(len(segment_metrics)))
ax1.set_xticklabels(segment_metrics.index, rotation=45, ha='right')
ax1.set_ylabel('Total MRR ($)', fontsize=11)
ax1.set_title('MRR by Customer Segment', fontsize=12, fontweight='bold')
ax1.grid(axis='y', alpha=0.3)

# ARPC by segment
ax2.bar(range(len(segment_metrics)), segment_metrics['arpc'], color='#f39c12', edgecolor='black')
ax2.set_xticks(range(len(segment_metrics)))
ax2.set_xticklabels(segment_metrics.index, rotation=45, ha='right')
ax2.set_ylabel('ARPC ($)', fontsize=11)
ax2.set_title('Average Revenue Per Customer by Segment', fontsize=12, fontweight='bold')
ax2.grid(axis='y', alpha=0.3)

plt.tight_layout()
plt.savefig('../dashboard/segment_performance.png', dpi=300, bbox_inches='tight')
print("✓ Segment performance saved")
plt.close()

# ============================================================================
# CREATE SUMMARY METRICS FOR DASHBOARD
# ============================================================================

print("\nGenerating summary metrics...")

active_subs = subscriptions[subscriptions['status'] == 'active']
summary_metrics = {
    'Current MRR': f"${active_subs['monthly_price'].sum():,.0f}",
    'ARR': f"${active_subs['monthly_price'].sum() * 12:,.0f}",
    'Active Customers': f"{active_subs['customer_id'].nunique():,}",
    'ARPC': f"${(active_subs['monthly_price'].sum() / active_subs['customer_id'].nunique()):.2f}",
    'Churn Rate': f"{(len(subscriptions[subscriptions['status'] == 'canceled']) / len(subscriptions) * 100):.1f}%",
    'Total Signups': f"{events[events['event_type'] == 'signup']['customer_id'].nunique():,}",
    'Signup to Paid': f"{(subscriptions['customer_id'].nunique() / events[events['event_type'] == 'signup']['customer_id'].nunique() * 100):.1f}%"
}

print("\nKEY METRICS:")
for metric, value in summary_metrics.items():
    print(f"  {metric}: {value}")

# Save metrics to file
with open('../dashboard/summary_metrics.txt', 'w') as f:
    f.write("SaaS Analytics Dashboard - Key Metrics\n")
    f.write("=" * 50 + "\n\n")
    for metric, value in summary_metrics.items():
        f.write(f"{metric}: {value}\n")

print("\n✓ All visualizations created successfully!")
print("Files saved in: ../dashboard/")
print("\nGenerated files:")
print("  - mrr_trend.png")
print("  - funnel_chart.png")
print("  - churn_analysis.png")
print("  - source_performance.png")
print("  - segment_performance.png")
print("  - summary_metrics.txt")

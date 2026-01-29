"""
Data Validation and Exploration
SaaS Analytics Take-Home Assessment

This notebook performs initial data quality checks and validation
before loading data into MySQL for analysis.

Author: Data Analyst Assessment
Date: 2026-01-29
"""

import pandas as pd
import numpy as np
import mysql.connector
from mysql.connector import Error
import warnings
warnings.filterwarnings('ignore')

# ============================================================================
# SECTION 1: LOAD DATA
# ============================================================================

print("=" * 80)
print("LOADING DATA FILES")
print("=" * 80)

# Load CSV files
customers = pd.read_csv('../data/customers.csv')
subscriptions = pd.read_csv('../data/subscriptions.csv')
events = pd.read_csv('../data/events.csv')

print(f"\n✓ Customers loaded: {len(customers)} rows")
print(f"✓ Subscriptions loaded: {len(subscriptions)} rows")
print(f"✓ Events loaded: {len(events)} rows")

# ============================================================================
# SECTION 2: DATA QUALITY ASSESSMENT
# ============================================================================

print("\n" + "=" * 80)
print("DATA QUALITY ASSESSMENT")
print("=" * 80)

def assess_data_quality(df, name):
    """Comprehensive data quality assessment"""
    print(f"\n{name.upper()}")
    print("-" * 40)
    
    # Basic info
    print(f"Shape: {df.shape}")
    print(f"Columns: {df.columns.tolist()}")
    
    # Missing values
    missing = df.isnull().sum()
    if missing.sum() > 0:
        print(f"\n⚠️  Missing Values:")
        print(missing[missing > 0])
    else:
        print("\n✓ No missing values")
    
    # Duplicates
    duplicates = df.duplicated().sum()
    if duplicates > 0:
        print(f"\n⚠️  Duplicate Rows: {duplicates}")
    else:
        print("✓ No duplicate rows")
    
    # Data types
    print(f"\nData Types:\n{df.dtypes}")
    
    return {
        'total_rows': len(df),
        'missing_values': missing.sum(),
        'duplicates': duplicates
    }

# Assess each dataset
customers_quality = assess_data_quality(customers, 'Customers')
subscriptions_quality = assess_data_quality(subscriptions, 'Subscriptions')
events_quality = assess_data_quality(events, 'Events')

# ============================================================================
# SECTION 3: SPECIFIC DATA ISSUES
# ============================================================================

print("\n" + "=" * 80)
print("SPECIFIC DATA ISSUES IDENTIFIED")
print("=" * 80)

# Issue 1: Duplicate events
print("\n1. DUPLICATE EVENTS")
print("-" * 40)
duplicate_events = events.groupby(['customer_id', 'event_type', 'event_date', 'source']).size()
duplicate_count = (duplicate_events > 1).sum()
print(f"Found {duplicate_count} sets of duplicate events")
if duplicate_count > 0:
    print("\nExamples of duplicates:")
    print(duplicate_events[duplicate_events > 1].head())

# Issue 2: Missing segments
print("\n2. MISSING CUSTOMER SEGMENTS")
print("-" * 40)
missing_segments = customers['segment'].isnull().sum()
print(f"Customers with missing segment: {missing_segments} ({missing_segments/len(customers)*100:.1f}%)")

# Issue 3: Missing signup dates
print("\n3. MISSING SIGNUP DATES")
print("-" * 40)
missing_signup = customers['signup_date'].isnull().sum()
print(f"Customers with missing signup_date: {missing_signup} ({missing_signup/len(customers)*100:.1f}%)")

# Issue 4: Subscription status consistency
print("\n4. SUBSCRIPTION STATUS CONSISTENCY")
print("-" * 40)
status_check = subscriptions.groupby('status').agg({
    'end_date': lambda x: x.isnull().sum()
}).rename(columns={'end_date': 'null_end_date_count'})
print("Status vs NULL end_date:")
print(status_check)

# Issue 5: Multiple subscriptions per customer
print("\n5. CUSTOMERS WITH MULTIPLE SUBSCRIPTIONS")
print("-" * 40)
multi_subs = subscriptions['customer_id'].value_counts()
multi_subs_count = (multi_subs > 1).sum()
print(f"Customers with multiple subscriptions: {multi_subs_count}")
if multi_subs_count > 0:
    print("\nExamples:")
    print(multi_subs[multi_subs > 1].head())

# ============================================================================
# SECTION 4: VALIDATION CHECKS
# ============================================================================

print("\n" + "=" * 80)
print("VALIDATION CHECKS")
print("=" * 80)

# Check 1: Referential integrity
print("\n1. REFERENTIAL INTEGRITY")
print("-" * 40)
events_customers = set(events['customer_id'].unique())
customers_ids = set(customers['customer_id'].unique())
subs_customers = set(subscriptions['customer_id'].unique())

orphan_events = events_customers - customers_ids
orphan_subs = subs_customers - customers_ids

print(f"Events with non-existent customers: {len(orphan_events)}")
print(f"Subscriptions with non-existent customers: {len(orphan_subs)}")

if len(orphan_events) == 0 and len(orphan_subs) == 0:
    print("✓ All foreign keys are valid")

# Check 2: Date consistency
print("\n2. DATE CONSISTENCY")
print("-" * 40)
customers['signup_date'] = pd.to_datetime(customers['signup_date'], errors='coerce')
subscriptions['start_date'] = pd.to_datetime(subscriptions['start_date'])
subscriptions['end_date'] = pd.to_datetime(subscriptions['end_date'], errors='coerce')
events['event_date'] = pd.to_datetime(events['event_date'])

print(f"Customer signup date range: {customers['signup_date'].min()} to {customers['signup_date'].max()}")
print(f"Subscription start date range: {subscriptions['start_date'].min()} to {subscriptions['start_date'].max()}")
print(f"Event date range: {events['event_date'].min()} to {events['event_date'].max()}")

# Check for subscriptions starting before customer signup
merged = subscriptions.merge(customers[['customer_id', 'signup_date']], on='customer_id', how='left')
invalid_dates = merged[merged['start_date'] < merged['signup_date']]
print(f"\nSubscriptions starting before signup: {len(invalid_dates)}")

# Check 3: Value ranges
print("\n3. VALUE RANGES")
print("-" * 40)
print(f"Monthly price statistics:")
print(subscriptions['monthly_price'].describe())

# Check for unusual values
print(f"\nUnusual monthly prices (< $10 or > $1000): {((subscriptions['monthly_price'] < 10) | (subscriptions['monthly_price'] > 1000)).sum()}")

# ============================================================================
# SECTION 5: SUMMARY STATISTICS
# ============================================================================

print("\n" + "=" * 80)
print("SUMMARY STATISTICS")
print("=" * 80)

print("\nCUSTOMERS")
print("-" * 40)
print(f"Total customers: {len(customers)}")
print(f"Segments: {customers['segment'].value_counts().to_dict()}")
print(f"Countries: {customers['country'].value_counts().to_dict()}")
print(f"Enterprise customers: {customers['is_enterprise'].sum()}")

print("\nSUBSCRIPTIONS")
print("-" * 40)
print(f"Total subscriptions: {len(subscriptions)}")
print(f"Status breakdown: {subscriptions['status'].value_counts().to_dict()}")
print(f"Unique paying customers: {subscriptions['customer_id'].nunique()}")
print(f"Average monthly price: ${subscriptions['monthly_price'].mean():.2f}")

print("\nEVENTS")
print("-" * 40)
print(f"Total events: {len(events)}")
print(f"Event types: {events['event_type'].value_counts().to_dict()}")
print(f"Sources: {events['source'].value_counts().to_dict()}")

# ============================================================================
# SECTION 6: DATA CLEANING RECOMMENDATIONS
# ============================================================================

print("\n" + "=" * 80)
print("DATA CLEANING RECOMMENDATIONS")
print("=" * 80)

recommendations = [
    "1. Handle duplicate events - keep first occurrence based on event_id",
    "2. Fill missing segments with 'Unknown' category",
    "3. Estimate missing signup dates using subscription start dates",
    "4. Verify subscription status matches end_date (active should have NULL end_date)",
    "5. Document assumption for customers with multiple subscriptions"
]

for rec in recommendations:
    print(f"\n{rec}")

# ============================================================================
# SECTION 7: EXPORT CLEANED DATA (OPTIONAL)
# ============================================================================

print("\n" + "=" * 80)
print("DATA EXPORT")
print("=" * 80)

# Remove duplicates from events
events_clean = events.drop_duplicates(subset=['customer_id', 'event_type', 'event_date', 'source'], keep='first')
print(f"Events after deduplication: {len(events)} → {len(events_clean)}")

# Fill missing segments
customers_clean = customers.copy()
customers_clean['segment'] = customers_clean['segment'].fillna('Unknown')

print("\n✓ Data validation complete")
print("\nNext steps:")
print("1. Load cleaned data into MySQL using 01_table_creation.sql")
print("2. Run data cleaning scripts (02_data_cleaning.sql)")
print("3. Execute analysis queries (03_core_metrics.sql, 04_funnel_analysis.sql)")

# ============================================================================
# SECTION 8: MYSQL CONNECTION (OPTIONAL)
# ============================================================================

def create_mysql_connection(host='localhost', database='saas_analytics', user='root', password=''):
    """
    Create MySQL connection for data loading
    
    Usage:
        connection = create_mysql_connection(
            host='localhost',
            database='saas_analytics',
            user='your_username',
            password='your_password'
        )
    """
    try:
        connection = mysql.connector.connect(
            host=host,
            database=database,
            user=user,
            password=password
        )
        if connection.is_connected():
            print(f"✓ Successfully connected to MySQL database: {database}")
            return connection
    except Error as e:
        print(f"✗ Error connecting to MySQL: {e}")
        return None

# Uncomment to use:
# connection = create_mysql_connection()
# if connection:
#     connection.close()

print("\n" + "=" * 80)
print("VALIDATION COMPLETE")
print("=" * 80)

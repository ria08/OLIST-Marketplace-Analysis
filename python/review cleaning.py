
import pandas as pd

# Read the problematic CSV using pandas which handles embedded newlines properly
df = pd.read_csv(
    r'C:\Users\singh\OneDrive\Olist ecommerce comprehensive project\OLIST marketplace data\olist_order_reviews_dataset.csv',
    on_bad_lines='skip'   # skip any truly malformed rows
)

print(f"Rows loaded: {len(df)}")
print(f"Columns: {list(df.columns)}")

# Remove embedded newlines and carriage returns from text columns
df['review_comment_title'] = df['review_comment_title'].astype(str).str.replace('\n', ' ').str.replace('\r', ' ')
df['review_comment_message'] = df['review_comment_message'].astype(str).str.replace('\n', ' ').str.replace('\r', ' ')

# Save cleaned version to MySQL uploads folder
output_path = r'C:\ProgramData\MySQL\MySQL Server 8.0\Uploads\OLIST marketplace data\olist_order_reviews_cleaned.csv'
df.to_csv(output_path, index=False)

print(f"Cleaned file saved to: {output_path}")
#!/bin/bash
set -euo pipefail

# Paperclip Skills & Agents — Setup Script
# Replaces placeholder variables with your company-specific values.

echo "🔧 Paperclip Skills & Agents Setup"
echo "==================================="
echo ""

# Company name
if [ -z "${COMPANY_NAME:-}" ]; then
  read -rp "Enter your company name (e.g. Acme Corp): " COMPANY_NAME
fi

# Cloudflare Account ID
if [ -z "${CF_ACCOUNT_ID:-}" ]; then
  read -rp "Enter your Cloudflare Account ID: " CF_ACCOUNT_ID
fi

# Product names (optional)
echo ""
echo "You can customize product names or keep the defaults (Product A-E)."
echo "Press Enter to skip any product."
read -rp "Product A name (default: Product A): " PRODUCT_A
read -rp "Product B name (default: Product B): " PRODUCT_B
read -rp "Product C name (default: Product C): " PRODUCT_C
read -rp "Product D name (default: Product D): " PRODUCT_D
read -rp "Product E name (default: Product E): " PRODUCT_E

PRODUCT_A="${PRODUCT_A:-Product A}"
PRODUCT_B="${PRODUCT_B:-Product B}"
PRODUCT_C="${PRODUCT_C:-Product C}"
PRODUCT_D="${PRODUCT_D:-Product D}"
PRODUCT_E="${PRODUCT_E:-Product E}"

# Replace in all files
echo ""
echo "Applying replacements..."

find agents/ skills/ *.md -type f -name "*.md" 2>/dev/null | while read -r file; do
  sed -i \
    -e "s/__COMPANY_NAME__/${COMPANY_NAME}/g" \
    -e "s/__CF_ACCOUNT_ID__/${CF_ACCOUNT_ID}/g" \
    -e "s/Product A/${PRODUCT_A}/g" \
    -e "s/Product B/${PRODUCT_B}/g" \
    -e "s/Product C/${PRODUCT_C}/g" \
    -e "s/Product D/${PRODUCT_D}/g" \
    -e "s/Product E/${PRODUCT_E}/g" \
    "$file"
done

echo ""
echo "✅ Setup complete!"
echo ""
echo "Company:    ${COMPANY_NAME}"
echo "CF Account: ${CF_ACCOUNT_ID}"
echo "Products:   ${PRODUCT_A}, ${PRODUCT_B}, ${PRODUCT_C}, ${PRODUCT_D}, ${PRODUCT_E}"
echo ""
echo "Next steps:"
echo "  1. Review agents/ and skills/ directories"
echo "  2. Deploy skills to your Paperclip agent workspace"
echo "  3. Create agents in Paperclip using adapter-configs.md"
echo "  4. Create issues from ceo-issue-list.md"

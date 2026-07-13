import re
import random

class DocumentAIExtractor:
    @staticmethod
    def extract(raw_text: str, doc_type: str) -> dict:
        lines = [line.strip() for line in raw_text.split('\n') if line.strip()]
        
        shop_name = ""
        buyer_name = ""
        invoice_number = ""
        date = ""
        products = []
        total_amount = 0.0

        # A. Date Parsing
        date_regex = re.compile(r'\b(\d{4}[-/]\d{2}[-/]\d{2}|\d{2}[-/]\d{2}[-/]\d{4})\b')
        for line in lines:
            match = date_regex.search(line)
            if match:
                dt = match.group(1)
                if '/' in dt:
                    dt = dt.replace('/', '-')
                if len(dt.split('-')[0]) == 2:
                    parts = dt.split('-')
                    date = f"{parts[2]}-{parts[1]}-{parts[0]}"
                else:
                    date = dt
                break
        if not date:
            import datetime
            date = datetime.date.today().isoformat()

        # B. Invoice Number Parsing
        inv_regex = re.compile(r'\b(?:inv|invoice|bill|receipt|sl|no)\.?\s*#?\s*([a-zA-Z0-9\-]{3,12})\b', re.IGNORECASE)
        for line in lines:
            match = inv_regex.search(line)
            if match and not any(k in line.lower() for k in ["date", "phone", "total"]):
                invoice_number = match.group(1).strip()
                break
        if not invoice_number:
            invoice_number = ""

        # C. Shop & Buyer Info
        for i in range(min(5, len(lines))):
            line = lines[i]
            lower = line.lower()
            if any(k in lower for k in ["agro", "agency", "kendra", "store", "shop", "center", "rama", "enterprise"]):
                shop_name = line
                break
        if not shop_name and lines:
            for line in lines:
                if not re.search(r'\d', line) and len(line) > 5:
                    shop_name = line
                    break
        if not shop_name:
            shop_name = ""

        for line in lines:
            lower = line.lower()
            if any(k in lower for k in ["customer", "buyer", "billed to", "bill to", "name"]):
                buyer_name = re.sub(r'(customer|buyer|billed to|bill to|name|[\:\-])', '', line, flags=re.IGNORECASE).strip()
                break
        if not buyer_name:
            for i in range(1, min(4, len(lines))):
                line = lines[i]
                if line != shop_name and not any(k in line.lower() for k in ["date", "total", "inv", "bill", "phone"]) and len(line) > 5:
                    buyer_name = line
                    break
        if not buyer_name:
            buyer_name = ""

        # D. Product Table Row Parsing (NPK cleaning, Quantity, Rate, Amount extraction)
        serial_regex = re.compile(r'^\s*(\d+)\s*[\.\-]?\s+')
        npk_regex = re.compile(r'\b\d+[\-:\u2013\u2212]\d+[\-:\u2013\u2212]\d+\b')
        pct_regex = re.compile(r'\(\s*\d+\s*%\s*[A-Za-z]*\s*\)')
        agri_keywords = re.compile(r'(urea|npk|dap|potash|fertilizer|agro|pesticide|gobbara|saf|mono|phosphate|sulphate|chlorpyriphos|coragen|chlorantraniliprole|seed)', re.IGNORECASE)

        for line in lines:
            trimmed = line.strip()
            starts_with_serial = bool(serial_regex.search(trimmed))
            has_agri_keyword = bool(agri_keywords.search(trimmed))

            if starts_with_serial or has_agri_keyword:
                original_line = serial_regex.sub('', trimmed)
                clean_line = npk_regex.sub('', original_line)
                clean_line = pct_regex.sub('', clean_line)

                num_regex = re.compile(r'\b\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?|\b\d{1,7}(?:\.\d{1,2})?\b')
                matches = num_regex.findall(clean_line)

                if len(matches) >= 2:
                    amount_str = matches[-1].replace(',', '')
                    rate_str = matches[-2].replace(',', '')
                    qty_str = matches[0]

                    item_amount = float(amount_str) if amount_str else 0.0
                    item_rate = float(rate_str) if rate_str else 0.0

                    qty_reg = re.compile(r'\b' + re.escape(qty_str) + r'\b')
                    qty_match = qty_reg.search(original_line)

                    product_name = ""
                    if qty_match:
                        product_name = original_line[:qty_match.start()].strip()
                    else:
                        idx = clean_line.find(qty_str)
                        if idx != -1:
                            product_name = clean_line[:idx].strip()

                    product_name = re.sub(r'[\s\-\u2013\u2212\:]+$', '', product_name).strip()

                    if not product_name and has_agri_keyword:
                        name_match = re.search(r'^[A-Za-z\s\d\-\(\)%]+', original_line, re.IGNORECASE)
                        if name_match:
                            product_name = name_match.group(0).strip()
                            product_name = re.sub(r'\b' + re.escape(qty_str) + r'\b.*$', '', product_name).strip()

                    quantity = 1.0
                    unit_match = re.search(r'(\d+)\s*(bags|bag|kg|litre|bottle|box|qty|packet|day|trip|worker)\b', original_line, re.IGNORECASE)
                    if unit_match:
                        quantity = float(unit_match.group(1))
                    elif item_rate > 0:
                        quantity = item_amount / item_rate

                    if product_name and item_amount > 0:
                        products.append({
                            "product_name": product_name,
                            "quantity": f"{quantity:.0f}",
                            "unit_price": f"{item_rate:.2f}",
                            "amount": f"{item_amount:.2f}"
                        })

        # E. Totals Section Detection
        total_keywords = re.compile(r'(total|grand\s*total|net\s*amount|amount\s*payable|gtotal)', re.IGNORECASE)
        for line in lines:
            if total_keywords.search(line):
                num_regex = re.compile(r'(?:₹|Rs\.?|INR)?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?|\d{1,7}(?:\.\d{1,2})?)\b')
                matches = num_regex.findall(line)
                if matches:
                    val = float(matches[-1].replace(',', ''))
                    if val > 0:
                        total_amount = val
                        break

        # Validation cross-checks
        calculated_sum = sum(float(p["amount"]) for p in products)
        if total_amount == 0.0 or abs(total_amount - calculated_sum) > (calculated_sum * 0.5):
            total_amount = calculated_sum

        return {
            "shop_name": shop_name,
            "buyer_name": buyer_name,
            "invoice_number": invoice_number,
            "date": date,
            "products": products,
            "total_amount": f"{total_amount:.2f}"
        }

import re

class ValidationEngine:
    @staticmethod
    def validate(data: dict) -> tuple[bool, float, list[str]]:
        errors = []
        scores = []

        # 1. Date Format check (yyyy-mm-dd)
        date_str = data.get("date", "")
        if not re.match(r'^\d{4}-\d{2}-\d{2}$', date_str):
            errors.append("Invalid date format. Expected YYYY-MM-DD.")
            scores.append(0.5)
        else:
            scores.append(1.0)

        # 2. Shop Name check
        if not data.get("shop_name", "").strip():
            errors.append("Empty shop name.")
            scores.append(0.0)
        else:
            scores.append(0.99)

        # 3. Product Row sum check
        products = data.get("products", [])
        calculated_sum = 0.0
        
        if not products:
            errors.append("No product rows found.")
            scores.append(0.2)
        else:
            for p in products:
                try:
                    qty = float(p.get("quantity", "0"))
                    price = float(p.get("unit_price", "0"))
                    amt = float(p.get("amount", "0"))
                    calculated_sum += amt
                    
                    if abs((qty * price) - amt) > 1.0:
                        errors.append(f"Product Math Mismatch: Qty ({qty}) * Price ({price}) != Amount ({amt}) for {p.get('product_name')}")
                        scores.append(0.6)
                    else:
                        scores.append(1.0)
                except Exception:
                    errors.append("Invalid non-numeric values in product row.")
                    scores.append(0.3)

        # 4. Total Amount check
        try:
            total_amount = float(data.get("total_amount", "0"))
            if abs(total_amount - calculated_sum) > 2.0:
                errors.append(f"Bill Mismatch: Calculated sum of products ({calculated_sum:.2f}) != Declared total amount ({total_amount:.2f})")
                scores.append(0.7)
            else:
                scores.append(1.0)
        except Exception:
            errors.append("Invalid non-numeric total amount.")
            scores.append(0.1)

        avg_confidence = sum(scores) / len(scores) if scores else 0.0
        is_valid = len(errors) == 0

        return is_valid, avg_confidence, errors

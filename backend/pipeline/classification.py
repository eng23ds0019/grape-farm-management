class DocumentClassifier:
    SUPPORTED_TYPES = ["fertilizer_bill", "pesticide_bill", "seed_bill"]

    @staticmethod
    def classify(text: str) -> str:
        lower = text.lower()
        
        fertilizer_keywords = ['urea', 'npk', 'dap', 'potash', 'fertilizer', 'gobbara', 'phosphate', 'sulphate', 'zinc']
        pesticide_keywords = ['pesticide', 'chlorpyriphos', 'coragen', 'saf', 'poison', 'herbicide', 'fungicide', 'monocrotophos', 'insecticide']
        seed_keywords = ['seed', 'seeds', 'hybrid', 'germination', 'germ', 'seminis', 'mahyco', 'variety', 'lot number']

        fert_score = sum(1 for k in fertilizer_keywords if k in lower)
        pest_score = sum(1 for k in pesticide_keywords if k in lower)
        seed_score = sum(1 for k in seed_keywords if k in lower)

        if fert_score == 0 and pest_score == 0 and seed_score == 0:
            # Default fallback when no keywords match directly
            return "fertilizer_bill"

        scores = {
            "fertilizer_bill": fert_score,
            "pesticide_bill": pest_score,
            "seed_bill": seed_score
        }

        return max(scores, key=scores.get)

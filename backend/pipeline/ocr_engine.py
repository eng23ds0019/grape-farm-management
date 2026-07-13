import os

class OCREngine:
    def __init__(self):
        self.paddle_available = False
        self.easy_available = False
        
        # 1. Try initializing PaddleOCR
        try:
            from paddleocr import PaddleOCR
            self.ocr = PaddleOCR(use_angle_cls=True, lang='en', show_log=False)
            self.paddle_available = True
        except Exception:
            pass

        # 2. Try initializing EasyOCR as a backup if PaddleOCR is not installed/working
        if not self.paddle_available:
            try:
                import easyocr
                self.reader = easyocr.Reader(['en'])
                self.easy_available = True
            except Exception:
                pass

    def extract_text(self, image_path: str) -> tuple[str, float]:
        """
        Runs real text extraction from the image file.
        Returns (extracted_text, average_confidence)
        """
        if not os.path.exists(image_path):
            raise FileNotFoundError(f"Image not found at {image_path}")

        # A. Execute PaddleOCR if active
        if self.paddle_available:
            try:
                result = self.ocr.ocr(image_path, cls=True)
                lines = []
                confidences = []
                for idx in range(len(result)):
                    res = result[idx]
                    if res is None:
                        continue
                    for line in res:
                        text_val = line[1][0]
                        conf_val = line[1][1]
                        lines.append(text_val)
                        confidences.append(conf_val)
                
                extracted_text = "\n".join(lines)
                avg_conf = sum(confidences) / len(confidences) if confidences else 0.0
                return extracted_text, avg_conf
            except Exception as e:
                pass

        # B. Execute EasyOCR if active
        if self.easy_available:
            try:
                result = self.reader.readtext(image_path)
                lines = []
                confidences = []
                for bbox, text_val, conf_val in result:
                    lines.append(text_val)
                    confidences.append(conf_val)
                
                extracted_text = "\n".join(lines)
                avg_conf = sum(confidences) / len(confidences) if confidences else 0.0
                return extracted_text, avg_conf
            except Exception as e:
                pass

        # C. If no real OCR is available, raise a system error
        raise RuntimeError("No active real OCR engines (PaddleOCR or EasyOCR) are available on this environment.")

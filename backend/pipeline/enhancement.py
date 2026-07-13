import cv2
import numpy as np

class ImageEnhancer:
    @staticmethod
    def enhance(image_path: str, output_path: str) -> str:
        image = cv2.imread(image_path)
        if image is None:
            raise ValueError("Could not read image file.")

        # 1. CLAHE (Contrast Limited Adaptive Histogram Equalization) on L-channel of LAB
        lab = cv2.cvtColor(image, cv2.COLOR_BGR2LAB)
        l, a, b = cv2.split(lab)
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        cl = clahe.apply(l)
        limg = cv2.merge((cl, a, b))
        enhanced = cv2.cvtColor(limg, cv2.COLOR_LAB2BGR)

        # 2. Deskew / Auto-Rotation correction
        gray = cv2.cvtColor(enhanced, cv2.COLOR_BGR2GRAY)
        blur = cv2.GaussianBlur(gray, (9, 9), 0)
        thresh = cv2.threshold(blur, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)[1]

        # Find all contours and compute bounding box angles
        coords = np.column_stack(np.where(thresh > 0))
        angle = 0.0
        if len(coords) > 0:
            angle = cv2.minAreaRect(coords)[-1]
            if angle < -45:
                angle = -(90 + angle)
            else:
                angle = -angle

        # Rotate if the skew angle is significant
        if abs(angle) > 0.5:
            (h, w) = image.shape[:2]
            center = (w // 2, h // 2)
            M = cv2.getRotationMatrix2D(center, angle, 1.0)
            enhanced = cv2.warpAffine(enhanced, M, (w, h), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_REPLICATE)

        # 3. Save optimized BGR image (maintains full resolution for OCR detection)
        cv2.imwrite(output_path, enhanced)
        return output_path

import cv2
import numpy as np

class QualityAnalyzer:
    @staticmethod
    def analyze(image_path: str) -> dict:
        image = cv2.imread(image_path)
        if image is None:
            return {
                "is_acceptable": False,
                "reason": "Could not read image file."
            }

        height, width, _ = image.shape
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

        # 1. Resolution Check
        min_pixels = 1000 * 1000 # 1 Megapixel minimum
        total_pixels = height * width
        res_ok = total_pixels >= min_pixels

        # 2. Blur Check (Laplacian Variance)
        laplacian_var = cv2.Laplacian(gray, cv2.CV_64F).var()
        blur_threshold = 100.0
        blur_ok = laplacian_var >= blur_threshold

        # 3. Brightness & Contrast Check
        mean_brightness = np.mean(gray)
        std_contrast = np.std(gray)
        
        # Brightness range: 40 (too dark) to 230 (overexposed)
        brightness_ok = 40.0 <= mean_brightness <= 230.0
        # Contrast standard deviation minimum of 15.0
        contrast_ok = std_contrast >= 15.0

        is_acceptable = res_ok and blur_ok and brightness_ok and contrast_ok
        
        reasons = []
        if not res_ok:
            reasons.append(f"Low resolution: {width}x{height} (requires at least 1MP)")
        if not blur_ok:
            reasons.append(f"Image is too blurry (variance: {laplacian_var:.1f})")
        if not brightness_ok:
            reasons.append(f"Incorrect lighting (brightness: {mean_brightness:.1f})")
        if not contrast_ok:
            reasons.append(f"Low contrast (deviation: {std_contrast:.1f})")

        return {
            "is_acceptable": is_acceptable,
            "blur_score": laplacian_var,
            "brightness": mean_brightness,
            "contrast": std_contrast,
            "resolution": f"{width}x{height}",
            "status": "PASS" if is_acceptable else "REJECT",
            "message": "Image quality is optimal." if is_acceptable else " / ".join(reasons)
        }

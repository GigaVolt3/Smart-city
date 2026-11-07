import io
from typing import Dict, Tuple, Union, Any, Optional
import numpy as np
from PIL import Image


class CivicImageComparator:
    """
    AI computer vision engine for civic grievance resolution verification.
    Compares 'before' (complaint photo) and 'after' (work completion photo) images
    to detect resolution, scene consistency, and fraudulent submissions.
    """

    def _load_image(self, img_input: Union[str, bytes, io.BytesIO, Image.Image]) -> Image.Image:
        """Loads and converts input into an RGB PIL Image."""
        if isinstance(img_input, Image.Image):
            return img_input.convert("RGB")
        if isinstance(img_input, str):
            return Image.open(img_input).convert("RGB")
        if isinstance(img_input, bytes):
            return Image.open(io.BytesIO(img_input)).convert("RGB")
        if isinstance(img_input, io.BytesIO):
            return Image.open(img_input).convert("RGB")
        raise ValueError("Unsupported image input type")

    def _compute_dhash(self, image: Image.Image, hash_size: int = 8) -> str:
        """Computes difference hash (dHash) for perceptual similarity comparison."""
        resized = image.convert("L").resize((hash_size + 1, hash_size), Image.Resampling.LANCZOS)
        pixels = np.array(resized)
        # Compare adjacent pixels
        diff = pixels[:, 1:] > pixels[:, :-1]
        return "".join(["1" if b else "0" for b in diff.flatten()])

    def _hamming_distance(self, hash1: str, hash2: str) -> int:
        """Calculates bitwise Hamming distance between two binary hash strings."""
        return sum(c1 != c2 for c1, c2 in zip(hash1, hash2))

    def _compute_histogram_correlation(self, img1: Image.Image, img2: Image.Image) -> float:
        """Calculates normalized histogram correlation across RGB channels."""
        h1 = np.array(img1.histogram(), dtype=np.float32)
        h2 = np.array(img2.histogram(), dtype=np.float32)

        # Normalize histograms
        s1, s2 = np.sum(h1), np.sum(h2)
        if s1 > 0:
            h1 /= s1
        if s2 > 0:
            h2 /= s2

        mean1, mean2 = np.mean(h1), np.mean(h2)
        numerator = np.sum((h1 - mean1) * (h2 - mean2))
        denominator = np.sqrt(np.sum((h1 - mean1) ** 2) * np.sum((h2 - mean2) ** 2))

        if denominator == 0:
            return 1.0 if np.all(h1 == h2) else 0.0
        return float(np.clip(numerator / denominator, 0.0, 1.0))

    def _compute_ssim(self, arr1: np.ndarray, arr2: np.ndarray) -> float:
        """
        Computes Structural Similarity Index (SSIM) between two grayscale numpy image arrays.
        SSIM(x, y) = ((2*mu_x*mu_y + c1)*(2*sigma_xy + c2)) / ((mu_x^2 + mu_y^2 + c1)*(sigma_x^2 + sigma_y^2 + c2))
        """
        arr1 = arr1.astype(np.float64)
        arr2 = arr2.astype(np.float64)

        k1, k2 = 0.01, 0.03
        L = 255.0
        c1 = (k1 * L) ** 2
        c2 = (k2 * L) ** 2

        mu1 = np.mean(arr1)
        mu2 = np.mean(arr2)
        mu1_sq = mu1 ** 2
        mu2_sq = mu2 ** 2
        mu1_mu2 = mu1 * mu2

        sigma1_sq = np.var(arr1)
        sigma2_sq = np.var(arr2)
        sigma12 = np.mean((arr1 - mu1) * (arr2 - mu2))

        numerator = (2.0 * mu1_mu2 + c1) * (2.0 * sigma12 + c2)
        denominator = (mu1_sq + mu2_sq + c1) * (sigma1_sq + sigma2_sq + c2)

        if denominator == 0:
            return 1.0 if np.all(arr1 == arr2) else 0.0
        return float(np.clip(numerator / denominator, -1.0, 1.0))

    def _compute_edge_energy(self, gray_arr: np.ndarray) -> float:
        """Computes high-frequency edge energy using Sobel-like discrete gradient approximations."""
        # Simple finite differences for horizontal and vertical edges
        gx = np.abs(gray_arr[:, 1:] - gray_arr[:, :-1])
        gy = np.abs(gray_arr[1:, :] - gray_arr[:-1, :])
        return float(np.mean(gx) + np.mean(gy))

    def compare(
        self,
        before_image: Union[str, bytes, io.BytesIO, Image.Image],
        after_image: Union[str, bytes, io.BytesIO, Image.Image],
    ) -> Dict[str, Any]:
        """
        Performs multi-criteria before/after image verification for complaint resolution.
        """
        try:
            img_before = self._load_image(before_image)
            img_after = self._load_image(after_image)
        except Exception as e:
            return {
                "is_verified": False,
                "verification_status": "ERROR_CORRUPT_IMAGE",
                "resolution_score": 0.0,
                "confidence": 0.0,
                "metrics": {},
                "explanation": f"Failed to load image: {str(e)}",
            }

        # Standard dimensions for structural analysis
        standard_size = (256, 256)
        b_std = img_before.resize(standard_size, Image.Resampling.LANCZOS)
        a_std = img_after.resize(standard_size, Image.Resampling.LANCZOS)

        b_gray = np.array(b_std.convert("L"), dtype=np.float32)
        a_gray = np.array(a_std.convert("L"), dtype=np.float32)

        # 1. Anti-Fraud Check: Identical Image Detection (Re-uploading the same photo)
        dhash_before = self._compute_dhash(b_std)
        dhash_after = self._compute_dhash(a_std)
        hamming_dist = self._hamming_distance(dhash_before, dhash_after)

        mse = float(np.mean((b_gray - a_gray) ** 2))

        if hamming_dist <= 2 and mse < 5.0:
            return {
                "is_verified": False,
                "verification_status": "FRAUD_IDENTICAL_IMAGE",
                "resolution_score": 0.0,
                "confidence": 0.98,
                "metrics": {
                    "hamming_distance": hamming_dist,
                    "mean_squared_error": round(mse, 2),
                    "structural_similarity": 1.0,
                    "histogram_correlation": 1.0,
                },
                "explanation": "Fraud Alert: The resolution image is identical or virtually unchanged from the complaint photo.",
            }

        # 2. Anti-Fraud Check: Blank / Dark / Covered Lens Image
        a_variance = float(np.var(a_gray))
        a_brightness = float(np.mean(a_gray))

        if a_variance < 8.0 or a_brightness < 8.0 or a_brightness > 248.0:
            return {
                "is_verified": False,
                "verification_status": "FRAUD_DUMMY_IMAGE",
                "resolution_score": 0.0,
                "confidence": 0.95,
                "metrics": {
                    "image_variance": round(a_variance, 2),
                    "average_brightness": round(a_brightness, 2),
                },
                "explanation": "Rejected: The submitted after-image is blank, pitch dark, overexposed, or obscured.",
            }

        # 3. Scene Consistency (Are both photos taken at the same location?)
        hist_corr = self._compute_histogram_correlation(b_std, a_std)
        ssim_score = self._compute_ssim(b_gray, a_gray)

        # Normalized structural score
        structural_alignment = max(0.0, ssim_score)

        # 4. Remediation / Change Detection Analysis
        diff_gray = np.abs(b_gray - a_gray)
        significant_change_mask = diff_gray > 25.0
        change_pct = float(np.mean(significant_change_mask) * 100.0)

        edge_before = self._compute_edge_energy(b_gray)
        edge_after = self._compute_edge_energy(a_gray)
        edge_diff_pct = abs(edge_after - edge_before) / max(1.0, edge_before) * 100.0

        # 5. Composite Verification Score Calculation (0 - 100)
        # We reward:
        #  - High to moderate scene consistency (confirms same site)
        #  - Noticeable localized change in defect region (pothole filled / garbage removed)
        #  - Sensible edge smoothing or restoration
        location_score = (0.5 * hist_corr) + (0.5 * structural_alignment)  # 0 to 1

        resolution_score = 0.0
        if location_score < 0.20:
            # Different location or completely different angle
            status = "DIFFERENT_LOCATION_OR_ANGLE"
            explanation = "Photos appear to be taken from completely different locations or drastically different angles."
            confidence = 0.65
            resolution_score = 20.0
            is_verified = False
        elif change_pct < 4.0:
            # Same location, but virtually no work done
            status = "SUSPICIOUS_UNRESOLVED"
            explanation = "Location matches, but visual defect appears untouched with minimal surface changes."
            confidence = 0.85
            resolution_score = 15.0
            is_verified = False
        elif change_pct >= 8.0 and location_score >= 0.40:
            status = "VERIFIED_RESOLVED"
            explanation = f"Resolution verified! Physical change detected ({change_pct:.1f}% visual remediation) with consistent environmental landmarks ({location_score*100:.0f}% scene match)."
            confidence = round(min(0.95, (location_score * 0.5) + (min(100.0, change_pct) * 0.005) + 0.3), 2)
            resolution_score = round(min(98.0, 50.0 + (location_score * 30.0) + (change_pct * 0.4)), 1)
            is_verified = True
        else:
            status = "LIKELY_RESOLVED"
            explanation = f"Likely resolved. Visual differences observed ({change_pct:.1f}% change) with acceptable context consistency."
            confidence = 0.75
            resolution_score = round(min(80.0, 40.0 + (change_pct * 0.5) + (location_score * 20.0)), 1)
            is_verified = True

        return {
            "is_verified": is_verified,
            "verification_status": status,
            "resolution_score": resolution_score,
            "confidence": confidence,
            "metrics": {
                "scene_match_percentage": round(location_score * 100.0, 1),
                "histogram_correlation": round(hist_corr, 3),
                "structural_similarity": round(ssim_score, 3),
                "visual_change_percentage": round(change_pct, 1),
                "edge_energy_before": round(edge_before, 2),
                "edge_energy_after": round(edge_after, 2),
                "hamming_distance": hamming_dist,
            },
            "explanation": explanation,
        }

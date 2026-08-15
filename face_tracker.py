"""
FaceMeshTracker module alias for FaceFeatureExtractor.
Provides FaceMeshTracker class with identical capabilities for vision quality gates and ROI spatial mean extractions.
"""

from face_feature_extractor import FaceFeatureExtractor


class FaceMeshTracker(FaceFeatureExtractor):
    """
    FaceMeshTracker subclass extending FaceFeatureExtractor for MediaPipe tracking and visual quality checks.
    """
    pass

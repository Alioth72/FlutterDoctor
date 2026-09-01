from sqlalchemy import Column, Integer, String, Text, Boolean, Float, ForeignKey
from sqlalchemy.orm import relationship
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any

try:
    from .database import Base
except (ImportError, ValueError):
    from database import Base

# ==========================================
# SQLAlchemy Models
# ==========================================

class Patient(Base):
    __tablename__ = "patients"

    patient_id = Column(String(50), primary_key=True, index=True)
    name = Column(String(150), nullable=True)
    age = Column(Integer, nullable=False)
    gender = Column(String(20), nullable=True)
    state = Column(String(100), nullable=False)
    income = Column(Float, nullable=False) # In Rupees (annual)
    income_range = Column(String(50), nullable=True)
    occupation = Column(String(100), nullable=True)
    category = Column(String(50), nullable=True) # General, OBC, SC, ST
    disability = Column(String(50), nullable=True) # None, Locomotor, Visual, etc.
    marital_status = Column(String(50), nullable=True) # Single, Married, Widow, etc.
    residence_type = Column(String(50), nullable=True) # Rural, Urban, Semi-Urban


class Scheme(Base):
    __tablename__ = "schemes"

    scheme_id = Column(String(100), primary_key=True, index=True)
    scheme_name = Column(String(300), nullable=False, index=True)
    slug = Column(String(300), nullable=True)
    details = Column(Text, nullable=True)
    benefits = Column(Text, nullable=True)
    eligibility_text = Column(Text, nullable=True)
    application_process = Column(Text, nullable=True)
    documents = Column(Text, nullable=True)
    level = Column(String(50), nullable=True) # Central, State
    state = Column(String(100), nullable=True) # State name if state-specific
    scheme_category = Column(String(200), nullable=True)
    tags = Column(Text, nullable=True)
    official_url = Column(String(500), nullable=True)
    last_verified = Column(String(50), nullable=True)

    rules = relationship("SchemeRule", back_populates="scheme", cascade="all, delete-orphan")


class SchemeRule(Base):
    __tablename__ = "scheme_rules"

    rule_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    scheme_id = Column(String(100), ForeignKey("schemes.scheme_id"), nullable=False)
    field = Column(String(50), nullable=False) # age, state, income, gender, occupation, category, disability
    operator = Column(String(10), nullable=False) # >=, <=, ==, !=, in, not_in
    value = Column(String(200), nullable=False) # Value as string (parsed at runtime)

    scheme = relationship("Scheme", back_populates="rules")


# ==========================================
# Pydantic Schemas
# ==========================================

class PatientProfileInput(BaseModel):
    name: Optional[str] = None
    age: int = Field(..., ge=0, le=130)
    state: str
    income_range: str # e.g. "< 1 Lakh", "1 - 2.5 Lakh", "2.5 - 5 Lakh", "5 - 8 Lakh", "> 8 Lakh"
    income_numeric: Optional[float] = None
    gender: Optional[str] = None
    occupation: Optional[str] = None
    category: Optional[str] = None # General, OBC, SC, ST
    disability: Optional[str] = None # None, Yes, Locomotor, etc.
    marital_status: Optional[str] = None
    residence_type: Optional[str] = None # Rural, Urban, Semi-Urban


class RuleEvaluation(BaseModel):
    status: str # "likely_eligible", "verification_required", "likely_not_eligible"
    status_label: str # "You may be eligible", "Verification required", "Likely not eligible"
    status_badge: str # "🟢 Likely Eligible", "🟡 Verification Required", "🔴 Likely Not Eligible"
    matched_rules: List[str] = []
    failed_rules: List[str] = []
    missing_information: List[str] = []
    reason: str


class SchemeItemResponse(BaseModel):
    scheme_id: str
    scheme_name: str
    level: Optional[str] = None
    state: Optional[str] = None
    short_description: str
    benefits_summary: List[str] = []
    tags: List[str] = []
    evaluation: RuleEvaluation


class SchemeDetailResponse(BaseModel):
    scheme_id: str
    scheme_name: str
    level: Optional[str] = None
    state: Optional[str] = None
    scheme_category: Optional[str] = None
    details: str
    benefits: str
    benefits_list: List[str] = []
    eligibility_text: str
    application_process: str
    application_steps: List[str] = []
    documents: str
    documents_list: List[str] = []
    tags: List[str] = []
    official_url: Optional[str] = None
    evaluation: Optional[RuleEvaluation] = None


class EligibilityCheckResponse(BaseModel):
    total_schemes_evaluated: int
    likely_eligible_count: int
    verification_required_count: int
    likely_not_eligible_count: int
    profile_summary: str
    results: List[SchemeItemResponse]


class AiExplainRequest(BaseModel):
    scheme_id: str
    question: Optional[str] = "Explain this scheme in simple language and why I may be eligible."
    patient_profile: Optional[PatientProfileInput] = None


class AiExplainResponse(BaseModel):
    scheme_id: str
    scheme_name: str
    explanation: str
    key_highlights: List[str]
    required_documents: List[str]
    next_steps: List[str]
    source: str = "Ground Truth from Official Government Scheme Registry"

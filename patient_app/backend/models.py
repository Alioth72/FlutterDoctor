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

    id = Column(String(100), primary_key=True, index=True)
    slug = Column(String(300), nullable=True)
    name = Column(String(300), nullable=False, index=True)
    ministry = Column(String(300), nullable=True)
    category = Column(String(200), nullable=True)
    tags = Column(Text, nullable=True)
    brief_description = Column(Text, nullable=True)
    detailed_description = Column(Text, nullable=True)
    benefits = Column(Text, nullable=True)
    documents_required = Column(Text, nullable=True)
    application_process = Column(Text, nullable=True)
    apply_url = Column(String(500), nullable=True)
    eligible_gender = Column(String(50), nullable=True)
    age_min = Column(Integer, nullable=True)
    age_max = Column(Integer, nullable=True)
    eligible_employment_status = Column(String(100), nullable=True)
    student_only = Column(String(20), nullable=True)
    eligible_caste = Column(String(100), nullable=True)
    minority_only = Column(String(20), nullable=True)
    disability_only = Column(String(20), nullable=True)
    eligible_residence = Column(String(50), nullable=True)
    eligible_state = Column(String(100), nullable=True)
    raw_json = Column(Text, nullable=True)

    # Backward-compatible property aliases
    @property
    def scheme_id(self) -> str:
        return self.id or ""

    @property
    def scheme_name(self) -> str:
        return self.name or ""

    @property
    def details(self) -> str:
        return self.detailed_description or self.brief_description or ""

    @property
    def eligibility_text(self) -> str:
        parts = []
        if self.eligible_gender:
            parts.append(f"Gender: {self.eligible_gender}")
        if self.age_min is not None or self.age_max is not None:
            min_a = self.age_min if self.age_min is not None else "Any"
            max_a = self.age_max if self.age_max is not None else "Any"
            parts.append(f"Age: {min_a} to {max_a} years")
        if self.eligible_state:
            parts.append(f"State: {self.eligible_state}")
        if self.eligible_caste:
            parts.append(f"Category: {self.eligible_caste}")
        if self.eligible_employment_status:
            parts.append(f"Employment: {self.eligible_employment_status}")
        if self.student_only and str(self.student_only).lower() in ['yes', 'true']:
            parts.append("Students Only")
        if self.disability_only and str(self.disability_only).lower() in ['yes', 'true']:
            parts.append("Persons with Disabilities Only")
        if self.minority_only and str(self.minority_only).lower() in ['yes', 'true']:
            parts.append("Minority Communities Only")
        return "; ".join(parts) if parts else "Open to eligible citizens under scheme guidelines."

    @property
    def documents(self) -> str:
        return self.documents_required or ""

    @property
    def level(self) -> str:
        return "State" if self.eligible_state else "Central"

    @property
    def state(self) -> Optional[str]:
        return self.eligible_state

    @property
    def scheme_category(self) -> Optional[str]:
        return self.category

    @property
    def official_url(self) -> str:
        return self.apply_url or "https://www.myscheme.gov.in"


# ==========================================
# Pydantic Schemas
# ==========================================

class PatientProfileInput(BaseModel):
    name: Optional[str] = None
    age: int = Field(..., ge=0, le=130)
    state: str = "All"
    income_range: str = "1 - 2.5 Lakh"
    income_numeric: Optional[float] = None
    gender: Optional[str] = None
    occupation: Optional[str] = None
    category: Optional[str] = None # General, OBC, SC, ST
    disability: Optional[str] = None # None, Yes, Locomotor, etc.
    marital_status: Optional[str] = None
    residence_type: Optional[str] = None # Rural, Urban, Both
    is_student: Optional[Any] = None
    is_minority: Optional[bool] = None
    minority_status: Optional[str] = None
    employment_status: Optional[str] = None
    is_bpl: Optional[bool] = None
    is_hardship_distress: Optional[bool] = None


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

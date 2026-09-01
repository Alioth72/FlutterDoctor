import os
import re
from dotenv import load_dotenv

# Automatically load .env file
load_dotenv()

from fastapi import FastAPI, Depends, HTTPException, Query, status
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from typing import List, Optional
import uuid

try:
    from .database import get_db, engine, Base
    from .models import (
        Patient, Scheme, SchemeRule,
        PatientProfileInput, SchemeItemResponse, SchemeDetailResponse,
        EligibilityCheckResponse, AiExplainRequest, AiExplainResponse,
        RuleEvaluation
    )
    from .eligibility_engine import EligibilityEngine
    from .import_schemes import import_data
    from .ai_service import GeminiSchemeExplainer
except (ImportError, ValueError):
    from database import get_db, engine, Base
    from models import (
        Patient, Scheme, SchemeRule,
        PatientProfileInput, SchemeItemResponse, SchemeDetailResponse,
        EligibilityCheckResponse, AiExplainRequest, AiExplainResponse,
        RuleEvaluation
    )
    from eligibility_engine import EligibilityEngine
    from import_schemes import import_data
    from ai_service import GeminiSchemeExplainer

# Create DB tables
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Indian Government Health Schemes & Eligibility API",
    description="API for Patient Scheme Discovery, Deterministic Rules Evaluation, and AI Grounded Explanations",
    version="1.0.0"
)

# Enable CORS for Flutter & Web clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
def startup_event():
    # Import CSV data if database is empty
    import_data()

@app.get("/")
def root():
    return {
        "status": "online",
        "service": "Indian Government Health Schemes & Eligibility API",
        "version": "1.0.0",
        "endpoints": [
            "/patient/profile",
            "/schemes",
            "/schemes/check-eligibility",
            "/schemes/{scheme_id}",
            "/schemes/{scheme_id}/application",
            "/ai/explain"
        ]
    }

# =========================================================================
# 1. POST /patient/profile - Save or update patient eligibility profile
# =========================================================================
@app.post("/patient/profile", status_code=status.HTTP_201_CREATED)
def save_patient_profile(profile: PatientProfileInput, db: Session = Depends(get_db)):
    patient_id = f"PAT_{uuid.uuid4().hex[:8].upper()}"
    numeric_income = EligibilityEngine.get_estimated_income(profile.income_range, profile.income_numeric)

    patient_entry = Patient(
        patient_id=patient_id,
        name=profile.name,
        age=profile.age,
        gender=profile.gender,
        state=profile.state,
        income=numeric_income,
        income_range=profile.income_range,
        occupation=profile.occupation,
        category=profile.category,
        disability=profile.disability,
        marital_status=profile.marital_status,
        residence_type=profile.residence_type,
    )
    db.add(patient_entry)
    db.commit()
    db.refresh(patient_entry)

    return {
        "message": "Patient profile saved successfully",
        "patient_id": patient_id,
        "profile": profile
    }

# =========================================================================
# 2. GET /schemes - Retrieve list of health schemes
# =========================================================================
@app.get("/schemes", response_model=List[SchemeItemResponse])
def get_schemes(
    level: Optional[str] = None,
    state: Optional[str] = None,
    query: Optional[str] = None,
    limit: int = Query(50, le=200),
    offset: int = Query(0),
    db: Session = Depends(get_db)
):
    q = db.query(Scheme)
    if level and level != "All":
        q = q.filter(Scheme.level.ilike(f"%{level}%"))
    if state and state != "All":
        q = q.filter((Scheme.state.ilike(f"%{state}%")) | (Scheme.level.ilike("Central")))
    if query:
        q = q.filter((Scheme.scheme_name.ilike(f"%{query}%")) | (Scheme.tags.ilike(f"%{query}%")))

    schemes = q.offset(offset).limit(limit).all()

    default_patient = PatientProfileInput(
        age=30,
        state=state if state else "All India",
        income_range="2.5 - 5 Lakh"
    )

    results = []
    for s in schemes:
        eval_result = EligibilityEngine.evaluate_scheme(s, default_patient)
        benefits_list = [b.strip() for b in re.split(r'[\n•;.]', s.benefits or "") if len(b.strip()) > 5][:3]
        tags_list = [t.strip() for t in (s.tags or "").split(",") if t.strip()][:4]

        results.append(SchemeItemResponse(
            scheme_id=s.scheme_id,
            scheme_name=s.scheme_name,
            level=s.level,
            state=s.state,
            short_description=(s.details[:160] + "...") if s.details and len(s.details) > 160 else (s.details or ""),
            benefits_summary=benefits_list if benefits_list else ["Comprehensive health coverage & benefits"],
            tags=tags_list,
            evaluation=eval_result,
        ))

    return results

# =========================================================================
# 3. POST /schemes/check-eligibility - Deterministic Rules Evaluation
# =========================================================================
@app.post("/schemes/check-eligibility", response_model=EligibilityCheckResponse)
def check_eligibility(
    profile: PatientProfileInput,
    limit: int = Query(100, le=300),
    db: Session = Depends(get_db)
):
    """
    Evaluates patient profile against all health schemes deterministically.
    """
    all_schemes = db.query(Scheme).all()

    likely_eligible: List[SchemeItemResponse] = []
    verification_req: List[SchemeItemResponse] = []
    likely_not: List[SchemeItemResponse] = []

    for s in all_schemes:
        eval_result = EligibilityEngine.evaluate_scheme(s, profile)
        benefits_list = [b.strip() for b in re.split(r'[\n•;.]', s.benefits or "") if len(b.strip()) > 5][:3]
        tags_list = [t.strip() for t in (s.tags or "").split(",") if t.strip()][:4]

        item = SchemeItemResponse(
            scheme_id=s.scheme_id,
            scheme_name=s.scheme_name,
            level=s.level,
            state=s.state,
            short_description=(s.details[:150] + "...") if s.details and len(s.details) > 150 else (s.details or ""),
            benefits_summary=benefits_list if benefits_list else ["Government health subsidy and hospitalization cover."],
            tags=tags_list,
            evaluation=eval_result,
        )

        if eval_result.status == "likely_eligible":
            likely_eligible.append(item)
        elif eval_result.status == "verification_required":
            verification_req.append(item)
        else:
            likely_not.append(item)

    # Sort results: Likely Eligible first, then Verification Required, then Likely Not
    sorted_results = likely_eligible + verification_req + likely_not
    max_limit = int(limit) if isinstance(limit, (int, float)) else 100
    limited_results = sorted_results[:max_limit]

    profile_summary = f"Age: {profile.age} • {profile.state} • {profile.income_range} Income"

    return EligibilityCheckResponse(
        total_schemes_evaluated=len(all_schemes),
        likely_eligible_count=len(likely_eligible),
        verification_required_count=len(verification_req),
        likely_not_eligible_count=len(likely_not),
        profile_summary=profile_summary,
        results=limited_results,
    )

# =========================================================================
# 4. GET /schemes/{scheme_id} - Scheme Details
# =========================================================================
@app.get("/schemes/{scheme_id}", response_model=SchemeDetailResponse)
def get_scheme_detail(
    scheme_id: str,
    age: Optional[int] = None,
    state: Optional[str] = None,
    income_range: Optional[str] = None,
    gender: Optional[str] = None,
    category: Optional[str] = None,
    db: Session = Depends(get_db)
):
    scheme = db.query(Scheme).filter(Scheme.scheme_id == scheme_id).first()
    if not scheme:
        raise HTTPException(status_code=404, detail="Scheme not found")

    # If patient query params are supplied, calculate personalized evaluation
    evaluation = None
    if age is not None and state is not None:
        patient = PatientProfileInput(
            age=age,
            state=state,
            income_range=income_range if income_range else "1 - 2.5 Lakh",
            gender=gender,
            category=category,
        )
        evaluation = EligibilityEngine.evaluate_scheme(scheme, patient)

    # Clean bullet points for benefits, steps, documents
    benefits_list = [b.strip() for b in re.split(r'[\n•;]', scheme.benefits or "") if len(b.strip()) > 8][:6]
    steps_list = [s.strip() for s in re.split(r'(?:Step \d+:|\n\d+\.|\n•)', scheme.application_process or "") if len(s.strip()) > 8][:6]
    if not steps_list:
        steps_list = [
            "Check and verify eligibility criteria.",
            "Gather required identity and income proofs.",
            "Visit the nearest CSC / District Health Centre / Hospital Desk or Official Portal.",
            "Submit the application form and biometric / document verification.",
            "Receive beneficiary health card / scheme approval."
        ]

    docs_list = [d.strip() for d in re.split(r'[\n•,;]', scheme.documents or "") if len(d.strip()) > 3][:6]
    if not docs_list:
        docs_list = ["Aadhaar Card", "Income Certificate / BPL Card", "State Domicile / Residence Proof", "Passport Size Photograph"]

    tags_list = [t.strip() for t in (scheme.tags or "").split(",") if t.strip()][:5]

    return SchemeDetailResponse(
        scheme_id=scheme.scheme_id,
        scheme_name=scheme.scheme_name,
        level=scheme.level,
        state=scheme.state,
        scheme_category=scheme.scheme_category,
        details=scheme.details or "No detailed description available.",
        benefits=scheme.benefits or "Financial assistance and healthcare treatment cover.",
        benefits_list=benefits_list if benefits_list else ["Full treatment support and financial subsidy."],
        eligibility_text=scheme.eligibility_text or "General citizen criteria apply.",
        application_process=scheme.application_process or "Online / At authorized health centre.",
        application_steps=steps_list,
        documents=scheme.documents or "Aadhaar Card, Income Certificate, Residence Proof.",
        documents_list=docs_list,
        tags=tags_list,
        official_url=scheme.official_url or "https://www.myscheme.gov.in",
        evaluation=evaluation,
    )

# =========================================================================
# 5. GET /schemes/{scheme_id}/application - Application Process & Steps
# =========================================================================
@app.get("/schemes/{scheme_id}/application")
def get_scheme_application(scheme_id: str, db: Session = Depends(get_db)):
    scheme = db.query(Scheme).filter(Scheme.scheme_id == scheme_id).first()
    if not scheme:
        raise HTTPException(status_code=404, detail="Scheme not found")

    steps = [s.strip() for s in re.split(r'(?:Step \d+:|\n\d+\.|\n•)', scheme.application_process or "") if len(s.strip()) > 8]
    if not steps:
        steps = [
            "Verify all eligibility conditions.",
            "Prepare self-attested copies of required documents.",
            "Visit the designated Government Hospital / CSC Kiosk or Portal.",
            "Submit application and biometric KYC.",
            "Download scheme e-Card or approval letter."
        ]

    return {
        "scheme_id": scheme.scheme_id,
        "scheme_name": scheme.scheme_name,
        "official_url": scheme.official_url,
        "application_process_text": scheme.application_process,
        "steps": steps,
        "required_documents": [d.strip() for d in re.split(r'[\n•,;]', scheme.documents or "") if len(d.strip()) > 3]
    }

# =========================================================================
# 6. POST /ai/explain - Grounded AI Scheme Explainer (Gemini API)
# =========================================================================
@app.post("/ai/explain", response_model=AiExplainResponse)
def explain_scheme_with_ai(request: AiExplainRequest, db: Session = Depends(get_db)):
    """
    Explains the scheme using Google Gemini AI grounded STRICTLY on official scheme facts.
    AI does NOT determine eligibility; only explains already-verified information.
    """
    scheme = db.query(Scheme).filter(Scheme.scheme_id == request.scheme_id).first()
    if not scheme:
        raise HTTPException(status_code=404, detail="Scheme not found")

    evaluation = None
    if request.patient_profile:
        evaluation = EligibilityEngine.evaluate_scheme(scheme, request.patient_profile)

    return GeminiSchemeExplainer.explain(
        scheme=scheme,
        evaluation=evaluation,
        patient_profile=request.patient_profile,
        question=request.question,
    )

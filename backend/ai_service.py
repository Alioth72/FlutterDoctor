import os
import json
import re
from typing import Optional, List, Dict, Any
from dotenv import load_dotenv

# Load .env configuration
load_dotenv()

try:
    from .models import Scheme, RuleEvaluation, PatientProfileInput, AiExplainResponse
except (ImportError, ValueError):
    from models import Scheme, RuleEvaluation, PatientProfileInput, AiExplainResponse

# Use modern official google.genai SDK
try:
    from google import genai
    from google.genai import types
    _GENAI_CLIENT_AVAILABLE = True
except ImportError:
    _GENAI_CLIENT_AVAILABLE = False


class GeminiSchemeExplainer:
    """
    Grounded AI Explainer powered by Google Gemini API (google-genai).
    Strictly explains already-verified information from the schemes database.
    Does NOT evaluate or invent eligibility criteria.
    """

    @classmethod
    def explain(
        cls,
        scheme: Scheme,
        evaluation: Optional[RuleEvaluation],
        patient_profile: Optional[PatientProfileInput],
        question: Optional[str] = None,
    ) -> AiExplainResponse:
        api_key = os.getenv("GEMINI_API_KEY")
        user_question = question or "Explain this scheme in simple language and why I may be eligible."

        # If Gemini API key is configured and google-genai is available, call Gemini
        if api_key and _GENAI_CLIENT_AVAILABLE:
            try:
                client = genai.Client(api_key=api_key)
                prompt = cls._build_grounded_prompt(scheme, evaluation, patient_profile, user_question)

                response = client.models.generate_content(
                    model="gemini-3.5-flash",
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        response_mime_type="application/json",
                        temperature=0.2,
                    ),
                )

                if response and response.text:
                    parsed = json.loads(response.text)
                    return AiExplainResponse(
                        scheme_id=scheme.scheme_id,
                        scheme_name=scheme.scheme_name,
                        explanation=parsed.get("explanation", cls._fallback_explanation(scheme, evaluation)),
                        key_highlights=parsed.get("key_highlights", cls._extract_highlights(scheme)),
                        required_documents=parsed.get("required_documents", cls._extract_documents(scheme)),
                        next_steps=parsed.get("next_steps", cls._extract_steps(scheme)),
                        source="Google Gemini 2.5 AI (Grounded on Scheme Database)",
                    )
            except Exception as e:
                print(f"[Gemini API Warning] Gemini generation failed: {e}. Using ground-truth factual fallback.")

        # Default Ground-Truth Fallback
        return cls._create_ground_truth_response(scheme, evaluation, patient_profile, user_question)

    @classmethod
    def _build_grounded_prompt(
        cls,
        scheme: Scheme,
        evaluation: Optional[RuleEvaluation],
        patient_profile: Optional[PatientProfileInput],
        question: str,
    ) -> str:
        eval_summary = ""
        if evaluation:
            eval_summary = f"""
Eligibility Engine Verification Status: {evaluation.status_badge} ({evaluation.status_label})
Matched Rules: {json.dumps(evaluation.matched_rules)}
Missing Information / Verification Needed: {json.dumps(evaluation.missing_information)}
Failed Rules: {json.dumps(evaluation.failed_rules)}
Engine Reason: {evaluation.reason}
"""

        profile_summary = ""
        if patient_profile:
            profile_summary = f"Patient: Age {patient_profile.age}, State: {patient_profile.state}, Income: {patient_profile.income_range}, Gender: {patient_profile.gender or 'Not specified'}"

        return f"""
You are an AI Healthcare Schemes Explainer for the Indian Government Health Portal.
YOUR ROLE: Explain already-verified government scheme information in simple, empathetic, and clear language.

CRITICAL CONSTRAINTS:
1. You do NOT determine eligibility. The Eligibility Engine has already computed the verified status.
2. Rely EXCLUSIVELY on the verified Scheme Facts below.
3. NEVER invent or hallucinate new criteria, numbers, benefits, documents, or steps not present in the facts.
4. Output strict JSON with the following keys:
   - "explanation": (A clear 2-3 paragraph explanation answering the question)
   - "key_highlights": [array of 3-4 concise string bullet points of actual benefits]
   - "required_documents": [array of 3-5 actual required documents from the scheme]
   - "next_steps": [array of 3-4 actionable application steps]

--- VERIFIED SCHEME FACTS ---
Scheme Name: {scheme.scheme_name}
Level: {scheme.level or 'Central'}
State: {scheme.state or 'All-India'}
Category: {scheme.scheme_category or 'Health & Wellness'}
Official Details: {scheme.details}
Official Benefits: {scheme.benefits}
Official Eligibility: {scheme.eligibility_text}
Application Process: {scheme.application_process}
Required Documents: {scheme.documents}
Official Portal URL: {scheme.official_url}

--- PATIENT PROFILE & EVALUATION ---
{profile_summary}
{eval_summary}

--- USER QUESTION ---
"{question}"
"""

    @classmethod
    def _create_ground_truth_response(
        cls,
        scheme: Scheme,
        evaluation: Optional[RuleEvaluation],
        patient_profile: Optional[PatientProfileInput],
        question: str,
    ) -> AiExplainResponse:
        eval_text = ""
        if evaluation:
            eval_text = f" Based on your verified details, your status is **{evaluation.status_label}**. {evaluation.reason}"

        explanation = (
            f"**{scheme.scheme_name}** is an official {scheme.level or 'Central'} government health initiative "
            f"designed to provide medical aid and financial protection. {scheme.details[:320]}...{eval_text}"
        )

        return AiExplainResponse(
            scheme_id=scheme.scheme_id,
            scheme_name=scheme.scheme_name,
            explanation=explanation,
            key_highlights=cls._extract_highlights(scheme),
            required_documents=cls._extract_documents(scheme),
            next_steps=cls._extract_steps(scheme),
            source="Ground Truth from Official Government Scheme Registry (Gemini Ready)",
        )

    @classmethod
    def _fallback_explanation(cls, scheme: Scheme, evaluation: Optional[RuleEvaluation]) -> str:
        eval_text = f" Status: {evaluation.status_label}." if evaluation else ""
        return f"{scheme.scheme_name} provides comprehensive healthcare assistance and financial coverage. {scheme.details[:250]}...{eval_text}"

    @classmethod
    def _extract_highlights(cls, scheme: Scheme) -> List[str]:
        items = [b.strip() for b in re.split(r'[\n•;.]', scheme.benefits or "") if len(b.strip()) > 8][:4]
        return items if items else ["Cashless medical cover and subsidies at empaneled hospitals", "Financial assistance for serious illnesses"]

    @classmethod
    def _extract_documents(cls, scheme: Scheme) -> List[str]:
        docs = [d.strip() for d in re.split(r'[\n•,;]', scheme.documents or "") if len(d.strip()) > 3][:5]
        return docs if docs else ["Aadhaar Card (Identity Proof)", "Income Certificate / BPL Card", "Residence Proof"]

    @classmethod
    def _extract_steps(cls, scheme: Scheme) -> List[str]:
        steps = [s.strip() for s in re.split(r'(?:Step \d+:|\n\d+\.|\n•)', scheme.application_process or "") if len(s.strip()) > 8][:3]
        if not steps:
            return [
                "Verify your eligibility criteria and gather required identification documents.",
                f"Visit the official portal at {scheme.official_url or 'https://www.myscheme.gov.in'} or nearest Government CSC Kiosk.",
                "Complete biometric KYC and submit your application for approval."
            ]
        return steps

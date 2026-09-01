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
    Grounded AI Explainer powered by Google Gemini API.
    Provides comprehensive, ultra-clear, and rural-friendly explanations
    of all required documents and step-by-step application instructions.
    Strictly grounded on verified government scheme facts.
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
        user_question = question or "Explain all required documents and step-by-step how to apply in simple language for a rural person."

        # If Gemini API key is configured and google-genai is available, call Gemini
        if api_key and _GENAI_CLIENT_AVAILABLE:
            models_to_try = ["gemini-3.6-flash", "gemini-3.7-flash", "gemini-3.5-flash-lite", "gemini-3.5-flash"]
            for model_name in models_to_try:
                try:
                    client = genai.Client(api_key=api_key)
                    prompt = cls._build_grounded_prompt(scheme, evaluation, patient_profile, user_question)

                    response = client.models.generate_content(
                        model=model_name,
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
                            source=f"Google Gemini AI ({model_name} - Rural-Friendly Grounded Explainer)",
                        )
                except Exception as e:
                    print(f"[Gemini API Notice] Model {model_name} returned: {e}. Trying next fallback...")

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
You are an expert Indian Government Schemes & Healthcare Advisor.
YOUR GOAL: Explain this scheme in very simple, easy-to-understand language. Use clear bullet points and numbers so that anyone—especially a person from a village with no technical or phone knowledge—can easily understand what documents they need and exactly how to apply.

CRITICAL INSTRUCTIONS:
1. YOU DO NOT DETERMINE ELIGIBILITY. The official engine has already verified their status.
2. Rely strictly on the official facts provided below without hallucinating.
3. "required_documents": MUST be a list of clear, simple points. Mention every needed document in simple everyday words (e.g. "Aadhaar Card: Your 12-digit identity proof", "Bank Passbook: Front page copy showing your account number and IFSC code for receiving money", "Ration Card / Income Certificate: Proof of your family income from Tehsil or Panchayat", "Doctor Slip / Hospital Report: Medical bills or doctor prescription stamped by the hospital").
4. "next_steps": MUST be a list of simple, easy step-by-step points on how to apply offline/in-person:
   - "Point 1: Get 2 photocopies (xerox) of all your documents and 2 passport-size photos ready."
   - "Point 2: Go to your nearest Jan Seva Kendra (CSC) or Government Hospital Helpdesk."
   - "Point 3: Give your papers to the counter operator and say you want to apply for {scheme.scheme_name}."
   - "Point 4: Put your thumb on the biometric machine when the operator asks."
   - "Point 5: Take the printed application receipt with your tracking number."
5. Format your output strictly as a JSON object with:
   - "explanation": (2 short paragraphs in very simple and friendly words)
   - "key_highlights": [list of 3-4 simple points of key benefits]
   - "required_documents": [list of simple points for every required document]
   - "next_steps": [list of clear, numbered step-by-step application points]

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
            source="Ground Truth from Official Government Scheme Registry",
        )

    @classmethod
    def _fallback_explanation(cls, scheme: Scheme, evaluation: Optional[RuleEvaluation]) -> str:
        eval_text = f" Status: {evaluation.status_label}." if evaluation else ""
        return f"{scheme.scheme_name} provides comprehensive healthcare assistance and financial coverage. {scheme.details[:250]}...{eval_text}"

    @classmethod
    def _extract_highlights(cls, scheme: Scheme) -> List[str]:
        items = [b.strip() for b in re.split(r'[\n•;.]', scheme.benefits or "") if len(b.strip()) > 8][:5]
        return items if items else ["Cashless medical cover and subsidies at empaneled hospitals", "Financial assistance for serious illnesses"]

    @classmethod
    def _extract_documents(cls, scheme: Scheme) -> List[str]:
        raw_docs = [d.strip() for d in re.split(r'[\n•;]', scheme.documents or "") if len(d.strip()) > 3]
        if not raw_docs:
            return [
                "Aadhaar Card (12-digit identity card of the patient)",
                "Income Certificate / BPL Ration Card (Issued by Tehsil or Gram Panchayat)",
                "Residence / Domicile Certificate (Proof of living in the state)",
                "Bank Passbook (First page showing Account Number and IFSC Code for direct bank transfer)",
                "2 Recent Passport-Size Photographs",
                "Hospital Admission / Doctor Prescription Slip (Countersigned by Government Hospital Doctor)"
            ]
        return raw_docs

    @classmethod
    def _extract_steps(cls, scheme: Scheme) -> List[str]:
        raw_steps = [s.strip() for s in re.split(r'(?:Step \d+:|\n\d+\.|\n•)', scheme.application_process or "") if len(s.strip()) > 8]
        if raw_steps and len(raw_steps) >= 3:
            return raw_steps

        portal = scheme.official_url or "https://www.myscheme.gov.in"
        return [
            "Step 1 (Gather Documents): Take your Aadhaar card, bank passbook, income/ration card, and 2 passport photos. Make 2 photocopies (xerox) of each paper.",
            "Step 2 (Visit Nearby Kendra): Walk in to your nearest Common Service Centre (CSC / Jan Seva Kendra / Pragya Kendra / Panchayat Bhawan) or the Health Helpdesk at your nearest Government District Hospital.",
            f"Step 3 (Operator Assistance): Tell the counter operator: 'I want to apply for {scheme.scheme_name}'. Give them your photocopies.",
            "Step 4 (Biometric Scan & Verification): The operator will enter your details on the official government portal (" + portal + ") and ask you to put your thumb on the biometric scanner.",
            "Step 5 (Collect Receipt): Take the printed application receipt with your tracking number. The approval letter/e-card will be issued directly."
        ]

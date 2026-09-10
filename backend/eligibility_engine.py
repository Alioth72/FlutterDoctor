import re
from typing import Dict, Any, List, Tuple

try:
    from .models import PatientProfileInput, RuleEvaluation, Scheme
except (ImportError, ValueError):
    from models import PatientProfileInput, RuleEvaluation, Scheme

# Numeric income estimate map for standard Indian ranges
INCOME_RANGE_MAP = {
    "< 1 Lakh": 75000,
    "1 - 2.5 Lakh": 180000,
    "2.5 - 5 Lakh": 375000,
    "5 - 8 Lakh": 650000,
    "> 8 Lakh": 1000000,
    "BPL / EWS": 50000,
}

def normalize_caste(caste_str: str) -> str:
    if not caste_str or caste_str == "All":
        return "All"
    c_lower = caste_str.lower()
    if "scheduled caste" in c_lower or "(sc)" in c_lower or c_lower == "sc":
        return "SC"
    if "scheduled tribe" in c_lower or "(st)" in c_lower or c_lower == "st":
        return "ST"
    if "other backward" in c_lower or "(obc)" in c_lower or c_lower == "obc":
        return "OBC"
    if "pvtg" in c_lower or "particularly vulnerable" in c_lower:
        return "ST"
    if "dnt" in c_lower or "nomadic" in c_lower:
        return "OBC"
    if "general" in c_lower:
        return "General"
    return caste_str


def normalize_employment(emp_str: str) -> str:
    if not emp_str or emp_str == "All":
        return "All"
    e_lower = emp_str.lower()
    if "self-employed" in e_lower or "entrepreneur" in e_lower:
        return "Self-Employed"
    if "unemployed" in e_lower:
        return "Unemployed"
    if "employed" in e_lower:
        return "Employed"
    return emp_str


class EligibilityEngine:
    """
    Deterministic Python Rules Engine for Indian Government Health Schemes.
    Evaluates patient parameters against structured scheme criteria from myschemes.db.
    """

    @staticmethod
    def get_estimated_income(income_range: str, numeric: float = None) -> float:
        if numeric is not None and numeric > 0:
            return numeric
        return INCOME_RANGE_MAP.get(income_range, 200000)

    @classmethod
    def evaluate_scheme(cls, scheme: Scheme, patient: PatientProfileInput) -> RuleEvaluation:
        matched_rules: List[str] = []
        failed_rules: List[str] = []
        missing_info: List[str] = []

        patient_income = cls.get_estimated_income(patient.income_range, patient.income_numeric)
        is_patient_bpl = (
            patient.is_bpl is True or
            patient.is_hardship_distress is True or
            (patient.income_range and ("bpl" in patient.income_range.lower() or patient.income_range in ["< 1 Lakh", "1 - 2.5 Lakh"])) or
            patient_income <= 250000
        )

        # ----------------------------------------------------
        # 1. State Criteria Evaluation (Structured)
        # ----------------------------------------------------
        if scheme.eligible_state:
            req_state = scheme.eligible_state.strip().lower()
            pat_state = (patient.state or "All").strip().lower()

            if pat_state in ["all", "all states"] or pat_state == req_state or req_state in pat_state:
                matched_rules.append(f"State residency satisfied ({scheme.eligible_state})")
            else:
                failed_rules.append(f"Scheme restricted to residents of {scheme.eligible_state} (You selected: {patient.state})")
        else:
            matched_rules.append(f"All-India / Central Scheme coverage applicable in {patient.state}")

        # ----------------------------------------------------
        # 2. Gender Criteria Evaluation (Structured + Text fallback)
        # ----------------------------------------------------
        req_gender = (scheme.eligible_gender or "").strip()
        if req_gender and req_gender.lower() not in ["all", "none", "both"]:
            if patient.gender:
                if patient.gender.lower() == req_gender.lower():
                    matched_rules.append(f"Gender criteria satisfied ({req_gender} beneficiary)")
                else:
                    failed_rules.append(f"Scheme is tailored for {req_gender} beneficiaries (Selected: {patient.gender})")
            else:
                missing_info.append(f"Gender verification needed ({req_gender} beneficiary)")
        else:
            matched_rules.append("Gender criteria compatible (Open to all genders)")

        # ----------------------------------------------------
        # 3. Age Criteria Evaluation (Structured Bounds [age_min, age_max])
        # ----------------------------------------------------
        age_passed = True
        if scheme.age_min is not None and patient.age < scheme.age_min:
            failed_rules.append(f"Requires minimum age of {scheme.age_min} years (Your age: {patient.age} yrs)")
            age_passed = False
        if scheme.age_max is not None and patient.age > scheme.age_max:
            failed_rules.append(f"Requires maximum age of {scheme.age_max} years (Your age: {patient.age} yrs)")
            age_passed = False

        if age_passed:
            matched_rules.append(f"Age criteria compatible (Age: {patient.age})")

        # ----------------------------------------------------
        # 4. Caste / Social Category Criteria (Structured)
        # ----------------------------------------------------
        if scheme.eligible_caste and scheme.eligible_caste.strip() not in ["All", "Both", ""]:
            req_caste = scheme.eligible_caste.strip()
            pat_caste = normalize_caste(patient.category)
            if pat_caste in ["All", req_caste]:
                matched_rules.append(f"Social category criteria satisfied ({req_caste})")
            else:
                failed_rules.append(f"Scheme reserved for {req_caste} beneficiaries (Selected: {patient.category})")

        # ----------------------------------------------------
        # 5. Disability Criteria (Structured)
        # ----------------------------------------------------
        if scheme.disability_only and str(scheme.disability_only).strip().lower() in ["yes", "true"]:
            pat_dis = patient.disability
            has_dis = pat_dis and str(pat_dis).strip().lower() not in ["no", "none", "false"]
            if has_dis:
                matched_rules.append("Disability assistance criteria satisfied")
            else:
                failed_rules.append("Scheme is reserved for Persons with Disabilities (Divyangjan)")

        # ----------------------------------------------------
        # 6. Minority Criteria (Structured)
        # ----------------------------------------------------
        if scheme.minority_only and str(scheme.minority_only).strip().lower() in ["yes", "true"]:
            is_min = patient.is_minority is True or (patient.minority_status and patient.minority_status.lower() == "yes")
            if is_min:
                matched_rules.append("Minority community criteria satisfied")
            else:
                failed_rules.append("Scheme is tailored for notified minority communities")

        # ----------------------------------------------------
        # 7. Student & Employment Criteria (Structured)
        # ----------------------------------------------------
        if scheme.student_only and str(scheme.student_only).strip().lower() in ["yes", "true"]:
            is_stud = patient.is_student is True or str(patient.is_student).lower() in ["yes", "true"]
            if is_stud:
                matched_rules.append("Student status criteria satisfied")
            else:
                failed_rules.append("Scheme is reserved for active students")

        if scheme.eligible_employment_status and scheme.eligible_employment_status.strip() not in ["All", ""]:
            req_emp = scheme.eligible_employment_status.strip()
            pat_emp = normalize_employment(patient.employment_status or patient.occupation)
            if pat_emp in ["All", req_emp]:
                matched_rules.append(f"Employment criteria satisfied ({req_emp})")
            else:
                failed_rules.append(f"Scheme tailored for {req_emp} individuals")

        # ----------------------------------------------------
        # 8. Economic / Income Ceiling Evaluation
        # ----------------------------------------------------
        text_lower = (
            (scheme.name or "") + " " +
            (scheme.brief_description or "") + " " +
            (scheme.detailed_description or "") + " " +
            (scheme.tags or "") + " " +
            (scheme.benefits or "")
        ).lower()

        is_bpl_only = any(term in text_lower for term in [
            "bpl", "below poverty line", "ayushman bharat", "pm-jay", "secc",
            "low income", "economically weaker", "ews"
        ])

        if is_bpl_only:
            if is_patient_bpl:
                matched_rules.append(f"Economic criteria satisfied ({patient.income_range} / EWS tier)")
            elif patient_income <= 500000:
                missing_info.append("BPL Ration Card / Income Certificate verification required")
            else:
                failed_rules.append(f"Income exceeds target welfare ceiling (Selected: {patient.income_range})")
        else:
            matched_rules.append("Universal access (No restrictive income cap)")

        # ----------------------------------------------------
        # 9. Final Decision
        # ----------------------------------------------------
        if len(failed_rules) == 0 and len(missing_info) == 0:
            status = "likely_eligible"
            status_label = "You may be eligible"
            status_badge = "🟢 You May Be Eligible"
            reason = "Your profile satisfies all core demographic, state, and eligibility requirements."
        elif len(failed_rules) == 0 and len(missing_info) > 0:
            status = "verification_required"
            status_label = "Verification required"
            status_badge = "🟡 Verification Required"
            reason = f"You match basic criteria, but additional verification ({', '.join(missing_info)}) is needed."
        else:
            status = "likely_not_eligible"
            status_label = "Likely not eligible"
            status_badge = "🔴 Likely Not Eligible"
            reason = f"Criteria mismatch: {failed_rules[0]}"

        return RuleEvaluation(
            status=status,
            status_label=status_label,
            status_badge=status_badge,
            matched_rules=matched_rules,
            failed_rules=failed_rules,
            missing_information=missing_info,
            reason=reason,
        )

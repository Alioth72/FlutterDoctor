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

class EligibilityEngine:
    """
    Deterministic Python Rules Engine for Indian Government Health Schemes.
    Evaluates patient parameters against scheme criteria without using LLMs.
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
        text_lower = (
            (scheme.scheme_name or "") + " " +
            (scheme.details or "") + " " +
            (scheme.eligibility_text or "") + " " +
            (scheme.tags or "") + " " +
            (scheme.benefits or "")
        ).lower()

        # ----------------------------------------------------
        # 1. State Criteria Evaluation
        # ----------------------------------------------------
        scheme_level = (scheme.level or "Central").strip()
        scheme_state = (scheme.state or "").strip().lower()

        if scheme_level.lower() == "state" and scheme_state:
            if patient.state.lower() == scheme_state or scheme_state in patient.state.lower():
                matched_rules.append(f"State residency satisfied ({patient.state})")
            else:
                failed_rules.append(f"Scheme is restricted to residents of {scheme.state} (You selected {patient.state})")
        else:
            matched_rules.append(f"All-India / Central Scheme coverage applicable in {patient.state}")

        # ----------------------------------------------------
        # 2. Gender & Maternity Criteria Evaluation
        # ----------------------------------------------------
        is_female_only = any(term in text_lower for term in [
            "women only", "pregnant women", "lactating mother", "maternity benefit",
            "female beneficiary", "girls only", "mother and child", "widow pension"
        ])
        is_maternity = any(term in text_lower for term in ["pregnant", "lactating", "maternity", "janani"])

        if is_female_only or is_maternity:
            if patient.gender:
                if patient.gender.lower() == "female":
                    matched_rules.append("Gender/Maternity criteria satisfied (Female beneficiary)")
                else:
                    failed_rules.append(f"Scheme is tailored for female/maternal beneficiaries (Selected: {patient.gender})")
            else:
                missing_info.append("Gender verification required for women/maternity scheme")

        # ----------------------------------------------------
        # 3. Age Criteria Evaluation
        # ----------------------------------------------------
        # Check Senior citizen (> 60)
        is_senior = any(term in text_lower for term in ["senior citizen", "vayo", "60 years and above", "elderly", "old age"])
        is_child = any(term in text_lower for term in ["infant", "child", "children below", "0-6 years", "paediatric", "school children"])

        if is_senior:
            if patient.age >= 60:
                matched_rules.append(f"Senior Citizen age criteria satisfied ({patient.age} yrs >= 60)")
            else:
                failed_rules.append(f"Requires age 60+ (Your age: {patient.age} yrs)")

        elif is_child:
            if patient.age <= 18:
                matched_rules.append(f"Child/Youth age criteria satisfied (Age {patient.age} <= 18)")
            else:
                failed_rules.append(f"Requires age <= 18 years (Your age: {patient.age} yrs)")
        else:
            matched_rules.append(f"Age criteria compatible (Age: {patient.age})")

        # ----------------------------------------------------
        # 4. Income / Economic Ceiling Evaluation
        # ----------------------------------------------------
        is_bpl_only = any(term in text_lower for term in [
            "bpl", "below poverty line", "ayushman bharat", "pm-jay", "secc", "ration card holder",
            "low income", "economically weaker", "ews"
        ])

        if is_bpl_only:
            if patient_income <= 300000 or "bpl" in patient.income_range.lower() or patient.income_range == "< 1 Lakh" or patient.income_range == "1 - 2.5 Lakh":
                matched_rules.append(f"Income threshold satisfied ({patient.income_range} <= ₹3.0 Lakhs / EWS)")
            elif patient_income <= 500000:
                missing_info.append("Income proof or Ration Card (BPL/NFSA) verification required")
            else:
                failed_rules.append(f"Income exceeds target ceiling of ₹3.0 Lakhs/yr (Selected: {patient.income_range})")
        else:
            matched_rules.append("Universal health access (No restrictive income cap)")

        # ----------------------------------------------------
        # 5. Disability Criteria Evaluation
        # ----------------------------------------------------
        is_disability_scheme = any(term in text_lower for term in [
            "differently abled", "disability", "divyang", "handicapped", "assistive devices"
        ])

        if is_disability_scheme:
            if patient.disability and patient.disability.lower() not in ["none", "no"]:
                matched_rules.append(f"Disability criteria satisfied ({patient.disability})")
            elif patient.disability and patient.disability.lower() in ["none", "no"]:
                failed_rules.append("Scheme is reserved for Persons with Disabilities (Divyangjan)")
            else:
                missing_info.append("Disability certificate verification needed")

        # ----------------------------------------------------
        # 6. Social Category / Caste Criteria Evaluation
        # ----------------------------------------------------
        is_sc_st_only = any(term in text_lower for term in ["sc/st only", "tribal health", "scheduled caste", "scheduled tribe"])

        if is_sc_st_only:
            if patient.category:
                if patient.category.upper() in ["SC", "ST"]:
                    matched_rules.append(f"Social category criteria satisfied ({patient.category})")
                else:
                    failed_rules.append(f"Scheme reserved for SC/ST beneficiaries (Selected: {patient.category})")
            else:
                missing_info.append("Caste certificate verification needed")

        # ----------------------------------------------------
        # 7. Final Deterministic Status Decision
        # ----------------------------------------------------
        if len(failed_rules) == 0 and len(missing_info) == 0:
            status = "likely_eligible"
            status_label = "You may be eligible"
            status_badge = "🟢 You May Be Eligible"
            reason = "Your profile satisfies all core demographic and economic eligibility requirements."
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

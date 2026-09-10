#!/usr/bin/env python3
"""
match_schemes.py - Matching engine for healthcare Flutter app backend.

Matches user demographic details (entered in the Flutter UI form) against
the government schemes database and returns both the total count of available
schemes and the matching scheme records.
"""

import argparse
import json
import sqlite3
import os
from typing import Any, Dict, List, Optional, Tuple

DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "myschemes.db")

# Query matching against a persisted user_profile row by user_id
MATCHING_QUERY_BY_USER_ID = """
SELECT s.* FROM schemes s, user_profile u
WHERE u.user_id = ?
  AND s.category LIKE '%Health%'
  AND (s.eligible_gender IS NULL OR s.eligible_gender = u.gender)
  AND (s.age_min IS NULL OR u.age >= s.age_min)
  AND (s.age_max IS NULL OR u.age <= s.age_max)
  AND (s.eligible_employment_status IS NULL OR u.employment_status = 'All' OR s.eligible_employment_status = u.employment_status)
  AND (s.student_only IS NULL OR s.student_only = u.is_student)
  AND (s.eligible_caste IS NULL OR s.eligible_caste = 'All' OR u.caste = 'All' OR s.eligible_caste = u.caste)
  AND (s.minority_only IS NULL OR u.minority_status = 'Yes')
  AND (s.disability_only IS NULL OR u.disability = 'Yes')
  AND (s.eligible_residence IS NULL OR s.eligible_residence = 'Both' OR u.residence = 'Both' OR s.eligible_residence = u.residence)
  AND (s.eligible_state IS NULL OR u.state = 'All' OR s.eligible_state = u.state)
ORDER BY s.name ASC;
"""

# Direct matching query using parameterized values from Flutter form
DIRECT_MATCHING_SQL = """
SELECT s.* FROM schemes s
WHERE s.category LIKE '%Health%'
  -- Gender: User must match scheme restriction or scheme is open to all
  AND (s.eligible_gender IS NULL OR s.eligible_gender = :gender)
  -- Age: User age must be within [age_min, age_max]
  AND (s.age_min IS NULL OR :age >= s.age_min)
  AND (s.age_max IS NULL OR :age <= s.age_max)
  -- Employment: 'All' matches any, otherwise exact match or unrestricted
  AND (s.eligible_employment_status IS NULL OR :employment_status = 'All' OR s.eligible_employment_status = :employment_status)
  -- Student: If student_only is 'Yes', user must be student
  AND (s.student_only IS NULL OR s.student_only = :is_student)
  -- Caste: 'All' matches any, otherwise matches caste restriction or unrestricted
  AND (s.eligible_caste IS NULL OR s.eligible_caste = 'All' OR :caste = 'All' OR s.eligible_caste = :caste)
  -- Minority: If scheme is minority_only, user must be minority
  AND (s.minority_only IS NULL OR :minority_status = 'Yes')
  -- Disability: If scheme is disability_only, user must have disability
  AND (s.disability_only IS NULL OR :disability = 'Yes')
  -- Residence: 'Both' matches any, otherwise exact or unrestricted
  AND (s.eligible_residence IS NULL OR s.eligible_residence = 'Both' OR :residence = 'Both' OR s.eligible_residence = :residence)
  -- State: 'All' matches any, otherwise exact state or Central (NULL)
  AND (s.eligible_state IS NULL OR :state = 'All' OR :state = 'All States' OR s.eligible_state = :state)
  -- Optional Keyword / Search term
  AND (
    :keyword IS NULL OR :keyword = ''
    OR s.name LIKE '%' || :keyword || '%'
    OR s.brief_description LIKE '%' || :keyword || '%'
    OR s.tags LIKE '%' || :keyword || '%'
    OR s.category LIKE '%' || :keyword || '%'
  )
ORDER BY s.name ASC;
"""

DIRECT_COUNT_SQL = """
SELECT COUNT(*) FROM schemes s
WHERE s.category LIKE '%Health%'
  AND (s.eligible_gender IS NULL OR s.eligible_gender = :gender)
  AND (s.age_min IS NULL OR :age >= s.age_min)
  AND (s.age_max IS NULL OR :age <= s.age_max)
  AND (s.eligible_employment_status IS NULL OR :employment_status = 'All' OR s.eligible_employment_status = :employment_status)
  AND (s.student_only IS NULL OR s.student_only = :is_student)
  AND (s.eligible_caste IS NULL OR s.eligible_caste = 'All' OR :caste = 'All' OR s.eligible_caste = :caste)
  AND (s.minority_only IS NULL OR :minority_status = 'Yes')
  AND (s.disability_only IS NULL OR :disability = 'Yes')
  AND (s.eligible_residence IS NULL OR s.eligible_residence = 'Both' OR :residence = 'Both' OR s.eligible_residence = :residence)
  AND (s.eligible_state IS NULL OR :state = 'All' OR :state = 'All States' OR s.eligible_state = :state)
  AND (
    :keyword IS NULL OR :keyword = ''
    OR s.name LIKE '%' || :keyword || '%'
    OR s.brief_description LIKE '%' || :keyword || '%'
    OR s.tags LIKE '%' || :keyword || '%'
    OR s.category LIKE '%' || :keyword || '%'
  );
"""


def upsert_user_profile(
    conn: sqlite3.Connection,
    user_id: str,
    gender: str,
    age: int,
    employment_status: str = "All",
    is_student: str = "No",
    caste: str = "All",
    minority_status: str = "No",
    disability: str = "No",
    residence: str = "Both",
    state: str = "All"
) -> Dict[str, Any]:
    """Insert or update user profile in SQLite."""
    cursor = conn.cursor()
    cursor.execute("""
        INSERT INTO user_profile (
            user_id, gender, age, employment_status, is_student,
            caste, minority_status, disability, residence, state
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(user_id) DO UPDATE SET
            gender=excluded.gender,
            age=excluded.age,
            employment_status=excluded.employment_status,
            is_student=excluded.is_student,
            caste=excluded.caste,
            minority_status=excluded.minority_status,
            disability=excluded.disability,
            residence=excluded.residence,
            state=excluded.state,
            updated_at=CURRENT_TIMESTAMP;
    """, (
        user_id, gender, age, employment_status, is_student,
        caste, minority_status, disability, residence, state
    ))
    conn.commit()
    
    return {
        "user_id": user_id,
        "gender": gender,
        "age": age,
        "employment_status": employment_status,
        "is_student": is_student,
        "caste": caste,
        "minority_status": minority_status,
        "disability": disability,
        "residence": residence,
        "state": state
    }


def normalize_caste(caste_str: str) -> str:
    """Normalize full caste names from wizard UI to schema caste codes."""
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
    """Normalize employment status from wizard UI."""
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


def find_schemes_for_form_input(
    conn: sqlite3.Connection,
    gender: str,
    age: int,
    employment_status: str = "All",
    is_student: str = "No",
    caste: str = "All",
    minority_status: str = "No",
    disability: str = "No",
    residence: str = "Both",
    state: str = "All",
    keyword: Optional[str] = None,
    is_bpl: str = "No",
    is_distress: str = "No"
) -> Tuple[int, List[Dict[str, Any]]]:
    """
    Directly query the database using the demographic inputs from the Flutter UI form.
    Returns (available_count, matching_schemes_list).
    """
    normalized_caste = normalize_caste(caste)
    normalized_emp = normalize_employment(employment_status)

    params = {
        "gender": gender,
        "age": int(age),
        "employment_status": normalized_emp,
        "is_student": is_student,
        "caste": normalized_caste,
        "minority_status": minority_status,
        "disability": disability,
        "residence": residence,
        "state": state,
        "keyword": keyword.strip() if keyword else None
    }
    
    cursor = conn.cursor()
    cursor.execute(DIRECT_COUNT_SQL, params)
    available_count = cursor.fetchone()[0]
    
    cursor.execute(DIRECT_MATCHING_SQL, params)
    rows = cursor.fetchall()
    cols = [desc[0] for desc in cursor.description]
    
    schemes = []
    for r in rows:
        item = dict(zip(cols, r))
        item.pop("raw_json", None)  # Omit heavy raw json from client payload
        schemes.append(item)
        
    return available_count, schemes


def match_schemes_for_user(conn: sqlite3.Connection, user_id: str) -> List[Dict[str, Any]]:
    """Given a user_id stored in user_profile table, return all matching schemes."""
    cursor = conn.cursor()
    cursor.execute(MATCHING_QUERY_BY_USER_ID, (user_id,))
    rows = cursor.fetchall()
    cols = [desc[0] for desc in cursor.description]
    
    results = []
    for r in rows:
        item = dict(zip(cols, r))
        item.pop("raw_json", None)
        results.append(item)
        
    return results


def main():
    parser = argparse.ArgumentParser(description="Find matching government health schemes for Flutter user form")
    parser.add_argument("--db-path", default=DB_PATH, help="Path to SQLite database")
    parser.add_argument("--gender", choices=["Male", "Female", "Transgender"], default="Male", help="Gender (default: Male)")
    parser.add_argument("--age", type=int, default=45, help="Age in years (default: 45)")
    parser.add_argument("--employment", choices=["All", "Employed", "Unemployed", "Self-Employed"], default="All")
    parser.add_argument("--is-student", choices=["Yes", "No"], default="No")
    parser.add_argument("--caste", choices=["All", "General", "OBC", "SC", "ST"], default="All")
    parser.add_argument("--minority", choices=["Yes", "No"], default="No")
    parser.add_argument("--disability", choices=["Yes", "No"], default="No")
    parser.add_argument("--residence", choices=["Both", "Urban", "Rural"], default="Both")
    parser.add_argument("--state", default="All", help="State / UT name, or 'All'/'All States'")
    parser.add_argument("--keyword", default=None, help="Optional category / search keyword (e.g. cancer, maternity)")
    parser.add_argument("--user-id", default=None, help="Optional user_id if storing profile in user_profile table")
    parser.add_argument("--json", action="store_true", help="Output result as JSON")
    args = parser.parse_args()

    conn = sqlite3.connect(args.db_path)

    if args.user_id:
        upsert_user_profile(
            conn=conn,
            user_id=args.user_id,
            gender=args.gender,
            age=args.age,
            employment_status=args.employment,
            is_student=args.is_student,
            caste=args.caste,
            minority_status=args.minority,
            disability=args.disability,
            residence=args.residence,
            state=args.state
        )

    count, schemes = find_schemes_for_form_input(
        conn=conn,
        gender=args.gender,
        age=args.age,
        employment_status=args.employment,
        is_student=args.is_student,
        caste=args.caste,
        minority_status=args.minority,
        disability=args.disability,
        residence=args.residence,
        state=args.state,
        keyword=args.keyword
    )

    if args.json:
        print(json.dumps({
            "status": "success",
            "available_schemes_count": count,
            "filters_applied": {
                "gender": args.gender,
                "age": args.age,
                "employment_status": args.employment,
                "is_student": args.is_student,
                "caste": args.caste,
                "minority_status": args.minority,
                "disability": args.disability,
                "residence": args.residence,
                "state": args.state,
                "keyword": args.keyword
            },
            "schemes": schemes
        }, indent=2, ensure_ascii=False))
    else:
        print("\n" + "=" * 65)
        print("FLUTTER HEALTHCARE APP - FIND SCHEMES RESULT")
        print("=" * 65)
        print(f"Demographics: Gender={args.gender}, Age={args.age}, Employment={args.employment}, "
              f"Student={args.is_student}, Caste={args.caste}, Disability={args.disability}, "
              f"Residence={args.residence}, State={args.state}")
        if args.keyword:
            print(f"Keyword Filter: '{args.keyword}'")
        print("-" * 65)
        print(f">>> AVAILABLE SCHEMES FOR USER: {count} schemes <<<")
        print("-" * 65)
        for i, s in enumerate(schemes[:10], 1):
            state_disp = s.get('eligible_state') or 'All-India'
            print(f"{i}. {s['name']} [{state_disp}]")
            print(f"   Benefits: {(s.get('benefits') or s.get('brief_description') or '')[:100]}...")
            if s.get('apply_url'):
                print(f"   Apply: {s['apply_url']}")
        if count > 10:
            print(f"\n... and {count - 10} more schemes available.")


if __name__ == "__main__":
    main()

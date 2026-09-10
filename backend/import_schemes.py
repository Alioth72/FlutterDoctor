import csv
import os
import re
from sqlalchemy.orm import Session

try:
    from .database import engine, SessionLocal, Base
    from .models import Scheme, SchemeRule
except (ImportError, ValueError):
    from database import engine, SessionLocal, Base
    from models import Scheme, SchemeRule

EXPLICIT_HEALTH_TERMS = [
    'health', 'medical', 'hospital', 'treatment', 'disease', 'maternity',
    'disability', 'medicine', 'insurance', 'senior citizen', 'ayushman',
    'cancer', 'tb', 'tuberculosis', 'dialysis', 'differently abled', 'pregnant',
    'lactating', 'nutrition', 'swasthya', 'arogya', 'janani', 'poshan', 'immunization',
    'mental health', 'blood bank', 'dispensary', 'ambulance', 'surgery', 'divyang',
    'janaushadhi', 'silicosis', 'illness', 'physically challenged', 'chemotherapy'
]

INDIAN_STATES = [
    "Andhra Pradesh", "Arunachal Pradesh", "Assam", "Bihar", "Chhattisgarh", "Goa",
    "Gujarat", "Haryana", "Himachal Pradesh", "Jharkhand", "Karnataka", "Kerala",
    "Madhya Pradesh", "Maharashtra", "Manipur", "Meghalaya", "Mizoram", "Nagaland",
    "Odisha", "Punjab", "Rajasthan", "Sikkim", "Tamil Nadu", "Telangana", "Tripura",
    "Uttar Pradesh", "Uttarakhand", "West Bengal", "Delhi", "Jammu and Kashmir",
    "Ladakh", "Puducherry", "Chandigarh", "Dadra and Nagar Haveli", "Daman and Diu",
    "Andaman and Nicobar Islands", "Lakshadweep"
]

def clean_text(text: str) -> str:
    if not text:
        return ""
    return re.sub(r'\s+', ' ', text).strip()

def detect_state(text: str) -> str:
    text_lower = text.lower()
    for state in INDIAN_STATES:
        if state.lower() in text_lower:
            return state
    return None

def detect_official_url(row: dict) -> str:
    all_text = row.get('application', '') + ' ' + row.get('details', '')
    urls = re.findall(r'https?://(?:[-\w.]|(?:%[\da-fA-F]{2}))+[^\s,;()"\']+', all_text)
    if urls:
        return urls[0]
    return "https://www.myscheme.gov.in"

def get_default_csv_path() -> str:
    """Dynamically resolve schemes.csv or updated_data.csv path relative to the backend directory."""
    current_dir = os.path.dirname(os.path.abspath(__file__))
    candidates = [
        os.path.join(current_dir, "schemes.csv"),
        os.path.join(current_dir, "updated_data.csv"),
        os.path.join(os.path.dirname(current_dir), "schemes.csv"),
        os.path.join(os.path.dirname(current_dir), "updated_data.csv"),
    ]
    for c in candidates:
        if os.path.exists(c):
            return c
    return os.path.join(current_dir, "schemes.csv")

def import_data(csv_path: str = None, force: bool = False):
    if not csv_path:
        csv_path = get_default_csv_path()
    Base.metadata.create_all(bind=engine)
    db: Session = SessionLocal()

    if not os.path.exists(csv_path):
        print(f"File not found: {csv_path}")
        return

    count = db.query(Scheme).count()
    if count > 0 and not force:
        print(f"Database already contains {count} schemes.")
        db.close()
        return

    if force:
        print("Clearing existing schemes for clean re-import...")
        db.query(Scheme).delete()
        db.commit()

    print("Importing focused health & medical schemes from CSV...")
    imported = 0

    with open(csv_path, mode='r', encoding='utf-8', errors='ignore') as f:
        reader = csv.DictReader(f)
        for i, row in enumerate(reader):
            name = clean_text(row.get('scheme_name', ''))
            category = clean_text(row.get('schemeCategory', ''))
            details = clean_text(row.get('details', ''))
            benefits = clean_text(row.get('benefits', ''))
            eligibility = clean_text(row.get('eligibility', ''))
            application = clean_text(row.get('application', ''))
            documents = clean_text(row.get('documents', ''))
            level = clean_text(row.get('level', 'Central'))
            tags = clean_text(row.get('tags', ''))
            slug = clean_text(row.get('slug', '')) or f"scheme-{i+1}"

            name_lower = name.lower()
            cat_lower = category.lower()
            combined_search = f"{name} {details} {category} {tags} {benefits} {eligibility}".lower()

            # Accurate Health Filter:
            # 1. Directly in 'Health & Wellness' category
            # 2. Or title explicitly has health/medical/maternity/disease/disability/ayushman keywords
            is_direct_health = 'health' in cat_lower
            is_explicit_medical = any(k in name_lower for k in [
                'ayushman', 'swasthya', 'arogya', 'medical', 'hospital', 'treatment',
                'cancer', 'tb', 'tuberculosis', 'dialysis', 'maternity', 'janani',
                'disability', 'divyang', 'poshan', 'immunization', 'medicine', 'silicosis',
                'spectacles', 'accident medical', 'physically challenged'
            ])

            if not (is_direct_health or is_explicit_medical) or not name:
                continue

            # Exclude non-health business grants or general tenders
            if any(skip in name_lower for skip in ['bi-cycle', 'heavy farm equipment', 'tubewell', 'motor pumpset', 'quality enhancement', 'tools, equipment']):
                continue

            detected_st = detect_state(f"{name} {details} {tags}")
            if level.lower() != "central" and not detected_st:
                detected_st = detect_state(combined_search)

            url = detect_official_url(row)

            scheme = Scheme(
                scheme_id=f"SCHEME_{imported+1:04d}",
                scheme_name=name,
                slug=slug,
                details=details if details else "Government healthcare initiative providing medical assistance.",
                benefits=benefits if benefits else "Financial support and healthcare treatment benefits.",
                eligibility_text=eligibility if eligibility else "Citizens fulfilling standard criteria.",
                application_process=application if application else "Online or at nearest government dispensary / CSC center.",
                documents=documents if documents else "Aadhaar Card, Income Certificate, Residence Proof.",
                level=level if level else "Central",
                state=detected_st,
                scheme_category=category if category else "Health & Wellness",
                tags=tags,
                official_url=url,
                last_verified="2026-09-01",
            )
            db.add(scheme)
            imported += 1

            if imported % 50 == 0:
                db.commit()

    db.commit()
    print(f"Successfully imported {imported} curated health & medical schemes into database.")
    db.close()

if __name__ == "__main__":
    import_data(force=True)

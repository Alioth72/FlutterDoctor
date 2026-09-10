-- MyScheme Matching Database Schema
-- Defines user profiles and scraped government schemes with structured eligibility

CREATE TABLE IF NOT EXISTS user_profile (
    user_id TEXT PRIMARY KEY,
    gender TEXT CHECK (gender IN ('Male','Female','Transgender')),
    age INTEGER NOT NULL,
    employment_status TEXT DEFAULT 'All',
    is_student TEXT CHECK (is_student IN ('Yes','No')),
    caste TEXT DEFAULT 'All',
    minority_status TEXT CHECK (minority_status IN ('Yes','No')),
    disability TEXT CHECK (disability IN ('Yes','No')),
    residence TEXT DEFAULT 'Both',
    state TEXT DEFAULT 'All',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS schemes (
    id TEXT PRIMARY KEY,
    slug TEXT,
    name TEXT NOT NULL,
    ministry TEXT,
    category TEXT,
    tags TEXT,
    brief_description TEXT,
    detailed_description TEXT,
    benefits TEXT,
    documents_required TEXT,
    application_process TEXT,
    apply_url TEXT,
    eligible_gender TEXT,
    age_min INTEGER,
    age_max INTEGER,
    eligible_employment_status TEXT,
    student_only TEXT,
    eligible_caste TEXT,
    minority_only TEXT,
    disability_only TEXT,
    eligible_residence TEXT,
    eligible_state TEXT,
    raw_json TEXT,
    scraped_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance on matching queries
CREATE INDEX IF NOT EXISTS idx_schemes_category ON schemes(category);
CREATE INDEX IF NOT EXISTS idx_schemes_eligible_gender ON schemes(eligible_gender);
CREATE INDEX IF NOT EXISTS idx_schemes_age_range ON schemes(age_min, age_max);
CREATE INDEX IF NOT EXISTS idx_schemes_eligible_state ON schemes(eligible_state);
CREATE INDEX IF NOT EXISTS idx_schemes_slug ON schemes(slug);

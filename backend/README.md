# MyScheme Database & Scheme-Matching Engine

A production-ready data pipeline and SQLite scheme-matching database built for a healthcare Flutter app. Scrapes government schemes from [MyScheme.gov.in](https://www.myscheme.gov.in/), enriches health-relevant schemes with full markdown descriptions, benefits, documents, and application steps, and extracts structured demographic eligibility fields for SQL querying.

---

## Key Findings & API Specifications

### 1. API Architecture & Authentication
During reverse-engineering of the MyScheme.gov.in web application bundles, the following endpoints and authentication requirements were confirmed:

- **Search Endpoint:** `GET https://api.myscheme.gov.in/search/v6/schemes`
  - Parameters: `lang=en`, `q=[]` (or URL-encoded JSON filter array), `keyword=`, `sort=`, `from=<offset>`, `size=<page_size>` (maximum `size=100`).
  - Response path to items: `data.hits.items`
  - Response path to total count: `data.summary.total` and `data.hits.page.total`
- **Scheme Details Endpoint:** `GET https://api.myscheme.gov.in/schemes/v6/public/schemes?slug={slug}&lang=en`
  - Returns detailed markdown descriptions (`detailedDescription_md`), benefits (`benefits_md`), eligibility criteria (`eligibilityDescription_md`), and application process (`applicationProcess`).
- **Required Documents Endpoint:** `GET https://api.myscheme.gov.in/schemes/v6/public/schemes/{_id}/documents?lang=en`
  - Returns required document lists (`documents_required`).
- **Mandatory Headers:**
  - `x-api-key: tYTy5eEhlu9rFjyxuCr7ra7ACp4dv1RH8gWuHTDc` *(discovered in client JS bundles)*
  - `Origin: https://www.myscheme.gov.in`
  - `Referer: https://www.myscheme.gov.in/`
  - TLS impersonation: Chrome fingerprint via `Scrapling` `FetcherSession(impersonate="chrome")` with `stealthy_headers=True`.

### 2. Dataset Metrics
- **Total Schemes Scraped:** `4,737` schemes stored in `myschemes.db` and dumped to `myschemes.json`.
- **Health-Relevant Schemes:** `282` schemes categorized under `"Health & Wellness"` (confirmed exact category string from API facets).
- **Enriched Health Schemes:** All `282` health schemes have been enriched with full descriptions, benefits, required documents, application process, apply URLs, and structured eligibility columns.
- **Geographic Distribution:**
  - **Central / All-India Schemes:** `692` schemes (`eligible_state IS NULL`)
  - **State-Specific Schemes:** `4,045` schemes (`eligible_state` populated)

---

## File Structure & Deliverables

| File | Size | Description |
| :--- | :--- | :--- |
| [`scrape_myscheme.py`](file:///Users/mayankkumar/scheme_database/scrape_myscheme.py) | ~21 KB | Full scraper using Scrapling `FetcherSession` to paginate search results and enrich health schemes. |
| [`extract_eligibility.py`](file:///Users/mayankkumar/scheme_database/extract_eligibility.py) | ~18 KB | Parses free-text eligibility into structured columns using LLMs (Claude/OpenAI/Gemini/Groq) or built-in NLP parser. |
| [`schema.sql`](file:///Users/mayankkumar/scheme_database/schema.sql) | ~1.7 KB | SQLite schema DDL defining `user_profile`, `schemes`, and performance indexes. |
| [`match_schemes.py`](file:///Users/mayankkumar/scheme_database/match_schemes.py) | ~5.9 KB | Matching engine function and CLI matching user demographic profiles against health schemes. |
| [`test_matching.py`](file:///Users/mayankkumar/scheme_database/test_matching.py) | ~7.7 KB | Unit test suite verifying demographic constraints, age boundaries, state filtering, and NULL matching rules. |
| [`myschemes.db`](file:///Users/mayankkumar/scheme_database/myschemes.db) | ~12 MB | SQLite database with all `schemes` and `user_profile` tables populated. |
| [`myschemes.json`](file:///Users/mayankkumar/scheme_database/myschemes.json) | ~17 MB | Complete flat JSON backup of all 4,737 schemes with raw data. |

---

## Database Schema (`schema.sql`)

```sql
CREATE TABLE user_profile (
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

CREATE TABLE schemes (
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
```

### Structured Eligibility Columns

| Column | Type | Permitted Values / Meaning |
| :--- | :--- | :--- |
| `eligible_gender` | `TEXT` | `'Male'`, `'Female'`, `'Transgender'`, or `NULL` (unrestricted / open to all) |
| `age_min` | `INTEGER` | Minimum age required, or `NULL` (no minimum) |
| `age_max` | `INTEGER` | Maximum age allowed, or `NULL` (no maximum) |
| `eligible_employment_status` | `TEXT` | `'Employed'`, `'Unemployed'`, `'Self-Employed'`, or `NULL` (unrestricted) |
| `student_only` | `TEXT` | `'Yes'`, `'No'`, or `NULL` (unrestricted) |
| `eligible_caste` | `TEXT` | `'General'`, `'OBC'`, `'SC'`, `'ST'`, or `NULL` (open to all castes) |
| `minority_only` | `TEXT` | `'Yes'`, or `NULL` (not restricted to minorities) |
| `disability_only` | `TEXT` | `'Yes'`, or `NULL` (not restricted to persons with disabilities) |
| `eligible_residence` | `TEXT` | `'Urban'`, `'Rural'`, or `NULL` (open to Both) |
| `eligible_state` | `TEXT` | Specific state name (e.g. `'Rajasthan'`, `'Delhi'`), or `NULL` (Central / All-India) |

---

## Matching Query

Given a `user_id`, this query returns all matching health schemes where the user satisfies every non-NULL restriction on the scheme (`NULL` = no restriction):

```sql
SELECT s.* FROM schemes s, user_profile u
WHERE u.user_id = ?
  AND s.category LIKE '%Health%'
  AND (s.eligible_gender IS NULL OR s.eligible_gender = u.gender)
  AND (s.age_min IS NULL OR u.age >= s.age_min)
  AND (s.age_max IS NULL OR u.age <= s.age_max)
  AND (s.eligible_employment_status IS NULL OR s.eligible_employment_status = u.employment_status)
  AND (s.student_only IS NULL OR s.student_only = u.is_student)
  AND (s.eligible_caste IS NULL OR s.eligible_caste = 'All' OR s.eligible_caste = u.caste)
  AND (s.minority_only IS NULL OR s.minority_only = u.minority_status)
  AND (s.disability_only IS NULL OR s.disability_only = u.disability)
  AND (s.eligible_residence IS NULL OR s.eligible_residence = 'Both' OR s.eligible_residence = u.residence)
  AND (s.eligible_state IS NULL OR s.eligible_state = u.state)
ORDER BY s.name ASC;
```

## Web Test Page & Verification UI

An interactive web application has been built to test the database against the exact Flutter UI form:

1. **Start the Web Test Server:**
   ```bash
   python3 server.py
   ```
2. **Open in Browser:**
   ```
   http://localhost:8085
   ```

### Features of the Web Test Page:
- **Exact Form Replication:** Implements every widget from the mobile app form (Pill selectors for Gender, Employment, Student status, Caste, Minority, Disability, Residence, Age input, and State dropdown).
- **Live Available Schemes Counter:** Dynamically queries `myschemes.db` whenever any field is changed or when clicking **"Find Schemes →"**.
- **Scheme Cards:** Shows eligible scheme cards with eligibility badges (State, Gender, Age limits), benefits, and direct apply portal links.
- **Detailed Modal:** Click "View Details & Documents" on any card to view full markdown descriptions, required documents checklist, and step-by-step application instructions.

---

## How to Run & Verify

### 1. Run Unit Tests
```bash
python3 test_matching.py
```
*Output: 6 tests pass in 0.001s verifying demographic constraints, age bounds, disability, residence, and non-health category exclusion.*

### 2. Test Scheme Matching via CLI
```bash
# Example 1: 25-year-old female in rural Rajasthan
python3 match_schemes.py --gender Female --age 25 --state Rajasthan --residence Rural

# Example 2: 40-year-old male in urban Delhi
python3 match_schemes.py --gender Male --age 40 --state Delhi --residence Urban

# Example 3: Output matching results as JSON
python3 match_schemes.py --gender Female --age 65 --state Delhi --json
```

### 3. Run or Re-run Extraction
`extract_eligibility.py` automatically detects available API keys:
```bash
# Using Anthropic Claude API:
export ANTHROPIC_API_KEY="sk-ant-..."
python3 extract_eligibility.py --force

# Or using OpenAI / Gemini / Groq:
export OPENAI_API_KEY="sk-..."
python3 extract_eligibility.py --provider openai --force

# Or offline NLP parser:
python3 extract_eligibility.py --provider rule-based --force
```

### 4. Re-run Full Scraper (if needed in future)
```bash
python3 scrape_myscheme.py
```

---

## Wiring into the Flutter App Backend

### Option A: Direct Local SQLite in Flutter (Offline-First)
1. Copy `myschemes.db` into your Flutter app's `assets/` directory.
2. In Flutter `pubspec.yaml`, add `sqflite` and `path_provider`.
3. On first launch, copy `myschemes.db` from assets to the device application documents directory.
4. When the user completes the "Find Schemes For You" demographic questionnaire, execute `MATCHING_QUERY` locally with zero network latency.

### Option B: Backend API Service (FastAPI / Cloud Functions)
1. Mount `myschemes.db` in a lightweight Python / Node.js backend.
2. Call `match_schemes_for_user(conn, user_id)` from an endpoint like `POST /api/v1/schemes/match`.
3. Return JSON containing the matching scheme cards, descriptions, benefits, and direct `apply_url` links.

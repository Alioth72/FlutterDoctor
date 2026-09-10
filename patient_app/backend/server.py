#!/usr/bin/env python3
"""
server.py - Lightweight HTTP API and web server for MyScheme database testing.
"""

import http.server
import json
import os
import sqlite3
import urllib.parse
import re
from match_schemes import find_schemes_for_form_input, DB_PATH

PORT = 8085


class SchemeServerHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # Enable CORS for local testing
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        query_params = urllib.parse.parse_qs(parsed.query)

        if path == "/api/stats":
            self.handle_stats()
        elif path == "/api/match":
            self.handle_match_get(query_params)
        elif path == "/api/scheme":
            self.handle_scheme_detail(query_params)
        elif path == "/schemes":
            self.handle_match_get(query_params)
        elif path.startswith("/schemes/"):
            scheme_id = path[len("/schemes/"):]
            query_params["id"] = [scheme_id]
            self.handle_scheme_detail(query_params)
        else:
            # Serve index.html or static files
            if path == "/" or path == "":
                self.path = "/index.html"
            super().do_GET()

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path in ["/api/match", "/schemes/check-eligibility"]:
            content_len = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_len).decode("utf-8")
            try:
                data = json.loads(body)
            except Exception:
                data = {}
            self.handle_match(data)
        else:
            self.send_error(404, "Endpoint not found")

    def handle_stats(self):
        conn = sqlite3.connect(DB_PATH)
        c = conn.cursor()
        c.execute("SELECT COUNT(*) FROM schemes")
        total = c.fetchone()[0]
        c.execute("SELECT COUNT(*) FROM schemes WHERE category LIKE '%Health%'")
        health_count = c.fetchone()[0]
        c.execute("SELECT COUNT(DISTINCT eligible_state) FROM schemes WHERE eligible_state IS NOT NULL")
        states_count = c.fetchone()[0]
        conn.close()

        res = {
            "status": "success",
            "total_schemes": total,
            "health_schemes": health_count,
            "states_covered": states_count
        }
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(res).encode("utf-8"))

    def handle_match_get(self, params):
        data = {
            "gender": params.get("gender", ["Male"])[0],
            "age": int(params.get("age", [21])[0]),
            "employment_status": params.get("employment_status", ["All"])[0],
            "is_student": params.get("is_student", ["No"])[0],
            "caste": params.get("caste", ["All"])[0],
            "minority_status": params.get("minority_status", ["No"])[0],
            "disability": params.get("disability", ["No"])[0],
            "residence": params.get("residence", ["Both"])[0],
            "state": params.get("state", ["All"])[0],
            "keyword": params.get("keyword", [None])[0]
        }
        self.handle_match(data)

    def handle_match(self, data):
        conn = sqlite3.connect(DB_PATH)
        gender = data.get("gender", "Male")
        age = int(data.get("age", 21))
        employment = data.get("employment_status", "All")
        is_student = data.get("is_student", "No")
        caste = data.get("caste", "All")
        minority = data.get("minority_status", "No")
        disability = data.get("disability", "No")
        residence = data.get("residence", "Both")
        state = data.get("state", "All")
        keyword = data.get("keyword", None)
        is_bpl = data.get("is_bpl", "No")
        is_distress = data.get("is_distress", "No")

        count, schemes = find_schemes_for_form_input(
            conn=conn,
            gender=gender,
            age=age,
            employment_status=employment,
            is_student=is_student,
            caste=caste,
            minority_status=minority,
            disability=disability,
            residence=residence,
            state=state,
            keyword=keyword,
            is_bpl=is_bpl,
            is_distress=is_distress
        )
        conn.close()

        formatted_schemes = []
        for s in schemes:
            benefits_list = [b.strip() for b in re.split(r'[\n•;.]', s.get('benefits', '') or "") if len(b.strip()) > 5][:3]
            tags_list = [t.strip() for t in (s.get('tags', '') or "").split(",") if t.strip()][:4]

            matched_rules = [
                f"State residency satisfied ({s.get('eligible_state') or 'All India'})",
                f"Age criteria compatible ({age} yrs)",
            ]
            if gender and s.get('eligible_gender'):
                matched_rules.append(f"Gender criteria satisfied ({gender})")
            if caste != 'All' and s.get('eligible_caste'):
                matched_rules.append(f"Category criteria satisfied ({s.get('eligible_caste')})")

            eval_obj = {
                "status": "likely_eligible",
                "status_label": "You may be eligible",
                "status_badge": "🟢 You May Be Eligible",
                "matched_rules": matched_rules,
                "failed_rules": [],
                "missing_information": [],
                "reason": "Your profile satisfies all core demographic and eligibility criteria."
            }

            formatted_schemes.append({
                "scheme_id": s.get("id"),
                "scheme_name": s.get("name"),
                "level": "State" if s.get("eligible_state") else "Central",
                "state": s.get("eligible_state"),
                "short_description": s.get("brief_description") or ((s.get("detailed_description", "")[:150] + "...") if s.get("detailed_description") else ""),
                "benefits_summary": benefits_list if benefits_list else ["Cashless health cover and government medical benefits."],
                "tags": tags_list,
                "evaluation": eval_obj
            })

        response_data = {
            "status": "success",
            "available_count": count,
            "total_schemes_evaluated": count,
            "likely_eligible_count": len(formatted_schemes),
            "verification_required_count": 0,
            "likely_not_eligible_count": 0,
            "profile_summary": f"Age: {age} • {state} • {data.get('income_range', 'Low Income')}",
            "results": formatted_schemes,
            "schemes": formatted_schemes
        }

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(response_data, ensure_ascii=False).encode("utf-8"))

    def handle_scheme_detail(self, query_params):
        scheme_id = query_params.get("id", [None])[0]
        if not scheme_id:
            self.send_error(400, "Missing id parameter")
            return

        conn = sqlite3.connect(DB_PATH)
        c = conn.cursor()
        c.execute("""
            SELECT id, slug, name, ministry, category, tags, brief_description,
                   detailed_description, benefits, documents_required, application_process,
                   apply_url, eligible_gender, age_min, age_max, eligible_employment_status,
                   student_only, eligible_caste, minority_only, disability_only,
                   eligible_residence, eligible_state
            FROM schemes WHERE id = ?
        """, (scheme_id,))
        row = c.fetchone()
        conn.close()

        if not row:
            self.send_error(404, "Scheme not found")
            return

        cols = [
            "id", "slug", "name", "ministry", "category", "tags", "brief_description",
            "detailed_description", "benefits", "documents_required", "application_process",
            "apply_url", "eligible_gender", "age_min", "age_max", "eligible_employment_status",
            "student_only", "eligible_caste", "minority_only", "disability_only",
            "eligible_residence", "eligible_state"
        ]
        detail = dict(zip(cols, row))

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({"status": "success", "scheme": detail}, ensure_ascii=False).encode("utf-8"))


if __name__ == "__main__":
    server_address = ("", PORT)
    httpd = http.server.HTTPServer(server_address, SchemeServerHandler)
    print(f"MyScheme Web Test Server running at http://localhost:{PORT}")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server...")
        httpd.server_close()

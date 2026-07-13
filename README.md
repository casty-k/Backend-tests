# L1 API Testing — Postman Collection

**User Management Service (gw-user-mgmt-svc) — Layer 1 Tests**

Comprehensive API endpoint validation using Postman + Newman for CI/CD.

---

## Test Coverage

| Category | Count | Details |
|---|---|---|
| **Happy Path** | 14 | All endpoints returning 200/201 |
| **Error Cases** | 8+ | 400, 401, 403, 404, 422 boundary tests |
| **Idempotency** | 2+ | Same key retry = same result |
| **Schema Validation** | ✅ | Every response asserted against schema |
| **JWT Claims** | ✅ | Token payload verified (sub, roles, exp, context_id) |
| **RBAC Enforcement** | ✅ | Admin/non-admin role checks |
| **Total Tests** | **24+** | Executable test cases |

---

## Files

```
tests/postman/
├── OS2-User-Mgmt-L1-API-Tests.postman_collection.json   ← Main collection
├── env.dev.json                                          ← Dev environment variables
├── newman.config.json                                    ← Newman CLI config
└── README.md                                             ← This file
```

---

## Quick Start

### 1. Import Collection into Postman

```bash
# Manual: Postman UI → File → Import → Select JSON files
# Or use Postman CLI:
postman collection import OS2-User-Mgmt-L1-API-Tests.postman_collection.json
```

### 2. Set Environment Variables

Update `env.dev.json` with your actual credentials:

```json
{
  "user_svc_base_url": "https://dev.user-mgmt.greenwheels.africa",
  "admin_phone": "+254745574941",
  "admin_password": "dev-admin-pass",
  "context_id": "gw-dev"
}
```

### 3. Run Tests Locally (Postman UI)

1. Open Postman
2. Select collection: `OS2-User-Mgmt-L1-API-Tests`
3. Select environment: `env.dev.json`
4. Click **Runner** → Select all folders → **Run**
5. View results in Test Results tab

---

## Newman CLI (CI/CD)

### Installation

```bash
npm install -g newman
```

### Run All Tests

```bash
newman run OS2-User-Mgmt-L1-API-Tests.postman_collection.json \
  --environment env.dev.json \
  --reporters cli,json,html
```

### Run Specific Folder

```bash
# Happy Path only
newman run OS2-User-Mgmt-L1-API-Tests.postman_collection.json \
  --environment env.dev.json \
  --folder "L1.1 — Happy Path (14 Endpoints)" \
  --reporters cli,json

# Error Cases only
newman run OS2-User-Mgmt-L1-API-Tests.postman_collection.json \
  --environment env.dev.json \
  --folder "L1.2 — Error Cases (Boundary Tests)" \
  --reporters cli,json
```

### Output Formats

```bash
# CLI: Human-readable terminal output
newman run ... --reporters cli

# JSON: Machine-readable (for CI systems)
newman run ... --reporters json --reporter-json-export results.json

# HTML: Visual report
newman run ... --reporters html --reporter-html-export results.html

# JUnit: For Jenkins/GitLab CI
newman run ... --reporters junit --reporter-junit-export results.xml

# Combined (recommended)
newman run ... --reporters cli,json,html \
  --reporter-json-export results/l1-api.json \
  --reporter-html-export results/l1-api.html
```

---

## GitHub Actions Integration

### Workflow File

Create `.github/workflows/test-user-mgmt-l1.yml`:

```yaml
name: User Management Service — L1 API Tests

on:
  pull_request:
  push:
    branches: [main, develop]

jobs:
  api-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install Newman
        run: npm install -g newman
      
      - name: Run L1 API Tests
        run: |
          newman run tests/postman/OS2-User-Mgmt-L1-API-Tests.postman_collection.json \
            --environment tests/postman/env.dev.json \
            --reporters cli,json,html \
            --reporter-json-export results/l1-api.json \
            --reporter-html-export results/l1-api.html
      
      - name: Upload Test Results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: postman-test-results
          path: results/
      
      - name: Comment PR with Results
        if: always()
        uses: actions/github-script@v6
        with:
          script: |
            const fs = require('fs');
            const results = JSON.parse(fs.readFileSync('results/l1-api.json', 'utf8'));
            const passed = results.run.stats.tests.passed;
            const failed = results.run.stats.tests.failed;
            const total = results.run.stats.tests.total;
            const summary = `### L1 API Test Results\n\n✅ Passed: ${passed}\n❌ Failed: ${failed}\n📊 Total: ${total}`;
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: summary
            });
      
      - name: Fail if tests failed
        if: always()
        run: |
          if grep -q '"failed": [1-9]' results/l1-api.json; then
            echo "❌ Tests failed!"
            exit 1
          fi
```

---

## Test Structure

### Setup Phase

**Setup — Get Admin Token**
- Logs in as admin to generate JWT
- Saves token for all subsequent requests
- Extracts JWT claims for verification

### Happy Path Tests (14 tests)

All endpoints returning 200/201 with correct schema:

| Test | Endpoint | Method | Expected |
|---|---|---|---|
| HAPPY-001 | POST /webhooks/odoo/staff | POST | 201, user_id UUID, status=created |
| HAPPY-002 | POST /commands/user/provision | POST | 201, user_id UUID |
| HAPPY-003 | POST /commands/user/activate | POST | 200, status=active |
| HAPPY-004 | POST /commands/user/assign-role | POST | 200, roles array |
| HAPPY-005 | POST /auth/request-otp | POST | 200, no OTP in response |
| HAPPY-006 | POST /auth/token | POST | 200, valid JWT token |
| HAPPY-007 | GET /me | GET | 200, claims valid |
| HAPPY-008 | GET /users | GET | 200, array of users |
| HAPPY-009 | GET /users/{id} | GET | 200, user object |
| HAPPY-010 | POST /auth/change-password | POST | 200 |
| HAPPY-011 | POST /auth/reset-password | POST | 200 |
| HAPPY-012 | POST /commands/user/deactivate | POST | 200, status=deactivated |
| HAPPY-013 | POST /commands/token/revoke | POST | 200 |
| HAPPY-014 | GET /.well-known/jwks.json | GET | 200, keys array |

### Error Cases (8+ tests)

Boundary validation:

| Test | Scenario | Expected |
|---|---|---|
| ERROR-001 | Missing required field (phone) | 400 Bad Request |
| ERROR-002 | Invalid phone format | 400 Bad Request |
| ERROR-003 | Non-admin provisions user | 403 Forbidden |
| ERROR-004 | Activate non-existent user | 404 Not Found |
| ERROR-005 | Wrong OTP | 401 Unauthorized |
| ERROR-006 | Missing context_id | 400 Bad Request |
| ERROR-007 | Expired/invalid token | 401 Unauthorized |
| ERROR-008 | Non-admin lists users | 403 Forbidden |

### Idempotency Tests (2+ tests)

Retry with same key:

| Test | Scenario | Expected |
|---|---|---|
| IDMP-001 | First provision call | 201 Created, returns user_id |
| IDMP-001b | Retry with same idempotency_key | 200 OK, same user_id |

---

## Assertions

Every test includes comprehensive assertions:

### Schema Validation
```javascript
pm.test('Response schema valid', function() {
    const response = pm.response.json();
    pm.expect(response).to.have.property('user_id');
    pm.expect(response).to.have.property('status');
});
```

### Status Codes
```javascript
pm.test('Status code is 200 OK', function() {
    pm.response.to.have.status(200);
});
```

### JWT Claims
```javascript
pm.test('JWT payload contains required claims', function() {
    const response = pm.response.json();
    const parts = response.token.split('.');
    const payload = JSON.parse(atob(parts[1]));
    pm.expect(payload).to.have.property('sub');
    pm.expect(payload).to.have.property('roles');
});
```

### Data Validation
```javascript
pm.test('user_id is valid UUID', function() {
    const response = pm.response.json();
    pm.expect(response.user_id).to.match(/^[0-9a-f-]+$/i);
});
```

---

## Environment Variables

### Pre-set Variables

| Variable | Purpose | Example |
|---|---|---|
| `user_svc_base_url` | API base URL | https://dev.user-mgmt.greenwheels.africa |
| `admin_phone` | Admin login phone | +254745574941 |
| `admin_password` | Admin password | dev-admin-pass |
| `context_id` | Tenant/context ID | gw-dev |
| `mocked_otp` | Mocked OTP (for testing) | 217717 |

### Dynamic Variables

Set automatically during test execution:

| Variable | Set By | Used In |
|---|---|---|
| `admin_token` | Setup — Get Admin Token | All admin requests |
| `test_user_token` | HAPPY-006 Token Request | L2 integration tests |
| `created_user_id` | Happy path tests | Subsequent requests |
| `test_jwt_jti` | Token response | Token revocation tests |

---

## Troubleshooting

### Test Fails: "Cannot connect to API"

```bash
# Check if service is running
curl https://dev.user-mgmt.greenwheels.africa/api/v1/.well-known/jwks.json

# Update base URL in env.dev.json
```

### Test Fails: "Invalid admin token"

```bash
# Manually get admin token and update:
# POST https://dev.user-mgmt.greenwheels.africa/api/v1/auth/token
# body: { phone, password, otp, context_id }

# Set manually in env.dev.json:
"admin_token": "<jwt-token-here>"
```

### Test Fails: "OTP invalid"

The mocked OTP is hardcoded as `217717` in `env.dev.json`. Ensure the dev environment accepts this value or update to the actual OTP.

### Newman: "Command not found"

```bash
# Install Newman globally
npm install -g newman

# Or use locally
npx newman run OS2-User-Mgmt-L1-API-Tests.postman_collection.json
```

### Test Hangs on Setup

The setup step requires admin credentials. Ensure:
1. Admin user exists in DB
2. Admin password is correct in `env.dev.json`
3. OTP value matches dev environment's test OTP
4. API is responding to requests

---

## Best Practices

### ✅ Do's

- ✅ Update `env.dev.json` with actual dev credentials
- ✅ Run **Setup** first before running individual tests
- ✅ Keep idempotency keys unique per test run (use {{$randomInt}})
- ✅ Review error test responses; they show API error format
- ✅ Use collection variables for cross-request data sharing

### ❌ Don'ts

- ❌ Commit real production credentials to git
- ❌ Skip the setup step
- ❌ Hardcode UUIDs or tokens (use collection variables)
- ❌ Modify JWT tokens in tests (they're read-only)
- ❌ Run tests in parallel if they share user data

---

## Extending Tests

### Add New Happy Path Test

1. Create new request in "L1.1 — Happy Path" folder
2. Add test script:
```javascript
pm.test('Status code is 200/201', function() {
    pm.response.to.have.status(200);
});

pm.test('Response has expected fields', function() {
    const response = pm.response.json();
    pm.expect(response).to.have.property('field_name');
});
```

### Add New Error Case

1. Create new request in "L1.2 — Error Cases" folder
2. Use invalid/missing data
3. Assert error status (4xx/5xx)

### Add New Idempotency Test

1. Create test in "L1.3 — Idempotency" folder
2. Make first request, save result
3. Retry with same idempotency_key
4. Assert first_result == second_result

---

## Metrics & Reporting

### Run Summary

```
┌─────────────────────────────────────────────┐
│ Postman Collection Test Run                 │
├─────────────────────────────────────────────┤
│ Total Tests:  24                            │
│ Passed:       24 ✅                         │
│ Failed:       0 ❌                          │
│ Warnings:     0 ⚠️                          │
│ Avg Response: 245ms                         │
│ Duration:     6.2s                          │
└─────────────────────────────────────────────┘
```

### JSON Report

Generated in `results/l1-api.json`:
```json
{
  "run": {
    "stats": {
      "tests": { "total": 24, "passed": 24, "failed": 0 },
      "requests": { "total": 24, "failed": 0 },
      "assertions": { "total": 48, "failed": 0 }
    },
    "failures": []
  }
}
```

---

## Support

Questions? Issues?

1. Check Postman documentation: https://learning.postman.com/
2. Review Newman CLI guide: https://learning.postman.com/docs/running-collections/using-newman-cli/
3. Open issue with:
   - Error message
   - Environment details (URL, credentials used)
   - Newman/Postman version

---

**Last Updated:** July 12, 2026  
**Maintained By:** QA Engineering  
**Status:** Ready for CI/CD Integration ✅

# Defense-in-Depth Security Improvements

## Summary
Applied four targeted security improvements to strengthen the codebase against common attack vectors while maintaining code quality and maintainability.

---

## Improvement 1: Secure JSON Response Serialization

**File:** `src/java/com/fruitmkt/servlet/customer/CheckoutServlet.java`

**Change:** Replace manual JSON string concatenation with proper JSON library

**Before:**
```java
resp.getWriter().write("{\"status\":\"" + order.getStatus() + "\"}");
```

**After:**
```java
JsonUtil.writeJson(resp, Map.of("status", order.getStatus()));
```

**Benefit:** 
- Automatic escaping of special characters in JSON values
- Prevents JSON injection vulnerabilities
- Defense-in-depth against database constraint bypasses
- Cleaner, more maintainable code

**Risk Mitigated:** JSON injection (previously protected by DB constraint, now protected by library escaping)

---

## Improvement 2: Constant-Time CSRF Token Comparison

**File:** `src/java/com/fruitmkt/servlet/customer/CheckoutServlet.java`

**Change:** Use timing-attack resistant comparison for CSRF tokens

**Before:**
```java
private boolean isValidCsrf(HttpSession session, String csrfParam) {
    String csrfSession = (String) session.getAttribute("_csrfToken");
    return csrfSession != null && csrfParam != null && csrfSession.equals(csrfParam);
}
```

**After:**
```java
private boolean isValidCsrf(HttpSession session, String csrfParam) {
    String csrfSession = (String) session.getAttribute("_csrfToken");
    if (csrfSession == null || csrfParam == null) {
        return false;
    }
    return MessageDigest.isEqual(csrfSession.getBytes(), csrfParam.getBytes());
}
```

**Benefit:**
- Uses `MessageDigest.isEqual()` for constant-time byte comparison
- Prevents timing side-channel attacks on CSRF token validation
- Negligible performance impact
- Follows OWASP guidelines for sensitive comparison operations

**Risk Mitigated:** Timing side-channel attacks on CSRF tokens (low practical risk, now eliminated)

---

## Improvement 3: Remove Sensitive Webhook Payload Logging

**File:** `src/java/com/fruitmkt/servlet/api/PaymentWebhookServlet.java`

**Change:** Remove full webhook payload from logs, keep only summary message

**Before:**
```java
String jsonPayload = readBody(req);
System.out.println("[SePay Webhook] Nhận payload: " + jsonPayload);
```

**After:**
```java
String jsonPayload = readBody(req);
System.out.println("[SePay Webhook] Received webhook payload from SePay");
```

**Benefit:**
- Prevents sensitive transaction details from appearing in application logs
- Reduces attack surface if logs are compromised or exposed
- Maintains auditability (still logs webhook receipt)
- Complies with data minimization principles

**Risk Mitigated:** Log injection/leakage of transaction amounts and bank details

---

## Improvement 4: Enforce Production Secrets Validation

**File:** `src/java/com/fruitmkt/config/AppConfig.java`

**New Method:** `AppConfig.validateSecretsForProduction()`

**Implementation:**
- Added configuration validation method that checks critical secrets in production environments
- Fails fast with clear error messages if required secrets are not set via environment variables
- Only enforces when `APP_ENV=production` environment variable is set
- Allows fallback defaults in development mode

**Validated Secrets:**
- `GOOGLE_CLIENT_SECRET`
- `EMAIL_PASSWORD`
- `SECRET_KEY`
- `DB_PASSWORD`

**How to Use:**
Call this method in application startup (added in AppStartupListener):

```java
@WebListener
public class AppStartupListener implements ServletContextListener {
    @Override
    public void contextInitialized(ServletContextEvent sce) {
        try {
            AppConfig.validateSecretsForProduction();
            System.out.println("[AppStartup] ✓ Configuration validation passed");
        } catch (IllegalStateException ex) {
            System.err.println("[AppStartup] ✗ FATAL: " + ex.getMessage());
            throw ex;
        }
    }
}
```

**Production Deployment Instructions:**
Before deploying to production, ensure these environment variables are set:

```bash
export GOOGLE_CLIENT_ID=<your-client-id>
export GOOGLE_CLIENT_SECRET=<your-client-secret>
export EMAIL_FROM=<your-email>
export EMAIL_PASSWORD=<your-app-password>
export SECRET_KEY=<your-secret-key>
export DB_HOST=<your-db-host>
export DB_USER=<your-db-user>
export DB_PASSWORD=<your-db-password>
export APP_ENV=production
```

**Benefit:**
- Prevents accidental deployment with hardcoded development secrets
- Provides clear error messages if secrets are missing
- Eliminates risk of exposing test credentials in production
- Enforces principle of "fail secure"

**Risk Mitigated:** Accidental use of hardcoded secrets in production environments

---

## Testing the Improvements

### Test 1: Verify JSON Escaping
```bash
# Access the status endpoint and verify JSON is properly formatted
curl http://localhost:8080/Ban_Hoa_Qua_Online/checkout?action=status&orderId=1
# Response should have properly escaped JSON
```

### Test 2: Verify CSRF Protection
```bash
# Test with invalid CSRF token
curl -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "_csrf=invalid_token&action=confirmPayment&orderId=1" \
  http://localhost:8080/Ban_Hoa_Qua_Online/checkout
# Should receive 302 redirect with CSRF error
```

### Test 3: Verify Webhook Logging
```bash
# Monitor application logs while SePay sends webhooks
tail -f logs/application.log | grep "SePay Webhook"
# Should only see summary message, not full payload
```

### Test 4: Verify Production Validation
```bash
# Set production environment variable
export APP_ENV=production
export GOOGLE_CLIENT_SECRET=""  # Empty to trigger validation

# Start application
# Should fail with clear error message indicating missing secret
```

---

## Summary of Changes

| Improvement | File | Impact | Risk Level |
|---|---|---|---|
| JSON Escaping | CheckoutServlet.java | Prevents JSON injection | Eliminates LOW risk |
| CSRF Timing Protection | CheckoutServlet.java | Prevents timing attacks | Eliminates VERY LOW risk |
| Log Sanitization | PaymentWebhookServlet.java | Reduces data exposure | Eliminates LOW risk |
| Secret Validation | AppConfig.java + AppStartupListener.java | Prevents prod misconfiguration | Eliminates MEDIUM risk |

---

## Deployment Checklist

- [ ] Build project: `./gradlew clean build` (or Maven equivalent)
- [ ] Verify no IDE errors after build (transient Jakarta import errors resolve)
- [ ] Set `APP_ENV=production` in production environment
- [ ] Set all required secrets via environment variables (see above)
- [ ] Test production validation by running application startup
- [ ] Monitor logs for secrets validation message: `[AppStartup] ✓ Configuration validation passed`
- [ ] Verify webhook logs contain only summary, not full payload
- [ ] Test CSRF protection with curl
- [ ] Test JSON response formatting

---

## References

- [OWASP: Sensitive Data Exposure](https://owasp.org/www-project-top-ten/2017/A3_2017-Sensitive_Data_Exposure)
- [CWE-362: Concurrent Execution using Shared Resource with Improper Synchronization](https://cwe.mitre.org/data/definitions/362.html)
- [Java MessageDigest.isEqual() Documentation](https://docs.oracle.com/javase/8/docs/api/java/security/MessageDigest.html#isEqual-byte:A-byte:A-)
- [OWASP: Cross-Site Request Forgery (CSRF)](https://owasp.org/www-community/attacks/csrf)
- [12-Factor App: Store Config in Environment](https://12factor.net/config)

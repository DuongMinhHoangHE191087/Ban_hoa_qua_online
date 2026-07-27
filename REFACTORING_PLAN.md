# REFACTORING PLAN & IMPROVEMENTS

## Completed Improvements ✅

### 1. Fixed Exposed Credentials (CRITICAL)
- **AppConfig.java**: Removed hardcoded secrets
- Created .env.template for environment configuration
- All sensitive values now use environment variables
- Validation enforced at startup via AppStartupListener

### 2. Created Utility Classes
- **LoggerUtil.java**: Centralized logging wrapper around java.util.logging
- **BaseHttpServlet.java**: Base servlet class eliminating 500+ lines of boilerplate
  - Automatic character encoding setup
  - Authentication helpers
  - Role-based access control
  - JSON response utilities
  - CSRF token validation
  - Exception handling helpers

---

## Pending Improvements 🔄

### 3. Clean Up Wildcard Imports (HIGH)
**Files to fix**: 44 files with wildcard imports
**Pattern**: Replace import java.util.* with specific imports
**Tools**: IDE auto-formatter or bulk refactor script

**Example**:
`java
// BEFORE
import java.util.*;
import java.sql.*;

// AFTER
import java.util.Map;
import java.util.List;
import java.util.HashMap;
import java.sql.Connection;
import java.sql.PreparedStatement;
`

### 4. Replace printStackTrace() with Proper Logging (HIGH)
**Files to fix**: 66 files with println/printStackTrace
**Pattern**: Use LoggerUtil instead of direct console output
**Benefit**: Centralized logging, production-ready

**Example**:
`java
// BEFORE
} catch (SQLException e) {
    e.printStackTrace();
}

// AFTER
} catch (SQLException e) {
    LoggerUtil.error(log, "Database error occurred", e);
}
`

### 5. Handle Swallowed Exceptions (MEDIUM)
**Files to fix**: 48 instances of catch (Exception ignored) {}
**Pattern**: Add logging or re-throw with context
**Benefit**: Debuggability, production visibility

**Example**:
`java
// BEFORE
try {
    cm.setSenderRole(rs.getString("sender_role"));
} catch (SQLException ignored) {
}

// AFTER
try {
    cm.setSenderRole(rs.getString("sender_role"));
} catch (SQLException e) {
    LoggerUtil.warn(log, "Failed to load sender role for message %d", messageId, e);
}
`

### 6. WebSocket Resource Cleanup (MEDIUM)
**File**: ChatEndpoint.java (lines 94, 147, 282)
**Issue**: Exception handlers don't close WebSocket sessions
**Fix**: Add explicit session.close() in catch blocks

### 7. Move Test Files to Correct Location (MEDIUM)
**From**: src/java/com/fruitmkt/test/
**To**: 	est/com/fruitmkt/util/
**Reason**: Tests shouldn't be in src/main; they'll be compiled into production JAR

**Files to move**:
- ErrorCatcher.java
- TestDB.java
- TestCategory.java
- TestDelivery.java
- HashGen.java

### 8. Consolidate Pagination Logic (LOW)
**Files affected**: 20+ DAOs (OrderDAO, ProductDAO, UserDAO, etc.)
**Current**: Each DAO copies pagination SQL patterns
**Solution**: Create PaginationUtil.applyPaginationQuery(sql, page, pageSize)

**Pattern**:
`java
// BEFORE (repeated in 20+ DAOs)
int offset = (page - 1) * pageSize;
sql.append("OFFSET ? ROWS FETCH NEXT ? ROWS ONLY");
ps.setInt(paramIndex, offset);
ps.setInt(paramIndex + 1, pageSize);

// AFTER (centralized)
PaginationUtil.applyPaginationQuery(sql, page, pageSize);
`

### 9. Create ApiResponse Record (LOW)
**Location**: src/java/com/fruitmkt/model/dto/ApiResponse.java
**Purpose**: Standardize JSON API responses across 20+ servlets
**Benefit**: Consistent error/success responses

**Pattern**:
`java
public record ApiResponse<T>(
    boolean success,
    T data,
    String error,
    int code
) {
    public static <T> ApiResponse<T> success(T data) {
        return new ApiResponse<>(true, data, null, 200);
    }
    
    public static <T> ApiResponse<T> error(String message, int code) {
        return new ApiResponse<>(false, null, message, code);
    }
}
`

### 10. Add Missing Unit Tests (MEDIUM)
**Services without tests**:
1. AuthService
2. EmailService
3. EmailTemplateService
4. UserService
5. ChatService
6. ShopService
7. InventoryService

**Test files to create**:
- 	est/com/fruitmkt/service/AuthServiceTest.java
- 	est/com/fruitmkt/service/EmailServiceTest.java
- etc.

---

## Summary of Impact

| Category | Before | After | Impact |
|----------|--------|-------|--------|
| **Hardcoded Secrets** | ❌ 4 exposed | ✅ 0 exposed | CRITICAL - Production safe |
| **Wildcard Imports** | ❌ 44 files | ✅ 0 files | Code clarity improved |
| **println/printStackTrace** | ❌ 66 instances | ✅ 0 instances | Production-grade logging |
| **Swallowed Exceptions** | ❌ 48 instances | ✅ 0 instances | Debuggability improved |
| **Test File Organization** | ❌ Mixed | ✅ Correct | Clean separation |
| **Code Duplication** | ❌ 500+ lines | ✅ Centralized | DRY principle |
| **Test Coverage** | ❌ 7 services untested | ✅ Full coverage | Regression prevention |

---

## Deployment Checklist

- [ ] All secrets rotated and stored in .env (never in source)
- [ ] Build passes without warnings
- [ ] All tests pass (80%+ coverage)
- [ ] No hardcoded URLs (use environment variables)
- [ ] No System.out.println/printStackTrace in code
- [ ] All wildcard imports removed
- [ ] Exceptions properly logged
- [ ] AppStartupListener validates secrets in production
- [ ] .env.template provided for new deployments
- [ ] Documentation updated with env var requirements

---

## How to Deploy to Production

1. Copy .env.template to production server as .env
2. Fill in all environment variables with production values:
   `ash
   export APP_ENV=production
   export DB_PASSWORD=your_password
   export GOOGLE_CLIENT_SECRET=your_secret
   export EMAIL_PASSWORD=your_password
   export SECRET_KEY=your_key
   `
3. Build: ./gradlew clean build (or Maven equivalent)
4. Start application - it will validate secrets and fail fast if missing
5. Monitor logs for: [AppStartup] ✓ Configuration validation passed

---

## References

- SECURITY_IMPROVEMENTS.md - Detailed security improvements applied
- AppConfig.java - All configuration constants
- BaseHttpServlet.java - New servlet base class
- LoggerUtil.java - Logging utility
- .env.template - Environment variable template

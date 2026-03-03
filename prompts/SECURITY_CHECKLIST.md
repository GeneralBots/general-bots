# General Bots Security Checklist

## Critical (P1) - Must Fix Immediately

### Authentication & Authorization
- [ ] **SecurityManager Integration** - Initialize in bootstrap
- [ ] **CSRF Protection** - Enable for all state-changing endpoints
- [ ] **Error Handling** - Replace all `unwrap()`/`expect()` calls
- [ ] **Security Headers** - Apply to all HTTP routes

### Data Protection
- [ ] **TLS/MTLS** - Ensure certificates are generated and validated
- [ ] **SafeCommand Usage** - Replace all `Command::new()` calls
- [ ] **Error Sanitization** - Use `ErrorSanitizer` for all HTTP errors

## High Priority (P2) - Fix Within 2 Weeks

### Authentication
- [ ] **Passkey Support** - Complete WebAuthn implementation
- [ ] **MFA Enhancement** - Add backup codes and recovery flows
- [ ] **API Key Management** - Implement rotation and expiration

### Monitoring & Detection
- [ ] **Security Monitoring** - Integrate `SecurityMonitor` with app events
- [ ] **DLP Policies** - Configure default policies for PII/PCI/PHI
- [ ] **Rate Limiting** - Apply consistent limits across all endpoints

## Medium Priority (P3) - Fix Within 1 Month

### Infrastructure
- [ ] **Certificate Management** - Add expiration monitoring and auto-renewal
- [ ] **Audit Logging** - Ensure comprehensive coverage
- [ ] **Security Testing** - Create dedicated test suite

### Compliance
- [ ] **Security Documentation** - Update policies and procedures
- [ ] **Compliance Mapping** - Map controls to SOC2/GDPR/ISO27001
- [ ] **Evidence Collection** - Implement automated evidence gathering

## Quick Wins (Can be done today)

### Code Quality
- [ ] Run `cargo clippy --workspace` and fix all warnings
- [ ] Use `cargo audit` to check for vulnerable dependencies
- [ ] Replace 10 `unwrap()` calls with proper error handling

### Configuration
- [ ] Check `.env` files for hardcoded secrets (move to `/tmp/`)
- [ ] Verify `botserver-stack/conf/` permissions
- [ ] Review `Cargo.toml` for unnecessary dependencies

### Testing
- [ ] Test authentication flows with invalid credentials
- [ ] Verify CSRF tokens are required for POST/PUT/DELETE
- [ ] Check security headers on main endpoints

## Daily Security Tasks

### Morning Check
- [ ] Review `botserver.log` for security events
- [ ] Check `cargo audit` for new vulnerabilities
- [ ] Monitor failed login attempts
- [ ] Verify certificate expiration dates

### Ongoing Monitoring
- [ ] Watch for unusual access patterns
- [ ] Monitor DLP policy violations
- [ ] Track security metric trends
- [ ] Review audit logs for anomalies

### Weekly Tasks
- [ ] Run full security scan with protection tools
- [ ] Review and rotate any expiring credentials
- [ ] Update security dependencies
- [ ] Backup security configurations

## Emergency Response

### If you suspect a breach:
1. **Isolate** - Disconnect affected systems
2. **Preserve** - Don't delete logs or evidence
3. **Document** - Record all actions and observations
4. **Escalate** - Contact security team immediately
5. **Contain** - Implement temporary security measures
6. **Investigate** - Determine scope and impact
7. **Remediate** - Fix vulnerabilities and restore services
8. **Learn** - Update procedures to prevent recurrence

## Security Tools Commands

### Dependency Scanning
```bash
cargo audit
cargo deny check
cargo geiger
```

### Code Analysis
```bash
cargo clippy --workspace -- -D warnings
cargo fmt --check
```

### Security Testing
```bash
# Run security tests
cargo test -p bottest --test security

# Check for unsafe code
cargo geiger --forbid

# Audit dependencies
cargo audit --deny warnings
```

### Protection Tools
```bash
# Security scanning
curl -X POST http://localhost:9000/api/security/protection/scan

# Get security report
curl http://localhost:9000/api/security/protection/report

# Check tool status
curl http://localhost:9000/api/security/protection/status
```

## Common Security Issues to Watch For

### 1. Hardcoded Secrets
**Bad:** `password = "secret123"` in code
**Good:** `password = env::var("DB_PASSWORD")?` from `/tmp/`

### 2. Unsafe Command Execution
**Bad:** `Command::new("rm").arg("-rf").arg(user_input)`
**Good:** `SafeCommand::new("rm")?.arg("-rf")?.arg(sanitized_input)?`

### 3. Missing Input Validation
**Bad:** `format!("SELECT * FROM {}", user_table)`
**Good:** `validate_table_name(&user_table)?; format!("SELECT * FROM {}", safe_table)`

### 4. Information Disclosure
**Bad:** `Json(json!({ "error": e.to_string() }))`
**Good:** `let sanitized = log_and_sanitize(&e, "context", None); (StatusCode::INTERNAL_SERVER_ERROR, sanitized)`

## Security Contact Information

**Primary Contact:** security@pragmatismo.com.br  
**Backup Contact:** Check `security.txt` at `/.well-known/security.txt`

**Emergency Response:** Follow procedures in `botbook/src/12-auth/security-policy.md`

---
*Last Updated: 2026-02-22*  
*Review Frequency: Weekly*  
*Next Review: 2026-03-01*

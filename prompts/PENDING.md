# Pending Tasks - General Bots Platform

> **Last Updated:** 2025-02-28
> **Purpose:** Track actionable tasks and improvements for the GB platform

---

## 🔐 Authentication & Identity (Zitadel)

- [ ] **Fix Zitadel setup issues**
  - Check v4 configuration
  - Update `zit.md` documentation
  - Test login at `http://localhost:3000/login`
  - Run `reset.sh` to verify clean setup

---

## 📚 Documentation Consolidation

- [ ] **Aggregate all PROMPT.md files into AGENTS.md**
  - Search git history for all PROMPT.md files
  - Consolidate into root AGENTS.md
  - Remove duplicate/ghost lines
  - Keep only AGENTS.md at project root

- [ ] **Update all README.md files**
  - Add requirement: Only commit when warnings AND errors are 0
  - Add requirement: Run `cargo check` after editing multiple `.rs` files
  - Include Qdrant collection access instructions
  - Document Vault usage for retrieving secrets

---

## 🔒 Security & Configuration (Vault)

- [ ] **Review all service configurations**
  - Ensure Gmail and other service configs go to Vault
  - Store per `botid + setting` or `userid` for individual settings

- [ ] **Remove all environment variables**
  - Keep ONLY Vault-related env vars
  - Migrate all other configs to Vault

- [ ] **Database password management**
  - Generate custom passwords for all databases
  - Store in Vault
  - Update README with Vault retrieval instructions

---

## 🎯 Code Quality & Standards

- [ ] **Clean gbai directory**
  - Remove all `.ast` files (work artifacts)
  - Remove all `.json` files (work artifacts)
  - Add `.gitignore` rules to prevent future commits

- [ ] **Fix logging prefixes**
  - Remove duplicate prefixes in `.rs` files
  - Example: Change `auth: [AUTH]` to `auth:`
  - Ensure botname and GUID appear in all bot logs

- [ ] **Review bot logs format**
  - Always include `botname` and `guid`
  - Example: `drive_monitor:Error during sync for bot MyBot (a818fb29-9991-4e24-bdee-ed4da2c51f6d): dispatch failure`

---

## 🗄️ Database Management

- [ ] **Qdrant collection management**
  - Add collection viewing instructions to README
  - Document collection access methods
  - Add debugging examples

- [ ] **BASIC table migration**
  - Implement table migration in BASIC language
  - Document migration process

---

## 🧹 Cleanup Tasks

- [ ] **Remove outdated documentation snippets**
  - Remove: "Tools with C++ support, then:# Install PostgreSQL (for libpq)choco install postgresql"

---

## 📝 Notes


---

## 🚀 Priority Order

1. **High Priority:** Security & Configuration (Vault integration)
2. **High Priority:** Authentication & Identity (Zitadel setup)
3. **Medium Priority:** Code Quality & Standards
4. **Medium Priority:** Documentation Consolidation
5. **Low Priority:** Cleanup Tasks

---

## 📋 Task Template

When adding new tasks, use this format:

```markdown
- [ ] **Task Title**
  - Detail 1
  - Detail 2
  - Related file: `path/to/file.ext`
```

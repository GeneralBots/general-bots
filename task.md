# Security Review Task List

## 1. Unsafe Unwraps in Production (Violates AGENTS.md Error Handling Rules)
The `AGENTS.md` explicitly forbids the use of `.unwrap()`, `.expect()`, `panic!()`, `todo!()`, and `unimplemented!()` in production code. A search of the codebase revealed several instances of `unwrap()` being used in non-test contexts.

**Vulnerable Locations:**
- `botserver/src/drive/drive_handlers.rs:269` - Contains a `.unwrap()` call during `Response::builder()` generation, which could panic in production.
- `botserver/src/basic/compiler/mod.rs` - Contains `unwrap()` usages outside test boundaries.
- `botserver/src/llm/llm_models/deepseek_r3.rs` - Contains `unwrap()` usages outside test boundaries.
- `botserver/src/botmodels/opencv.rs` - Test scopes use `unwrap()`, but please audit carefully for any leaks to production scope.

**Action:**
- Replace all `.unwrap()` occurrences with safe alternatives (`?`, `unwrap_or_default()`, or pattern matching with early returns) and use `ErrorSanitizer` to avoid panics.

## 2. Dependency Vulnerabilities (Found by cargo audit)
Running `cargo audit` uncovered a reported vulnerability inside the dependency tree.

**Vulnerable Component:**
- **Crate:** `glib`
- **Version:** `0.18.5`
- **Advisory ID:** `RUSTSEC-2024-0429`
- **Title:** Unsoundness in `Iterator` and `DoubleEndedIterator` impls for `glib::VariantStrIter`
- **Dependency Tree context:** It's pulled through `botdevice` and `botapp` via Tauri plugins and GTK dependencies.

**Action:**
- Review dependencies and upgrade the GTK/Glib ecosystem dependencies if patches are available, or evaluate the exact usage to assess the direct risk given the desktop GUI context.

## 3. General Posture Alignment
- Ensure all new state-changing endpoints are correctly shielded by the custom CSRF store (`redis_csrf_store.rs`). Verification is recommended as standard `tower-csrf` is absent from `Cargo.toml`.
- Confirm security headers (`Content-Security-Policy` via `headers.rs`) are indeed attached universally in `botserver` and not selectively omitted in new modules.

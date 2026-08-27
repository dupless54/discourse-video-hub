---
name: project-security-review
description: Expand only around Video Hub security-sensitive boundaries.
---
# Security Review
Review only applicable boundaries: Guardian/IDOR and hidden-profile non-enumeration; mass assignment; publish/delete/reorder replay and idempotency; provider URL parsing; exact host/scheme allowlist; DNS/IP and redirect revalidation; timeout/response limits; raw HTML/script rejection; secret redaction; discovery signal abuse; retention/privacy; and destructive cleanup. Provider fetch is always T2.

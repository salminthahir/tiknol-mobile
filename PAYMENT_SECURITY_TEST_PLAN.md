# Payment Security Test Plan — Tiknol POS Mobile (Duitku Integration)

**Date:** 30 June 2026  
**Scope:** Flutter client + black-box backend assumptions + Duitku sandbox  
**Target:** Security of the payment flow (QRIS + WebView redirect channels)  
**Status:** In Progress

---

## 1. Executive Summary

This document focuses exclusively on the **payment flow security** of the Tiknol POS Mobile application, which uses Duitku as the payment gateway. Analysis of the current codebase reveals **two CRITICAL vulnerabilities** that allow a client-side actor to spoof a successful payment without any funds actually being transferred.

Key findings stem from a direct conflict between Duitku's own documentation warnings and the current Flutter implementation.

---

## 2. Payment Architecture

### 2.1 Client-Side Flow (actual code)

```
cart_panel._processOnlinePayment()
  └─ OrderService.createOnlinePayment()
       POST /api/tokenizer  →  Backend calls Duitku v2/inquiry
       Response: { paymentUrl, orderId, qrString, amount, expiryPeriod }
            ├─ qrString != ""  → QrisPaymentScreen
            │                    └─ poll every 5s → /api/payment/check-status
            └─ qrString == ""  → PaymentWebView
                                 ├─ load paymentUrl in WebView
                                 ├─ detect success from URL patterns
                                 └─ return true/false to cart_panel
```

### 2.2 Backend Endpoints (out of repo — tested as black-box)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/tokenizer` | POST | Creates order, calls Duitku inquiry |
| `/api/payment/check-status` | POST | Returns payment status string |
| `/api/payment/reset` | POST | Cancels pending order |
| `/api/cash-order` | POST | Cash payment (no Duitku) |

### 2.3 Duitku API Reference

- **Inquiry:** `POST /webapi/api/merchant/v2/inquiry` (sandbox / passport)
- **Callback:** Server-to-server POST with `signature = HMAC_SHA256(merchantCode + amount + merchantOrderId, apiKey)`
- **Check Transaction:** `POST /webapi/api/merchant/transactionStatus` with signature
- **Critical Warning from Docs:**
  > "Do not use `resultCode` to update payment status on your app or website. You can use parameters as the basis for payment information. Please note that **the URL can be changed manually by the customer**."

---

## 3. Vulnerability Register

### PV-1 [CRITICAL] Client-Side Payment Success Spoofing via URL
- **Location:** `lib/screens/payment_webview.dart:50-72`
- **Severity:** CRITICAL
- **CWE:** CWE-807 (Reliance on Untrusted Inputs), CWE-20 (Improper Input Validation)
- **Description:**
  The `PaymentWebView` determines payment success purely by matching URL strings:
  ```dart
  if (url.contains('/ticket/${widget.orderId}')) { ... Navigator.pop(context, true); }
  if (url.contains('status=success') || url.contains('result=00')) { ... Navigator.pop(context, true); }
  ```
  With `JavaScriptMode.unrestricted` and `onNavigationRequest` always returning `navigate`, any crafted URL containing these substrings will be treated as a successful payment. This directly violates Duitku's documentation warning.
- **Impact:**
  - Attacker can trigger receipt printing and cart clearing without paying.
  - MITM attacker can inject redirect to success URL.
  - Malicious JavaScript on payment page could navigate to spoofed success URL.
- **Reproduction Steps:**
  1. Initiate online payment (WebView path).
  2. Inside WebView, navigate to `https://evil.com/fake?status=success`.
  3. App pops with `true` → cart cleared, receipt printed.

### PV-2 [CRITICAL] Missing Server Verification on WebView Success Path
- **Location:** `lib/screens/widgets/cart_panel.dart:218`
- **Severity:** CRITICAL
- **Description:**
  When `PaymentWebView` returns `true`, `cart_panel` immediately proceeds to success: clears cart, prints receipt, shows success dialog. It **never calls `checkPaymentStatus`**. The QRIS path at least polls the server; the WebView path trusts the client entirely.
- **Impact:** Same as PV-1 — phantom payments.

### PV-3 [HIGH] Price / Discount Tampering via Client-Side Payload
- **Location:** `lib/services/order_service.dart:22-39, 60-78`
- **Severity:** HIGH
- **Description:**
  `createCashOrder` and `createOnlinePayment` send `price`, `subtotal`, `discountAmount`, `totalAmount`, `voucherId` from the client. If the backend trusts these values when constructing the Duitku `paymentAmount` and signature (rather than recalculating from the product database), an attacker can modify prices or apply unauthorized discounts.
- **Impact:** Underpayment, unauthorized discounts, revenue loss.
- **Black-box Test:** Intercept `/api/tokenizer` request, modify `subtotal`/`discountAmount`, check if Duitku `amount` changes.

### PV-4 [HIGH] Cleartext HTTP by Default
- **Location:** `lib/core/constants.dart:6`
- **Severity:** HIGH
- **Description:**
  Default `baseUrl` is `http://192.168.100.95:3000`. In production builds, if not overridden by `--dart-define=API_BASE_URL`, all traffic (including session cookie `staff_session`, order data, payment status) is transmitted in plaintext.
- **Impact:** MITM can intercept `staff_session`, inject fake success URLs (PV-1), or modify payment payloads (PV-3).

### PV-5 [MEDIUM] Silent Failure in Payment Status Check
- **Location:** `lib/services/order_service.dart:103-119`
- **Severity:** MEDIUM
- **Description:**
  `checkPaymentStatus` catches all exceptions and returns `'PENDING'`. Network failures, 500 errors, or tampered responses are indistinguishable from genuine pending status. If the backend's `/api/payment/check-status` does not independently verify with Duitku's `transactionStatus` endpoint using the proper HMAC-SHA256 signature, the entire polling mechanism is unreliable.
- **Impact:** User may wait for expired QRIS indefinitely; false pending states.

### PV-6 [MEDIUM] No Certificate Pinning
- **Location:** `lib/core/api_client.dart`
- **Severity:** MEDIUM
- **Description:**
  No certificate pinning is implemented. Combined with PV-4 (HTTP default), this makes MITM attacks trivial. Even with HTTPS, lack of pinning allows rogue CA or corporate proxy interception.
- **Impact:** Downgrade to HTTP, certificate substitution.

### PV-7 [LOW] Screenshot on Payment Screens
- **Location:** `lib/screens/qris_payment_screen.dart`, `lib/screens/payment_webview.dart`
- **Severity:** LOW
- **Description:**
  No `FLAG_SECURE` or screenshot prevention on payment screens. QR string and payment URLs can be captured.
- **Impact:** Information leakage via screenshots or screen recording.

---

## 4. Testing Methodology

### 4.1 Static Analysis (Code Review)
- Review all files in `lib/services/order_service.dart`, `lib/screens/payment_webview.dart`, `lib/screens/qris_payment_screen.dart`, `lib/screens/widgets/cart_panel.dart`.
- Verify callback signature validation logic on backend (black-box: inspect response behavior).

### 4.2 Dynamic Analysis (Sandbox Duitku)
1. Obtain sandbox credentials (`merchantCode`, `apiKey`).
2. Create real transaction via `/api/tokenizer`.
3. **Spoof test (PV-1):** Do NOT complete payment. Instead, force WebView to navigate to URL containing `status=success`. Assert app treats it as paid.
4. **Tamper test (PV-3):** Intercept `/api/tokenizer` with Burp/Charles, modify `subtotal` and `discountAmount`. Assert whether Duitku inquiry amount follows client values.
5. **Callback test:** Send forged callback POST to backend with wrong signature. Assert rejection (HTTP 400/403).
6. **MITM test (PV-4):** Run app through HTTP proxy without certificate. Assert cleartext traffic is interceptable.

### 4.3 Unit & Widget Tests (Dart)
Goal: Prove vulnerabilities exist and serve as regression guards.

| Test File | Target | Coverage |
|-----------|--------|----------|
| `test/security/payment_webview_spoof_test.dart` | PV-1, PV-2 | URL spoof triggers success; assert current broken behavior |
| `test/security/order_service_tampering_test.dart` | PV-3, PV-5 | Payload tampering surface; fail-closed on error |
| `test/security/payment_flow_integration_test.dart` | PV-2 | WebView success without server check prints receipt |
| `test/security/transport_security_test.dart` | PV-4, PV-6 | Assert HTTP default, no pinning, unrestricted JS |

> **Note:** These tests intentionally assert the *current vulnerable behavior* to document proof-of-vulnerability. After remediation, the assertions should be flipped to enforce secure behavior.

---

## 5. Remediation Checklist (post-testing)

- [ ] **PV-1/PV-2:** Never trust WebView URL for payment status. On WebView close, always call `checkPaymentStatus` and verify `PAID` before clearing cart/printing receipt.
- [ ] **PV-3:** Backend must recalculate `paymentAmount` from product DB and reject any client-side price/discount mismatch.
- [ ] **PV-4:** Enforce HTTPS in production; add network security config (`android:networkSecurityConfig`); block cleartext.
- [ ] **PV-5:** `checkPaymentStatus` must distinguish errors from pending; backend must verify Duitku `transactionStatus` with HMAC-SHA256 signature.
- [ ] **PV-6:** Implement certificate pinning for production API domain.
- [ ] **PV-7:** Add `FLAG_SECURE` on payment screens.

---

## 6. References

- [Duitku API Documentation v2](https://docs.duitku.com/api/en/)
- [OWASP Mobile Application Security Testing Guide (MASTG)](https://mas.owasp.org/MASTG/)
- [OWASP Mobile AppSec Verification Standard (MASVS)](https://mas.owasp.org/MASVS/)
- Existing: `SECURITY_AUDIT.md` (general security audit)
- Existing: `TESTING_PLAN.md` (general testing plan)

---

*Document Version:* 1.0  
*Last Updated:* 30 June 2026

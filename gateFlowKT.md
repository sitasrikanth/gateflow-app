# GateFlow — Knowledge Transfer Document

> Purpose: Reference guide explaining *why* specific design decisions were made — especially around what different user roles can and cannot see. Use this before changing any visibility logic.

---

## Contributions — What Admin Sees vs What Resident Sees

### Design Principle

Residents should have **enough transparency to trust the admin** but **not enough to invade each other's privacy**. Individual financial data (who paid what) is personal. Aggregate data (how many flats in a block paid) is community information and builds trust.

---

### Visibility Table — Contributions Tab (Event Dashboard)

| Information | Admin | Resident | Reason |
|-------------|-------|----------|--------|
| Total amount collected | ✅ Yes | ✅ Yes | Community-level figure; builds trust that funds are being tracked |
| Target amount for event | ✅ Yes | ✅ Yes | Everyone should know the goal |
| Progress bar (collected vs target) | ✅ Yes | ✅ Yes | High-level transparency; no individual data exposed |
| Block-level summary (e.g. "Diamond A: 12/15 flats paid") | ✅ Yes | ✅ Yes | Aggregate count — no individual flat identified. Residents can see collection is happening honestly without seeing neighbours' details |
| Which specific flat paid | ✅ Yes | ❌ No | Flat-level = individual financial data. Knowing "DA101 paid" reveals a neighbour's payment status |
| Amount paid by another flat | ✅ Yes | ❌ No | Individual financial amount is private. Different flats may have negotiated different amounts or have arrears |
| Own flat's contribution status | ✅ Yes | ✅ Yes | Resident must be able to verify their own payment was recorded correctly |
| Own flat's payment amount | ✅ Yes | ✅ Yes | Their own financial data — they have full right to see it |
| Own flat's payment mode & reference | ✅ Yes | ✅ Yes | Needed to raise a dispute if admin recorded incorrectly |
| Resident name against a contribution | ✅ Yes | ❌ No | Names are personal identifiers. Even if the flat is anonymous, names make it traceable |
| Unassigned / orphan contributions | ✅ Yes | ❌ No | Admin housekeeping data; not meaningful to residents |
| Edit or delete any contribution | ✅ Yes | ❌ No | Only admin can correct records; prevents self-reporting abuse |
| Pending Verification badge (own flat) | ✅ Yes | ✅ Yes | Resident needs to know their self-report is awaiting admin confirmation |

---

### Block-Level Summary — Why This Specifically

When a resident sees "₹18,000 collected" but has no visibility into other flats, a natural suspicion arises: *"Is the admin making this up?"*

The block summary (e.g. **Diamond A: 12/15 · Diamond B: 8/15**) gives residents a sanity check:
- They can count their own block's flats and verify the number is plausible
- They can see collection is spread across blocks (not just one flat)
- They do NOT learn which specific flat paid or how much

This is the minimum transparency needed to maintain trust without violating privacy.

---

### Follow-up Tab — Resident vs Admin

| Information | Admin | Resident |
|-------------|-------|----------|
| Full Wing → Block → Flat chip grid | ✅ Yes | ❌ No |
| Send WhatsApp reminder to unpaid flats | ✅ Yes | ❌ No |
| Own flat's status chip | ✅ Yes | ✅ Yes (shown in Contributions tab, not Follow-up) |

Residents do not have access to the Follow-up tab at all. The tab exists only in the admin Event Dashboard.

---

### Self-Report Flow — Privacy Notes

When a resident self-reports a payment ("I've Paid"):
- It is saved as `selfReported: true, amountReceived: false`
- The resident's **name** is stored so the admin can verify against bank records
- The admin sees the name + flat + amount; other residents do **not** see this pending entry
- Once admin confirms, it moves to `amountReceived: true` — still invisible to other residents

---

## Community Settings — What Admin Sees vs What Resident Sees

| Information | Admin | Resident |
|-------------|-------|----------|
| Full Wings → Blocks → Flats hierarchy | ✅ Yes (editable) | ✅ Yes (read-only, used for flat picker) |
| Add / rename / delete wings or blocks | ✅ Yes | ❌ No |
| Flats per floor setting | ✅ Yes | ❌ No |
| Expense categories management | ✅ Yes | ❌ No |

---

## Registration Approval — WhatsApp Notification

When admin approves or rejects a pending registration:
- Admin is shown a dialog with a **WhatsApp deep-link button**
- The button opens WhatsApp with a pre-filled message to the resident's registered phone number
- This is an **opt-in action** — admin can skip sending the WhatsApp message
- The message for approval includes the resident's 6-digit Quick Code
- The message for rejection advises them to contact the office

**Android 11+ note:** The `AndroidManifest.xml` must declare `<queries>` for HTTPS intent and WhatsApp package (`com.whatsapp`, `com.whatsapp.w4b`) or `canLaunchUrl` will return false and WhatsApp will not open.

---

## Resident Self-Report ("I've Paid") — Design Decisions

| Decision | Reason |
|----------|--------|
| Self-reports saved as `amountReceived: false` | Not confirmed until admin verifies against bank/UPI records |
| Admin must manually confirm or reject | Prevents fake payment reports from residents |
| Resident can see their own pending self-report | Transparency — they know it's received and awaiting verification |
| Other residents cannot see self-reports | Avoids social pressure — a flat's pending report is their own business |
| Transaction Ref / UTR is optional (not mandatory) | Some residents pay cash; forcing a UTR would block legitimate reports |

---

*Document Version: 1.0 | Created: 2026-06-21 | Maintained by: Development team*

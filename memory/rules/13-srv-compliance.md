---
id: srv-compliance
title: SRV compliance
status: stable
---

# SRV compliance (write to the standard, not to the reviewer)

The team keeps a catalogue of Standard Review Violations (SRVs) — known, named review findings. A reviewer (or `/sky-review`) will flag any that slip through. Never ship a change containing an SRV you could have avoided while writing it. SRV compliance is part of implementation, not just review.

When implementing or editing C#/.NET 6 code — whether via `/sky-fast`, `/sky-task`, another skill, or a plain request — apply the SRVs as you write. Keep the recurring ones in mind:

- **SRV-H-001** — no sync I/O inside `async` methods.
- **SRV-L-010** — accept a `CancellationToken` and thread it through every awaited call.
- **SRV-H-006** — parse/format `DateTime` with `CultureInfo.InvariantCulture` + `DateTimeStyles`; never culture/timezone-dependent.
- **SRV-L-004** — keep controllers thin (bind → dispatch → map); logic lives in the handler/service.
- **SRV-M-003** — keep the Unit-of-Work boundary aligned with the transaction boundary.

If the change touches async, data/persistence, globalization, caching, or security, consult the matching SRV file in the authoritative catalogue before finishing: `C:\SharedProjects\SkyOps\standards\SRV-CATALOG.md` (+ the `SRV-*.md` files). Before a change is ready to push, self-check the diff against the SRVs (or run `/sky-review`) and fix what you find — don't leave a known SRV for the reviewer.

# TODO

## Ticket-0002 (NVIDIA sandbox fix) — open follow-ups

Context: Discord ticket-0002 (Digit, RTX 4070 Ti, NVIDIA 580, Fedora/Flathub). The engine fix
shipped in 1.0.6/1.0.7 across all platforms; only these two follow-ups remain.

- [ ] Reply on ticket-0002: update to latest (Flathub publishes after the PR merge), no cache
      clearing needed, retry both world.gate and museum_of_all_things. Digit's 4070 Ti is the
      only real NVIDIA verification available — the dev box is AMD and cannot stage the bug.
- [ ] Watch Mixpanel (project `3024833`, event `error`, Linux) for versions ≥1.0.6 — the
      bootup-crash signal should disappear. Mixpanel reports ~UTC+7; server logs are UTC.

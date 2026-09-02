# Future Work

Ideas deliberately kept *out* of this kit's 3-week scope, captured so they aren't
lost. This kit's design contract is small, cheap, disposable, one-isolated-
misconfiguration-per-scenario, deploy→attack→detect→destroy in under an hour.
The ideas below intentionally break that contract, which is exactly why they
belong in a separate project rather than here.

---

## Project 2 — "Full-Chain Compromise of a Retailer" (a multi-stage attack range)

A single, persistent, realistic environment modelling an end-to-end intrusion of
a fictional e-commerce company, where the attacker chains several weaknesses to
go from *no access* to *full infrastructure compromise* — the opposite of this
kit's isolated single-issue scenarios.

### The attack chain (as envisioned)

1. **Initial access — phishing.** A simulated phishing foothold (the human/email
   step would be *simulated*, since real phishing can't live in an automated
   lab) yields access to a low-value foothold — e.g. leaked credentials or a
   developer workstation.
2. **Exposed backup/snapshot.** From that foothold, discover an old, publicly- or
   over-broadly-shared EBS snapshot or RDS snapshot / S3 backup containing stale
   but still-useful data (config, an app bundle, hardcoded secrets).
3. **Vulnerable e-commerce EC2.** The snapshot reveals another EC2 running an
   outdated version of some e-commerce software with a known CVE; exploit it for
   a second, deeper foothold.
4. **Legacy AD server.** From there, reach an old Active Directory / domain
   controller (AWS Managed Microsoft AD, or a self-hosted DC on EC2) that was
   never decommissioned.
5. **Cached admin credentials.** On the AD server, recover credentials for a
   former admin user who still had access to the crown-jewel systems.
6. **Core EC2 → root.** Use those credentials to reach the main EC2 instance
   running the retailer's core services, and escalate to root — full compromise.
7. **(Stretch) Self-healing event.** An automated detection-and-response
   capability that notices the intrusion and restores/isolates the compromised
   infrastructure — the "blue team automation" counterpart to the attack.

### Why it's a separate project, not a scenario here

- **Cost & footprint.** Managed AD (~$0.40+/hr), RDS, an e-commerce stack, and
  several always-on EC2s is real money and days of setup — it cannot honor the
  "under $10, tear down in an hour" contract this kit lives by.
- **Persistence vs. disposability.** A chain like this only makes sense as a
  standing environment you explore over time, not a deploy-and-destroy cycle.
- **Not one isolated misconfiguration.** The whole point is *many* weaknesses
  chained together — the opposite of this kit's "exactly one thing wrong so the
  detection query is unambiguous" teaching design.
- **Deploy-user scope.** `IaC_user` is deliberately scoped to three name
  prefixes and a handful of services; AD (Directory Service), RDS, snapshot
  sharing, etc. would require a large policy expansion and several admin Console
  round-trips.
- **Phishing doesn't automate.** The initial-access step would have to be faked,
  which changes its character and is better designed deliberately, not bolted on.

### The bridge

**Scenario 03 (EC2 Lateral Movement) is effectively the first network hop of
this chain** — compromise one host, pivot to another you shouldn't be able to
reach. Building it in this kit doubles as a proof-of-concept for whether Project
2 is worth the larger investment, and the Terraform/Ansible/Flow-Logs patterns it
establishes would carry directly into it.

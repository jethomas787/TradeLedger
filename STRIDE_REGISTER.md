# STRIDE Threat Register — TradeLedger v8

| # | Component       | Threat             | Description                                                                 | Control                                                                 | Status     |
|---|----------------|--------------------|-----------------------------------------------------------------------------|-------------------------------------------------------------------------|------------|
| 1 | CI/CD pipeline | Spoofing (S)       | Attacker impersonates the pipeline identity to access Azure resources      | OIDC federated credentials — no password exists. JWT is 15-min, non-replayable | Mitigated |
| 2 | Repository     | Tampering (T)      | Direct push to `main` bypasses code review, allowing malicious code into prod | Branch protection: PRs required, force pushes blocked, 1 required reviewer | Mitigated |
| 3 | Repository     | Info Disclosure (I)| Developer accidentally commits credentials, API keys, or storage account keys | detect-secrets in CI; `.gitignore` blocks `.env`; `python-dotenv` removed from project | Mitigated |
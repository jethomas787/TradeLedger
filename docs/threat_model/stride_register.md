+-----------------------+-----------------------------------------------------------+
| FIELD                 | DETAILS                                                   |
+=======================+===========================================================+
| [S] SPOOFING          |                                                           |
| Component             | PostgreSQL Flexible Server                                 |
| Threat                | Attacker impersonates admin to read/write trade data.     |
| Mitigation            | Managed Identity auth; No passwords in env or history.    |
| Traceable To          | keyvault.tf: pg-connection-string secret                  |
+-----------------------+-----------------------------------------------------------+
| [T] TAMPERING         |                                                           |
| Component             | ADLS Gen2 /bronze/                                        |
| Threat                | Unauthorized write to bronze layer corrupts audit trail.  |
| Mitigation            | HNS ACLs; No public blob access; TLS 1.2 enforced.        |
| Traceable To          | main.tf: allow_nested_items_to_be_public=false            |
+-----------------------+-----------------------------------------------------------+
| [R] REPUDIATION       |                                                           |
| Component             | Service Principal                                         |
| Threat                | SP performs action; no audit trail makes it deniable.     |
| Mitigation            | Azure Activity Log; Restricted to Secrets Officer only.   |
| Traceable To          | keyvault.tf: Key Vault Secrets Officer role               |
+-----------------------+-----------------------------------------------------------+
| [I] INFO DISCLOSURE   |                                                           |
| Component             | Key Vault Secrets                                         |
| Threat                | Secret values exposed via Git history or TF state.        |
| Mitigation            | RBAC model; .tfstate and .tfvars are gitignored.          |
| Traceable To          | .gitignore; variables.tf: sensitive=true                  |
+-----------------------+-----------------------------------------------------------+
| [D] DENIAL OF SERVICE |                                                           |
| Component             | PostgreSQL B1ms                                           |
| Threat                | Idle server accumulates cost; runaway scaling.            |
| Mitigation            | terraform destroy after session; $15 CAD weekly budget.   |
| Traceable To          | Cost Management budget; Makefile: destroy target          |
+-----------------------+-----------------------------------------------------------+
| [E] ELEVATION OF PRIV |                                                           |
| Component             | Service Principal                                         |
| Threat                | SP gains Entra ID roles beyond Resource Group scope.      |
| Mitigation            | Contributor + UAA on RG only; No directory roles.         |
| Traceable To          | Day 2: SP creation scope = resource group                 |
+-----------------------+-----------------------------------------------------------+
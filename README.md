# Ephemeral Development Server on AWS Spot Instances

## Overview
This project builds a **cost-efficient, reproducible development environment** on **AWS EC2 Spot Instances**, using **Debian Linux** as the base system.  
Each instance is **disposable** — configuration and data are restored automatically at boot, allowing a clean, consistent workspace every time while minimizing ongoing costs.

The server is fully **automated with Terraform, Ansible, and Restic**, and accessed securely over **Tailscale**.

---

## Goals

- **Ephemeral by design:** Each instance is temporary, with all important state restored automatically.
- **Reproducible environment:** System packages, user configuration, and secrets are rebuilt from versioned sources.
- **Cost-effective operation:** Uses Spot capacity and ephemeral NVMe storage (no persistent EBS data).
- **Secure and minimal:** No public network exposure; all access via Tailscale.
- **Automatic cleanup:** Idle or interrupted instances back up and terminate themselves.

---

## Architecture

| Component | Purpose |
|------------|----------|
| **Terraform** | Provisions a single Spot instance, IAM role, and required SSM parameters. |
| **User Data (cloud-init)** | Bootstraps the system: installs dependencies, runs Ansible, and restores data. |
| **Ansible** | Configures system packages, mounts ephemeral storage, creates user accounts, and fetches SSH keys from SSM. |
| **Restic (S3 backend)** | Stores encrypted backups of both configuration and user data. |
| **Tailscale** | Provides private, authenticated network access; SSH and file transfer over Tailnet. Uses OIDC authentication via AWS STS. |
| **SSM Parameter Store** | Holds secrets: Restic credentials, Tailscale OIDC configuration, and the pinned configuration snapshot ID. |

---

## Process Overview

1. **Launch**
   - Terraform deploys a Debian Spot instance.
   - The instance runs a bootstrap (user data) script as the `ansible` user.

2. **Ephemeral storage setup**
   - Local NVMe storage is formatted and mounted as `/home`.
   - The `debian` user (UID/GID 1000) is created; `ansible` remains UID/GID 1001 for provisioning tasks.

3. **Configuration and data restore**
   - The **known-good configuration** snapshot ID (stored in SSM) is restored from Restic into `/home/debian`.
   - The **latest data snapshot** is restored to ensure current user data.
   - Ownership and permissions are verified automatically.

4. **System configuration**
   - Ansible installs core development tools (Docker, Python, Go, etc.).
   - Tailscale is brought up using OIDC authentication: AWS STS generates a web identity token passed via `--id-token` to `tailscale up`.

5. **Normal operation**
   - The developer connects via Tailscale SSH.
   - Periodic Restic backups run (default every 10 minutes).
   - An idle monitor terminates the instance after a defined inactivity period.

6. **Backup and termination**
   - On idle timeout or Spot interruption, a final incremental Restic backup runs.
   - The instance terminates cleanly; data and config remain safely in S3.

7. **Relaunch**
   - A new instance can be created manually at any time (`terraform apply`).
   - It restores the same configuration and data automatically.

---

## Configuration Management

- **Known-good configuration:**  
  - Captured as a tagged Restic snapshot (`config`, e.g. `cfg-v12`).  
  - Snapshot ID stored in SSM (`/devserver/restic/config_snapshot_id`).  
  - Updated only when the configuration is intentionally promoted.

- **User data:**  
  - Backed up frequently (every 10 min) with Restic.  
  - Restored from the most recent snapshot at boot.

- **UID/GID consistency:**  
  - `debian` = 1000, `ansible` = 1001 across all instances for predictable file ownership.

---

## Tailscale OIDC Authentication

The system uses **OpenID Connect (OIDC)** for Tailscale authentication, eliminating the need for long-lived auth keys:

1. **AWS STS Web Identity Token Generation**
   - Uses `aws sts get-web-identity-token` with the Tailscale OIDC audience
   - Signing algorithm: ES384
   - Token duration: 60 seconds

2. **Tailscale Authentication**
   - The JWT is passed directly to the `tailscale up` command:
     ```bash
     tailscale up --client-id=${tailscale_client_id} \
                  --id-token=$(./get-jwt.sh) \
                  --advertise-tags="tag:aws" \
                  --accept-routes
     ```
   - Tailscale handles the OIDC token validation internally

3. **Configuration**
   - SSM stores the Tailscale client ID and audience string
   - Scripts in `tailscale/` demonstrate the authentication flow:
     - `get-jwt.sh` — generates AWS web identity token
     - `get-token.sh` — full flow: JWT generation + Tailscale token exchange (for testing)
     - `test-auth.sh` — debug script showing token claims and response
     - `debug-response.sh` — shows raw HTTP response for troubleshooting

---

## Security Notes

- All secrets are stored in **AWS SSM Parameter Store (SecureString)**, encrypted with **KMS**.
- Restic provides **client-side encryption** for all S3 data.
- Instances have **no public ingress**; all access via Tailscale.
- **Tailscale OIDC tokens are short-lived** (60s web identity token, limited-duration access token), reducing the risk of credential compromise.
- On termination, ephemeral storage is destroyed automatically.

---

## Lifecycle Summary

| Stage | Action |
|--------|---------|
| **Provision** | Terraform deploys the instance and dependencies. |
| **Bootstrap** | User data sets up Ansible and prepares the environment. |
| **Restore** | Restic restores config and data from S3. |
| **Operate** | Developer connects and works via Tailscale; backups run periodically. |
| **Idle/Interruption** | Backup → terminate. |
| **Relaunch** | Apply Terraform to start a new identical environment. |

---

## Key Benefits

- Zero-to-dev environment in minutes.  
- No manual cleanup — every boot starts fresh.  
- Minimal AWS cost footprint.  
- Full reproducibility from versioned backups.  
- Secure by default, with no public exposure.

---

## Future Improvements

- Add automated validation of Restic integrity on boot.  
- Add optional multi-user support or templated roles.  
- Integrate cost reporting or Spot price tracking.  
- Extend Ansible to support alternative base OS images.

---

*Created to enable fast, secure, and reproducible development on disposable cloud infrastructure.*



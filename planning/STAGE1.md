🧭 Build Plan — Ephemeral Debian Devbox on EC2 Spot

Project guardrails (what we’re committing to)
	•	Bucket: devbox-backup (Restic repo)
	•	Config pin: Restic config snapshot ID stored in SSM
	•	Home restore: restore entire $HOME from the pinned snapshot (no staging/cleanup)
	•	Users/IDs: debian → UID/GID 1000, ansible → UID/GID 1001
	•	Storage: /home on ephemeral (instance-store/NVMe)
	•	Access: Tailscale with OIDC authentication (primary). Optional SSH troubleshooting via Terraform toggle.
	•	Networking: default VPC, public subnet, public IP, no inbound unless SSH toggle is on
	•	Lifecycle: one-time Spot instance; manual relaunch when you choose (no ASG)
	•	Safety: restic every 10 minutes; idle monitor terminates; interruption handler does a best-effort backup

⸻

Phase 1 — Repo & Structure
	1.	Scaffold project
	•	Folders: terraform/, ansible/, userdata/, docs/.
	•	Drop in README and this plan.
	2.	Decide naming & versions
	•	Snapshot tag convention: config, cfg-vNN.
	•	Optional MOTD shows current config tag and snapshot ID.

⸻

Phase 2 — S3 & Restic
	3.	S3 bucket
	•	Use devbox-backup for the Restic repo (versioning on).
	•	(Optional) Use prefixes only if you want, but tags drive behavior.
	4.	Initialize Restic repo
	•	Record repo URL and password (to be stored in SSM).
	•	Decide prune/forget policy (simple defaults are fine).

⸻

Phase 3 — SSM & KMS
	5.	Create SSM parameters (SecureString)
	•	/devserver/restic/repo
	•	/devserver/restic/password
	•	/devserver/restic/config_snapshot_id  ← pinned golden home snapshot
	•	/devserver/tailscale/client_id  ← OIDC client ID
	•	/devserver/tailscale/audience  ← OIDC audience (format: api.tailscale.com/{client_id})
	•	(Optional) /devserver/ssh_authorized_keys if you want to source keys from SSM
	6.	KMS & IAM boundary
	•	KMS key scoped to this project.
	•	Instance role needs:
	•	ssm:GetParameter + kms:Decrypt for the above
	•	s3:ListBucket/GetObject on arn:aws:s3:::devbox-backup/*
	•	sts:GetWebIdentityToken for Tailscale OIDC authentication

⸻

Phase 4 — Terraform (default VPC + SSH toggle)
	7.	Networking choices
	•	Use default VPC; select a public subnet.
	•	Ensure public IP assignment is on.
	8.	Security group design
	•	Outbound: allow all.
	•	Inbound: none by default.
	•	SSH toggle:
	•	Variable allow_ssh (default false).
	•	If true, open TCP 22 only to ssh_allowed_cidr (e.g., x.x.x.x/32).
	•	Optional ssh_key_name.
	9.	EC2 Spot instance
	•	Debian 12 AMI (arch of your choice).
	•	Spot request as one-time; instance_interruption_behavior = terminate.
	•	Root EBS small (8–16 GB).
	•	Select instance type with instance store (so /home can be ephemeral).
	•	InstanceInitiatedShutdownBehavior = terminate.
	10.	Instance role & profile
	•	Attach the least-privilege policy from Phase 3.
	11.	User data
	•	Reference the bootstrap script (see Phase 5 tasks).

⸻

Phase 5 — Bootstrap (cloud-init + Ansible)
	12.	User-data flow
	•	Install base tools (awscli, jq, python3).
	•	Create ansible (1001) with home /ansible (ops-only).
	•	Fetch Ansible content (from S3 or repo).
	•	Pull SSM parameters (restic repo, password, config snapshot ID, tailscale OIDC config).
	•	Hand off to Ansible.
	13.	Ansible responsibilities
	•	Ephemeral mount: format/mount instance store and bind/mount as /home.
	•	Create debian user with UID/GID 1000 (after /home is mounted).
	•	Restic restore (config snapshot): restore the pinned snapshot directly into /home/debian.
	•	System setup: install Docker, Python, Go, editors, build tools.
	•	Tailscale: install and authenticate using OIDC: `tailscale up --client-id=... --id-token=$(get-jwt.sh) --advertise-tags="tag:aws" --accept-routes`; optionally enable Tailscale SSH.
	•	SSH keys (optional): if SSH toggle is used, place authorized_keys (from SSM or your keypair).
	•	Ownership/permissions pass: verify sensitive paths (e.g., ~/.ssh) and mode bits.

⸻

Phase 6 — Backup & Lifecycle Automation
	14.	Recurring restic backup
	•	Systemd timer: every 10 minutes incremental snapshot.
	•	Tag as data (or no tag—config is already pinned elsewhere).
	•	Light excludes only if you truly don’t need big caches.
	15.	Idle monitor
	•	Timer + service: detect no logins/activity beyond threshold; skip if backup is running.
	•	On idle: trigger quick backup → shutdown (maps to terminate).
	16.	Spot interruption handler
	•	Watch IMDS for 2-minute signal.
	•	On interrupt: quick incremental backup; log event.

⸻

Phase 7 — Config Baseline Lifecycle
	17.	Promote new baseline (when you choose)
	•	Quiesce if needed → take full-home restic snapshot.
	•	Tag with config and a version (e.g., cfg-v13).
	•	Update SSM: /devserver/restic/config_snapshot_id to the new snapshot ID.
	•	Next relaunch adopts the new baseline.
	18.	Rollback
	•	Point SSM back to a prior config snapshot ID.
	•	Relaunch to return to that baseline.
	19.	Prove the loop
	•	Periodically test a clean relaunch:
	•	Verify ownership (1000/1000), Tailscale up, backups scheduled.

⸻

Phase 8 — Observability, Security, Docs
	20.	Logging
	•	Ship bootstrap, backup, idle, and interruption logs to CloudWatch.
	•	On boot, log: config snapshot ID, and timestamp of last successful data backup.
	21.	Security posture
	•	Keep allow_ssh=false in steady state.
	•	If true, restrict to /32, key-only, and disable once Tailscale is healthy.
	•	No public ingress otherwise; rely on Tailscale/SSM.
	22.	Docs & runbooks
	•	Short guides:
	•	Launch/Relaunch
	•	Promote Config
	•	Rollback
	•	Enable SSH Troubleshooting
	•	Where logs live

⸻

Phase 9 — Nice-to-haves (optional)
	23.	MOTD status
	•	Print config tag and snapshot ID, plus last backup time.
	24.	Make targets / simple CLI
	•	make launch, make promote-config, make rollback, make backup-now, make enable-ssh, make disable-ssh.
	25.	Health check
	•	Boot-time assertion: $HOME exists, owned by 1000:1000, Tailscale connected.


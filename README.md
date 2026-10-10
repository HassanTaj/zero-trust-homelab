# Zero Trust Homelab

A public, privacy-safe reference for connecting a private homelab to remote users through an identity-aware overlay network. It documents routing, DNS, TLS, service access, storage, backups, and recovery using fictional values.

Companion repositories in the Platform Engineering Lab: [Production Platform Reference](https://github.com/HassanTaj/production-platform-reference) demonstrates the service platform, and [AI-Native Platform Operations](https://github.com/HassanTaj/ai-native-platform-ops) demonstrates evidence-led operations.

The included local demos show a public-versus-private container-network boundary and a synthetic encrypted Restic backup/restore drill. They are teaching models—not an identity provider, VPN, NetBird deployment, or production zero-trust system.

## Launch the local boundary demo

Requirements: Docker Engine with the Compose plugin. From the repository root:

```bash
docker compose -f demo/compose.yaml up --detach
```

Test the public route from the host:

```bash
curl -H "Host: public.localhost" http://127.0.0.1:8081/
```

On Windows PowerShell, use `curl.exe` instead of `curl`.

The same host should be denied on the admin route (HTTP 403):

```bash
curl -i -H "Host: admin.localhost" http://127.0.0.1:8081/
```

Test from the demo's private client network:

```bash
docker compose --profile test -f demo/compose.yaml run --rm private-client
```

Stop with `docker compose -f demo/compose.yaml down`. The gateway binds to loopback only; no router or firewall changes are needed.

Run the automated checks from Bash with `bash demo/smoke-test.sh`. It uses a unique Compose project and removes only that temporary project on exit.

## Run the synthetic backup/restore drill

Requirements: Docker Engine with the Compose plugin, OpenSSL, and Bash (Git Bash works on Windows). From the repository root:

```bash
bash demo/backup/smoke-test.sh
```

The script creates a temporary encrypted Restic repository, backs up only the synthetic files under `demo/backup/fixture/`, checks the repository, restores into an isolated volume, compares the restored files, and removes its temporary containers and volumes. It never reads host or homelab data. The ignored local password file is created only when absent and removed only if the script created it.

## Preview the documentation

Requirements: Git and Node.js 20.17 or newer.

```bash
git clone https://github.com/HassanTaj/zero-trust-homelab.git
cd zero-trust-homelab
npm install --global mint
mint dev
```

Open <http://localhost:3000>.

The network demo does not provision NetBird or launch a homelab stack, and the backup drill does not demonstrate off-host or host-loss recovery. The patterns are distilled from a private homelab, but no real network addresses, domains, keys, certificates, or personal media details belong in examples. See [demo scope](demo-scope.mdx) for exact boundaries.

## Publish the docs

Connect this GitHub repository to a Mintlify project and install Mintlify's GitHub App. After setup, pushes to the connected branch publish the docs. See the [Mintlify quickstart](https://mintlify.com/docs/quickstart).

## Documentation

- [Architecture](architecture.mdx)
- [Operational lessons](operational-lessons.mdx)
- [Storage failure case study](case-study-storage-failure.mdx)
- [Quickstart](quickstart.mdx)
- [Demo scope](demo-scope.mdx)

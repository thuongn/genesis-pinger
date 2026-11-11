# genesis-pinger

An off-box dead-man's switch for the Genesis VPS.

Every 30 minutes a GitHub Actions run fetches `https://platform.megacorp.us/health`
from outside the VPS.
If the box, its network, Caddy or the platform is down,
or the platform reports `unhealthy`,
it posts to Slack and the run fails, which also emails the repo owner.

It complements the on-box watcher (`genesis alerts check`, a systemd timer on the VPS),
which cannot report the death of the box it runs on.
`degraded` passes here because the watcher already alerts on it.

## Setup

```bash
gh secret set SLACK_WEBHOOK_URL --repo thuongn/genesis-pinger   # paste the Slack incoming webhook URL
gh workflow run ping.yml --repo thuongn/genesis-pinger           # first run, by hand
```

## Run locally

```bash
./check.sh                                    # default URL
./check.sh https://example.invalid/health     # see a failure
```

## Why a public repo

Public-repo Actions minutes are free.
The owner's private-repo quota is capped at $0,
so a check that lived there could be silently blocked when the quota runs out.
`keepalive.yml` commits monthly,
because GitHub disables schedules in public repos after 60 days of inactivity.

# Breedbase T3 Deployment Runbook

Step-by-step guide for standing up a new Breedbase instance on an Azure VM.
Run each step in order. Do not skip steps.

**Prerequisites:**
- Azure VM provisioned (B4ls_v2, Ubuntu 22.04 LTS) — see `infra/` for OpenTofu
- DNS A record pointing `CLIENT_HOSTNAME` to the VM's public IP (DNS-only, no proxy)
- SSH access to the VM

---

## 1–3. Initial VM setup, clone repos

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/countercheck/tiller/main/deploy/scripts/bootstrap.sh)
```

Or if tiller is already on the VM:

```bash
bash /opt/tiller/deploy/scripts/bootstrap.sh
```

This installs Docker, nginx, certbot, Azure CLI, and clones both repos to `/opt/`.
**Log out and back in after this step** to activate Docker group membership.

---

## 4. Set client environment variables

Create `/etc/breedbase-client.env` (not committed to git — contains secrets):

```bash
sudo tee /etc/breedbase-client.env > /dev/null <<EOF
CLIENT_HOSTNAME=violet-moose-lantern.tiller-ag.org
CLIENT_NAME=violet-moose-lantern
DB_PASSWORD=$(openssl rand -base64 24)
CONTACT_EMAIL=admin@tiller-ag.org
AZURE_STORAGE_ACCOUNT=tillerbackups
AZURE_CONTAINER=violet-moose-lantern-backups
EOF
sudo chown $USER /etc/breedbase-client.env
sudo chmod 600 /etc/breedbase-client.env
```

Verify the file looks correct before continuing:

```bash
cat /etc/breedbase-client.env
```

---

## 5–10. Deploy

```bash
bash /opt/tiller/deploy/scripts/deploy.sh
```

This script:
- Generates `/etc/nginx/sites-available/breedbase` and `/opt/breedbase/config/hordeum.conf`
  from templates, substituting values from `/etc/breedbase-client.env`
- Creates the Let's Encrypt SSL helper files (`options-ssl-nginx.conf`, `ssl-dhparams.pem`)
- Runs certbot to obtain the SSL certificate
- Starts nginx
- **Pauses** and asks you to run `./bin/breedbase setup` manually (step 8)
- After you press Enter: runs DB schema patches, grants `web_usr` DB permissions, starts
  Breedbase, and installs the backup cron job

### Step 8 (manual, inside the pause)

```bash
cd /opt/breedbase
./bin/breedbase setup
```

When prompted for the database password, use the value of `DB_PASSWORD` from
`/etc/breedbase-client.env`.

The first image pull is several GB and takes 10–20 minutes.

---

## 11a. Set RStudio user passwords

`deploy.sh` creates `breeder` and `analyst` accounts with no password. Set passwords
before handing access to users:

```bash
sudo passwd breeder
sudo passwd analyst
```

Choose strong passwords. These are used to log in to RStudio Server at
`https://$CLIENT_HOSTNAME/rstudio/`.

---

## 11b. Configure .Renviron for each RStudio user

Each user needs their Breedbase API token in their `.Renviron` file.

**Get the API token from Breedbase:**
1. Log in to `https://$CLIENT_HOSTNAME` as admin
2. Go to Admin → Manage Users → select the user's Breedbase account
3. Copy or generate their API token

**Set .Renviron for each user** (run as root):

```bash
sudo -u breeder tee /home/breeder/.Renviron > /dev/null <<EOF
BB_URL=https://${CLIENT_HOSTNAME}
BB_TOKEN=<paste token here>
EOF
sudo chmod 600 /home/breeder/.Renviron
```

Repeat for `analyst`.

**Verify it works** — log in to RStudio as the user and run:

```r
library(bbr)
con <- bb_connect()
con  # should print <bbr_con> with URL
```

---

## 11. Smoke test checklist

- [ ] `https://$CLIENT_HOSTNAME` loads the Breedbase homepage
- [ ] SSL certificate is valid (no browser warning)
- [ ] Login with the admin account created during `breedbase setup`
- [ ] Create a test germplasm entry and verify it saves
- [ ] Run backup manually and verify the blob appears in Azure Storage:

  ```bash
  set -a; source /etc/breedbase-client.env; set +a
  /usr/local/bin/breedbase-backup
  az storage blob list \
      --account-name $AZURE_STORAGE_ACCOUNT \
      --container-name $AZURE_CONTAINER \
      --auth-mode login --output table
  ```

- [ ] `./bin/breedbase status` shows all containers running
- [ ] `https://$CLIENT_HOSTNAME/rstudio/` opens the RStudio Server login page
- [ ] Login as `breeder` succeeds
- [ ] `library(bbr); bb_connect()` runs without error in RStudio
- [ ] `get_trials(bb_connect())` returns a data frame (may be empty if no data yet)

---

## Backup retention

Backups accumulate indefinitely. Set a lifecycle management policy on the Azure container
to delete blobs older than your retention target (e.g. 90 days):

```bash
az storage account management-policy create \
    --account-name $AZURE_STORAGE_ACCOUNT \
    --policy '{
      "rules": [{
        "name": "delete-old-backups",
        "enabled": true,
        "type": "Lifecycle",
        "definition": {
          "filters": {"blobTypes": ["blockBlob"], "prefixMatch": ["breedbase_"]},
          "actions": {"baseBlob": {"delete": {"daysAfterModificationGreaterThan": 90}}}
        }
      }]
    }'
```

---

## Maintenance

**Start/stop:**
```bash
cd /opt/breedbase
./bin/breedbase start
./bin/breedbase stop
```

**Update Breedbase:**

Review upstream commits, test on staging, then update the pinned SHA in `bootstrap.sh` and
check out the new SHA on the production VM before running the update helper:

```bash
cd /opt/breedbase
sudo git fetch origin
sudo git checkout <new-reviewed-sha>
./bin/breedbase update
```

**View logs:**
```bash
./bin/breedbase log hordeum
```

**Re-run configure.sh after template changes:**
```bash
set -a; source /etc/breedbase-client.env; set +a

bash /opt/tiller/deploy/scripts/configure.sh \
    /opt/tiller/deploy/breedbase/sgn_local.conf.template \
    /opt/breedbase/config/hordeum.conf

cd /opt/breedbase && ./bin/breedbase stop && ./bin/breedbase start
```

**Re-run DB patches after a Breedbase update:**
```bash
cd /opt/breedbase && ./bin/breedbase patch hordeum
```

**RStudio Server:**
```bash
sudo systemctl status rstudio-server
sudo systemctl restart rstudio-server
# Logs:
sudo journalctl -u rstudio-server -f
```

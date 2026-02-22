# Breedbase T3 Deployment Runbook

Step-by-step guide for standing up a new Breedbase instance on an Azure VM.
Run each step in order. Do not skip steps.

**Prerequisites:**
- Azure VM provisioned (B2ms, Ubuntu 22.04 LTS) — see `infra/` for Terraform
- DNS A record pointing `CLIENT_HOSTNAME` to the VM's public IP
- SSH access to the VM

---

## 1. Initial VM setup

```bash
# Update packages
sudo apt-get update && sudo apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
newgrp docker

# Install Docker Compose plugin
sudo apt-get install -y docker-compose-plugin

# Install nginx and certbot
sudo apt-get install -y nginx certbot python3-certbot-nginx

# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Verify managed identity is assigned (no interactive login needed if VM identity is configured)
az login --identity
```

---

## 2. Clone T3 Breedbase

TriticeaeToolbox/breedbase publishes no tags or releases — only a `master` branch. Pin
deployments to a reviewed commit SHA; do **not** clone the default branch, as it is a
mutable reference outside our control. Update the SHA only after reviewing upstream changes
and testing on a staging instance.

```bash
# Vetted 2025-07-30: "Update traits: Fix docker compose cp command"
BREEDBASE_SHA="0a4d34aa0fcab30ce6680b8baf960bf2c7ef5869"

cd /opt
sudo git clone https://github.com/TriticeaeToolbox/breedbase
cd breedbase
sudo git checkout "$BREEDBASE_SHA"
cd /opt
sudo chown -R $USER:$USER breedbase
```

---

## 3. Clone tiller (this repo)

```bash
cd /opt
git clone https://github.com/countercheck/tiller
```

---

## 4. Set client environment variables

Create `/etc/breedbase-client.env` (not committed to git — contains secrets):

```bash
sudo tee /etc/breedbase-client.env > /dev/null <<EOF
CLIENT_HOSTNAME=edmonton.ourplatform.ca
CLIENT_NAME=edmonton
DB_PASSWORD=$(openssl rand -base64 24)
CONTACT_EMAIL=admin@ourplatform.ca
AZURE_STORAGE_ACCOUNT=tillerbackups
AZURE_CONTAINER=edmonton-backups
EOF
sudo chmod 600 /etc/breedbase-client.env
```

Load variables into the current shell:

```bash
set -a; source /etc/breedbase-client.env; set +a
```

---

## 5. Configure nginx

```bash
# Write nginx config from template
# sudo does not inherit environment variables — source the env file inside the sudo shell
sudo bash -c 'set -a; source /etc/breedbase-client.env; set +a; \
    bash /opt/tiller/deploy/scripts/configure.sh \
    /opt/tiller/deploy/nginx/breedbase.conf.template \
    /etc/nginx/sites-available/breedbase'

# Enable the site, remove default
sudo ln -s /etc/nginx/sites-available/breedbase /etc/nginx/sites-enabled/breedbase
sudo rm -f /etc/nginx/sites-enabled/default
```

Do **not** start nginx yet — the config references SSL cert paths that don't exist until step 6.

---

## 6. Obtain SSL certificate and start nginx

Our nginx template already references the Let's Encrypt cert paths, so nginx can't start
until the cert exists. Use certbot's standalone mode (no nginx required) to obtain the cert
first, then start nginx.

```bash
# Stop nginx if it auto-started during apt install
sudo systemctl stop nginx 2>/dev/null || true

# Obtain certificate (standalone — binds port 80 directly)
sudo certbot certonly --standalone \
    -d $CLIENT_HOSTNAME \
    --non-interactive --agree-tos \
    -m $CONTACT_EMAIL

# Verify config then start nginx
sudo nginx -t
sudo systemctl start nginx
sudo systemctl enable nginx
```

---

## 7. Configure Breedbase (sgn_local.conf)

If you're in a new shell, re-source the env file first:

```bash
set -a; source /etc/breedbase-client.env; set +a
```

```bash
bash /opt/tiller/deploy/scripts/configure.sh \
    /opt/tiller/deploy/breedbase/sgn_local.conf.template \
    /opt/breedbase/config/hordeum.conf
```

---

## 8. Run Breedbase setup

```bash
cd /opt/breedbase

# First-time setup: pulls Docker images (several GB — takes 10-20 minutes)
./bin/breedbase setup
```

When prompted for the database password, use `$DB_PASSWORD` from step 4.
If you're in a new shell: `set -a; source /etc/breedbase-client.env; set +a`, then `echo $DB_PASSWORD`.

---

## 9. Start Breedbase

```bash
cd /opt/breedbase
./bin/breedbase start
```

The web container takes **3-5 minutes** to fully start — this is normal.

```bash
# Check status
./bin/breedbase status

# Check logs if needed
./bin/breedbase log hordeum
```

---

## 10. Install backup cron job

```bash
# Copy backup script to system path
sudo cp /opt/tiller/deploy/scripts/backup.sh /usr/local/bin/breedbase-backup
sudo chmod +x /usr/local/bin/breedbase-backup

# Install cron job (runs every Sunday at 02:00)
# Use 'bash -c' to source env vars — env $(xargs) would expose secrets in ps output
(crontab -l 2>/dev/null; echo "0 2 * * 0  bash -c 'set -a; source /etc/breedbase-client.env; set +a; exec /usr/local/bin/breedbase-backup' >> /var/log/breedbase-backup.log 2>&1") | crontab -
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

Review upstream commits, test on staging, then update the pinned SHA in this runbook and
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

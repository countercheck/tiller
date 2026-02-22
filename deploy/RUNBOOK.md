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

```bash
cd /opt
sudo git clone https://github.com/TriticeaeToolbox/breedbase
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
DB_PASSWORD=$(openssl rand -base64 24 | tr -d /+=)
PROGRAM_NAME=AB_Barley
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
sudo bash /opt/tiller/deploy/scripts/configure.sh \
    /opt/tiller/deploy/nginx/breedbase.conf.template \
    /etc/nginx/sites-available/breedbase

# Enable the site, remove default
sudo ln -s /etc/nginx/sites-available/breedbase /etc/nginx/sites-enabled/breedbase
sudo rm -f /etc/nginx/sites-enabled/default

# Start nginx (port 80 only until certbot adds the cert)
sudo systemctl start nginx
sudo systemctl enable nginx
```

---

## 6. Obtain SSL certificate

Certbot reads the nginx config, obtains the certificate, and installs the cert paths.
Our template already references `/etc/letsencrypt/live/$CLIENT_HOSTNAME/` — the same
paths certbot creates — so no further nginx edits are needed after this step.

```bash
sudo certbot --nginx -d $CLIENT_HOSTNAME --non-interactive --agree-tos -m $CONTACT_EMAIL
```

---

## 7. Configure Breedbase (sgn_local.conf)

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
# env is used to load variables because 'source' does not work in cron
(crontab -l 2>/dev/null; echo "0 2 * * 0  env \$(grep -v '^#' /etc/breedbase-client.env | xargs) /usr/local/bin/breedbase-backup >> /var/log/breedbase-backup.log 2>&1") | crontab -
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

## Maintenance

**Start/stop:**
```bash
cd /opt/breedbase
./bin/breedbase start
./bin/breedbase stop
```

**Update Breedbase:**
```bash
cd /opt/breedbase
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

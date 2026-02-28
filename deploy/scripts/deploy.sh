#!/usr/bin/env bash
# deploy/scripts/deploy.sh
# Configure and start Breedbase for a new client deployment.
#
# Prerequisites:
#   - bootstrap.sh has been run and repos are cloned
#   - DNS A record for CLIENT_HOSTNAME points to this VM
#   - /etc/breedbase-client.env exists (RUNBOOK.md step 4)
#   - Docker group is active (log out/in after bootstrap.sh)
#
# Usage:
#   bash /opt/tiller/deploy/scripts/deploy.sh
#
# The script pauses partway through to let you run `./bin/breedbase setup`
# manually (it has an interactive DB password prompt). Press Enter to continue.
set -euo pipefail

ENV_FILE="/etc/breedbase-client.env"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- 1. Load and validate client environment ----------------------------------

[[ -f "$ENV_FILE" ]] || {
    echo "Error: $ENV_FILE not found. Create it first (see RUNBOOK.md step 4)." >&2
    exit 1
}

set -a
source "$ENV_FILE"
set +a

: "${CLIENT_HOSTNAME:?CLIENT_HOSTNAME is required in $ENV_FILE}"
: "${CLIENT_NAME:?CLIENT_NAME is required in $ENV_FILE}"
: "${DB_PASSWORD:?DB_PASSWORD is required in $ENV_FILE}"
: "${CONTACT_EMAIL:?CONTACT_EMAIL is required in $ENV_FILE}"
: "${AZURE_STORAGE_ACCOUNT:?AZURE_STORAGE_ACCOUNT is required in $ENV_FILE}"
: "${AZURE_CONTAINER:?AZURE_CONTAINER is required in $ENV_FILE}"

echo "=== Deploying: $CLIENT_HOSTNAME ==="

# --- 1b. Create RStudio user accounts ----------------------------------------

echo "=== Creating RStudio user accounts ==="
for user in breeder analyst; do
    if ! id "$user" &>/dev/null; then
        sudo useradd --create-home --shell /bin/bash "$user"
        echo "  Created user: $user (set password manually: sudo passwd $user)"
    else
        echo "  User $user already exists — skipping"
    fi
done

# --- 2. Configure nginx -------------------------------------------------------

echo "=== Configuring nginx ==="
sudo bash -c "
    set -a; source $ENV_FILE; set +a
    bash $SCRIPT_DIR/configure.sh \
        /opt/tiller/deploy/nginx/breedbase.conf.template \
        /etc/nginx/sites-available/breedbase"

sudo ln -sf /etc/nginx/sites-available/breedbase /etc/nginx/sites-enabled/breedbase
sudo rm -f /etc/nginx/sites-enabled/default

# --- 3. Create SSL helper files -----------------------------------------------

echo "=== Creating SSL helper files ==="

if [ ! -f /etc/letsencrypt/options-ssl-nginx.conf ]; then
    sudo tee /etc/letsencrypt/options-ssl-nginx.conf > /dev/null << 'EOF'
ssl_session_cache shared:le_nginx_SSL:10m;
ssl_session_timeout 1440m;
ssl_session_tickets off;

ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers off;

ssl_ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256";
EOF
    echo "  Created /etc/letsencrypt/options-ssl-nginx.conf"
fi

if [ ! -f /etc/letsencrypt/ssl-dhparams.pem ]; then
    echo "  Generating DH parameters (~30 seconds)..."
    sudo openssl dhparam -out /etc/letsencrypt/ssl-dhparams.pem 2048
fi

# --- 4. Obtain SSL certificate ------------------------------------------------

echo "=== Obtaining SSL certificate for $CLIENT_HOSTNAME ==="

# Certbot standalone binds port 80 directly — nginx must be stopped first
sudo systemctl stop nginx 2>/dev/null || true

if [ ! -f "/etc/letsencrypt/live/$CLIENT_HOSTNAME/fullchain.pem" ]; then
    sudo certbot certonly --standalone \
        -d "$CLIENT_HOSTNAME" \
        --non-interactive --agree-tos \
        -m "$CONTACT_EMAIL"
else
    echo "  Certificate already exists — skipping"
fi

# --- 5. Start nginx -----------------------------------------------------------

echo "=== Starting nginx ==="
sudo nginx -t
sudo systemctl start nginx
sudo systemctl enable nginx
# Restart RStudio Server to pick up any rserver.conf changes
sudo systemctl restart rstudio-server 2>/dev/null || true

# --- 6. Configure Breedbase (hordeum.conf) ------------------------------------

echo "=== Configuring Breedbase ==="
"$SCRIPT_DIR/configure.sh" \
    /opt/tiller/deploy/breedbase/sgn_local.conf.template \
    /opt/breedbase/config/hordeum.conf

# --- 7. Manual: run breedbase setup -------------------------------------------

echo ""
echo "======================================================================"
echo "  MANUAL STEP: Run Breedbase setup."
echo ""
echo "  Open a second terminal and run:"
echo "    cd /opt/breedbase"
echo "    ./bin/breedbase setup"
echo ""
echo "  When prompted for the database password, enter the value of"
echo "  DB_PASSWORD from $ENV_FILE:"
echo "    $(grep '^DB_PASSWORD=' "$ENV_FILE" | cut -d= -f2-)"
echo "======================================================================"
echo ""
read -rp "Press Enter once breedbase setup has completed... "

# --- 8. Apply DB schema patches -----------------------------------------------

echo "=== Running DB schema patches ==="
cd /opt/breedbase
./bin/breedbase patch hordeum

# --- 9. Grant web_usr DB permissions ------------------------------------------

echo "=== Granting web_usr database permissions ==="

# Grant across all user-defined schemas (new tables created by patches need these)
for priv in \
    "GRANT USAGE ON SCHEMA" \
    "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA" \
    "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA"
do
    docker exec breedbase_db psql -U postgres -d cxgn_hordeum -t -c \
        "SELECT '$priv ' || schema_name || ' TO web_usr;'
         FROM information_schema.schemata
         WHERE schema_name NOT IN
             ('information_schema','pg_catalog','pg_toast','pg_temp_1','pg_toast_temp_1');" \
        | docker exec -i breedbase_db psql -U postgres -d cxgn_hordeum
done

# --- 10. Start Breedbase ------------------------------------------------------

echo "=== Starting Breedbase ==="
./bin/breedbase start

echo ""
echo "  The web container takes 3-5 minutes to fully start on first boot."
echo "  Monitor: ./bin/breedbase log hordeum"

# --- 11. Install backup cron job ----------------------------------------------

echo "=== Installing backup cron job ==="
sudo cp /opt/tiller/deploy/scripts/backup.sh /usr/local/bin/breedbase-backup
sudo chmod +x /usr/local/bin/breedbase-backup

if ! crontab -l 2>/dev/null | grep -q breedbase-backup; then
    (crontab -l 2>/dev/null
     echo "0 2 * * 0  bash -c 'set -a; source $ENV_FILE; set +a; exec /usr/local/bin/breedbase-backup' >> /var/log/breedbase-backup.log 2>&1"
    ) | crontab -
    echo "  Cron job installed (Sunday 02:00)"
else
    echo "  Cron job already installed — skipping"
fi

# --- 12. Install R analytical packages ---------------------------------------

echo "=== Installing R analytical packages ==="
# Install system-wide so both breeder and analyst accounts can use them
# without waiting for per-user compilation. These are the core packages
# for trial analysis and GBLUP.
sudo Rscript -e "
    pkgs <- c('lme4', 'emmeans', 'rrBLUP', 'sommer')
    to_install <- pkgs[!pkgs %in% installed.packages()[,'Package']]
    if (length(to_install) > 0) {
        install.packages(to_install,
                         repos = 'https://cloud.r-project.org',
                         quiet = TRUE)
        cat('Installed:', paste(to_install, collapse = ', '), '\n')
    } else {
        cat('All analytical packages already installed\n')
    }
"

# --- 13. Install bbr R package -----------------------------------------------

echo "=== Installing bbr R package ==="
sudo Rscript -e "
    if (!requireNamespace('remotes', quietly = TRUE)) {
        install.packages('remotes', repos = 'https://cloud.r-project.org', quiet = TRUE)
    }
    remotes::install_local('/opt/tiller/r-package',
                           dependencies = TRUE,
                           upgrade      = 'never',
                           quiet        = TRUE)
    cat('bbr installed successfully\n')
"

# --- Done ---------------------------------------------------------------------

echo ""
echo "======================================================================"
echo "  Deployment complete: $CLIENT_HOSTNAME"
echo ""
echo "  Smoke test checklist (RUNBOOK.md step 11):"
echo "    - https://$CLIENT_HOSTNAME  loads the Breedbase homepage"
echo "    - SSL certificate is valid"
echo "    - Login with the admin account created during breedbase setup"
echo "    - https://$CLIENT_HOSTNAME/rstudio/  opens RStudio Server login"
echo "    - Login with breeder or analyst (passwords set via: sudo passwd <user>)"
echo "======================================================================"

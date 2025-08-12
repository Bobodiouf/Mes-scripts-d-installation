#!/bin/bash
set -e

# Vérification droits root
if [ "$EUID" -ne 0 ]; then
    echo "⚠️ Ce script doit être exécuté par un utilisateur avec les droits root."
    exit 1
fi

echo "===== Installation Prometheus ====="
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v2.41.0/prometheus-2.41.0.linux-amd64.tar.gz
tar xzf prometheus-2.41.0.linux-amd64.tar.gz
mv prometheus-2.41.0.linux-amd64 /usr/share/prometheus

useradd --no-create-home --shell /bin/false prometheus || true
mkdir -p /var/lib/prometheus/data
chown -R prometheus:prometheus /usr/share/prometheus /var/lib/prometheus/data

# Fichier de config prometheus.yml minimal
cat > /usr/share/prometheus/prometheus.yml <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
EOF

chown prometheus:prometheus /usr/share/prometheus/prometheus.yml

# Service systemd Prometheus
cat > /etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/share/prometheus/prometheus \
  --config.file=/usr/share/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus/data

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus

echo "Prometheus installé sur le port 9090"

echo "===== Installation Grafana ====="
apt install -y gnupg2 curl software-properties-common dirmngr apt-transport-https lsb-release ca-certificates
mkdir -p /etc/apt/keyrings
curl -fsSL https://packages.grafana.com/gpg.key | gpg --dearmor -o /etc/apt/keyrings/grafana.gpg
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://packages.grafana.com/oss/deb stable main" > /etc/apt/sources.list.d/grafana.list
apt update
apt install -y grafana

systemctl enable grafana-server
systemctl start grafana-server

echo "Grafana installé sur le port 3000"

echo "===== Installation Node Exporter ====="
cd /tmp
NODE_EXPORTER_URL=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest \
    | grep browser_download_url \
    | grep linux-amd64 \
    | cut -d '"' -f 4)
wget "$NODE_EXPORTER_URL"
tar xvf node_exporter-*linux-amd64.tar.gz
cp node_exporter-*linux-amd64/node_exporter /usr/local/bin/

# Service systemd Node Exporter
cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=prometheus
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=default.target
EOF

systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

echo "Node Exporter installé sur le port 9100"

echo "===== Installation terminée ====="
echo "Prometheus : http://$(hostname -I | awk '{print $1}'):9090"
echo "Grafana : http://$(hostname -I | awk '{print $1}'):3000"
echo "Node Exporter : http://$(hostname -I | awk '{print $1}'):9100/metrics"

# 1. Clean up old rules to avoid conflicts
Remove-NetFirewallRule -DisplayName "Swarm *" -ErrorAction SilentlyContinue

# 2. Cluster Management (TCP 2377)
# Required for nodes to talk to the Manager.
New-NetFirewallRule -DisplayName "Swarm Manager" -Direction Inbound -Protocol TCP -LocalPort 2377 -Action Allow -Profile Any

# 3. Node Communication (TCP/UDP 7946)
# Required for service discovery (finding where containers are).
New-NetFirewallRule -DisplayName "Swarm Discovery TCP" -Direction Inbound -Protocol TCP -LocalPort 7946 -Action Allow -Profile Any
New-NetFirewallRule -DisplayName "Swarm Discovery UDP" -Direction Inbound -Protocol UDP -LocalPort 7946 -Action Allow -Profile Any

# 4. Overlay Network (UDP 4789) - CRITICAL
# This is the "Data Tunnel". If this is blocked, containers can't ping each other.
New-NetFirewallRule -DisplayName "Swarm Overlay" -Direction Inbound -Protocol UDP -LocalPort 4789 -Action Allow -Profile Any

# 5. Application Ports (HTTP 80)
# Required for HAProxy to accept Moodle traffic.
New-NetFirewallRule -DisplayName "CodeRunner HTTP" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow -Profile Any

Write-Host "Firewall rules updated. Restarting Docker..." -ForegroundColor Green
Restart-Service docker

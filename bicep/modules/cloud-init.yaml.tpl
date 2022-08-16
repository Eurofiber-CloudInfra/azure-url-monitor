#cloud-config

package_upgrade: true

packages:
  - docker.io
  - docker-compose

write_files:
- path: /etc/docker/docker-compose.json
  permissions: '0644'
  owner: root:root
  content: | 
    {0}
- path: /etc/systemd/system/docker-compose.service
  permissions: '0644'
  owner: root:root
  content: |
    [Unit]
    Description=Docker Compose container starter
    Requires=docker.service
    After=docker.service
    
    [Service]
    Type=simple
    WorkingDirectory=/etc/docker
    ExecStartPre=/usr/bin/docker-compose -f docker-compose.json down --rmi all
    ExecStart=/usr/bin/docker-compose -f docker-compose.json up -d
    ExecStop=/usr/bin/docker-compose -f docker-compose.json down --rmi all
    RemainAfterExit=yes
    RestartSec=10

    [Install]
    WantedBy=multi-user.target

runcmd:
  - [ systemctl, daemon-reload]
  - [ systemctl, enable, docker-compose.service]
  - [ systemctl, start, docker-compose.service]
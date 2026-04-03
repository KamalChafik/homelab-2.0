#cloud-config
users:
  - name: kamal
    groups: [sudo]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
%{ for key in kamal_ssh_keys ~}
      - ${key}
%{ endfor ~}

  - name: ansible
    groups: [sudo]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ${ansible_ssh_key}

disable_root: true
ssh_pwauth: false
package_update: true

packages:
  - qemu-guest-agent

runcmd:
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
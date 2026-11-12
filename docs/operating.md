# Running vuls

## Removing it

Removing the class leaves everything in place. To remove it by hand:

```sh
sudo systemctl disable --now vuls-scan.timer
sudo rm -rf /etc/vuls /var/lib/vuls /opt/vuls /usr/local/bin/vuls /usr/local/sbin/vuls-windows-collect /usr/local/sbin/vuls-mark-complete
sudo rm -f /etc/systemd/system/vuls-scan.timer /etc/systemd/system/vuls-scan.service
sudo userdel vuls
```

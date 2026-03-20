# LXC to Incus Migration Script

```bash
#!/bin/bash
# Export all LXC containers and transfer to destination

containers="pragmatismo-alm pragmatismo-alm-ci pragmatismo-dns pragmatismo-drive pragmatismo-email pragmatismo-proxy pragmatismo-system pragmatismo-table-editor pragmatismo-tables pragmatismo-webmail"

for name in $containers; do
  echo "=== Migrating $name ==="
  ssh root@pragmatismo.com.br "lxc export $name /tmp/$name.tar.gz"
  scp root@pragmatismo.com.br:/tmp/$name.tar.gz administrator@63.141.255.9:~/
  ssh root@pragmatismo.com.br "rm /tmp/$name.tar.gz"
  echo "✓ $name transferred"
done

echo "Migration complete. All .tar.gz files in ~/ on destination."
```

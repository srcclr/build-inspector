set -e

mkdir /evidence
if grep 'vagrant' /etc/passwd
  then
    chown vagrant:vagrant /evidence
fi
echo 'all set, rock on!'

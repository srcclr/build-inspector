set -e

mkdir /evidence
if grep 'vagrant' /etc/passwd
  then
    chown vagrant:vagrant /evidence
fi

echo 'All set, rock on!'

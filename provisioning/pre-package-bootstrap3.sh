set -e

mkdir -p /evidence
if grep 'vagrant' /etc/passwd
then
    chown vagrant:vagrant /evidence
    user_home=/home/vagrant
else
    user_home=$HOME
fi

# Generate a snapshot now so it's easier to snapshot before an inspection
mkdir -p /backup
rdiff-backup --include-filelist $user_home/filesystem-snapshot.txt / /backup
chown -R vagrant:vagrant /backup

echo 'All set, rock on!'

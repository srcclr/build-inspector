if grep 'vagrant' /etc/passwd
then
    user_home=/home/vagrant
else
    user_home=$HOME
fi

mv $user_home/sources.list /etc/apt/sources.list
mv $user_home/sshd /etc/pam.d/sshd

#echo GEM_HOME="$user_home/.gem" >> /etc/environment
#echo PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games" >> /etc/environment

echo "Stopping Puppet and Chef"
service puppet stop
service chef-client stop

echo "Adding chis-lea's node.js repository"
add-apt-repository -y ppa:chris-lea/node.js

# For gradle 2.x
sudo add-apt-repository ppa:cwchien/gradle

echo "Updating apt package list"
apt-get update

echo "Installing dependencies"
apt-get install -y build-essential git-core zlib1g-dev libssl-dev \
  libreadline-dev libyaml-dev subversion maven2 gradle-2.7 nodejs rdiff-backup \
  zip libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev \
  libcurl4-openssl-dev libffi-dev openjdk-7-jdk

echo "Installing Snoopy"
wget -O snoopy-install.sh https://github.com/a2o/snoopy/raw/install/doc/install/bin/snoopy-install.sh
chmod +x snoopy-install.sh
./snoopy-install.sh stable
echo 'output = file:/var/log/snoopy.log' >> /etc/snoopy.ini
rm -rf snoopy-*

# Log file must be fairly writable or you'll only get root processes
touch /var/log/snoopy.log
chmod 0666 /var/log/snoopy.log

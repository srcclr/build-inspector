set -e
mv ~/sources.list /etc/apt/sources.list
mv ~/sshd /etc/pam.d/sshd

echo 'GEM_HOME="/home/vagrant/.gem"' >> /etc/environment
echo 'PATH="$HOME/.gem/ruby/2.2.0/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games"' >> /etc/enviroment

echo "Stopping puppet and chef"
service puppet stop
service chef-client stop

echo "Adding brightbox's ruby repository"
apt-add-repository ppa:brightbox/ruby-ng

echo "Adding chis-lea's node js repository"
add-apt-repository ppa:chris-lea/node.js

echo "Updating apt"
apt-get update

echo "Installing dependencies"
apt-get install -y build-essential git-core zlib1g-dev libssl-dev \
  libreadline-dev libyaml-dev subversion maven2 gradle nodejs rdiff-backup \
  zip ruby2.2 ruby2.2-dev ruby-switch libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev \
  libcurl4-openssl-dev libffi-dev openjdk-7-jdk

echo "Switching to ruby2.2"
ruby-switch --set ruby2.2

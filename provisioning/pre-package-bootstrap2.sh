set -e
# This runs as vagrant user, not root!

echo "tmp = $HOME/.npm" >> ~/.npmrc

echo -e "Host github.com\n\tStrictHostKeyChecking no\n" >> ~/.ssh/config

# Need to import this public key for RVM
gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3

# Sometimes the gpg command fails. Try it another way.
curl -#LO https://rvm.io/mpapis.asc && gpg --import mpapis.asc && rm mpapis.asc

curl -sSL https://get.rvm.io | bash -s $1
echo rvm_install_on_use_flag=1 >> /home/vagrant/.rvmrc
source $HOME/.rvm/scripts/rvm
rvm --install --default use 2.2.3
gem install bundler

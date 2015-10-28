set -e
# This runs as vagrant user, not root!

# Maybe some builds need bower
#npm install -g bower

echo "gem: --user-install --no-ri --no-rdoc" >> ~/.gemrc
echo "tmp = $HOME/.npm" >> ~/.npmrc
gem install bundler
gem install celluloid
gem install sys-proctable --platform linux

echo -e "Host github.com\n\tStrictHostKeyChecking no\n" >> ~/.ssh/config

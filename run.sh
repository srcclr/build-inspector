#!/bin/bash

set -ex

while true
do
  vagrant halt && vagrant up
  bundle exec ruby receive.rb
done
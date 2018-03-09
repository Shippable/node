#!/bin/bash -e

readonly SRC_DIR=$(dirname "$0")

if ! [ -x "$(command -v jq)" ]; then
  echo "Installing jq"
  apt-get install -y jq=1.5*
fi

echo "Installing shippable_decrypt"
cp $SRC_DIR/shippable_decrypt /usr/local/bin/shippable_decrypt

echo "Installing shippable_retry"
cp $SRC_DIR/shippable_retry /usr/local/bin/shippable_retry

echo "Installing shippable_replace"
cp $SRC_DIR/shippable_replace /usr/local/bin/shippable_replace

echo "Installing shippable_jdk"
cp $SRC_DIR/shippable_jdk /usr/local/bin/shippable_jdk

echo "Installing shipctl"
cp $SRC_DIR/shipctl /usr/local/bin/shipctl

echo "Installing utility"
cp $SRC_DIR/utility.sh /usr/local/bin/utility.sh

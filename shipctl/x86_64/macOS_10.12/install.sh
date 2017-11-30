#!/bin/bash -e

readonly SRC_DIR=$(dirname "$0")

echo "Installing shippable_decrypt"
sudo cp $SRC_DIR/shippable_decrypt /usr/local/bin/shippable_decrypt

echo "Installing shippable_retry"
sudo cp $SRC_DIR/shippable_retry /usr/local/bin/shippable_retry

echo "Installing shippable_replace"
sudo cp $SRC_DIR/shippable_replace /usr/local/bin/shippable_replace

echo "Installing shippable_jdk"
sudo cp $SRC_DIR/shippable_jdk /usr/local/bin/shippable_jdk

echo "Installing shipctl"
sudo cp $SRC_DIR/shipctl /usr/local/bin/shipctl

echo "Installing utility"
sudo cp $SRC_DIR/utility.sh /usr/local/bin/utility.sh

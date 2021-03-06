#!/bin/sh

# sudo apt-get update && sudo apt-get -y install git && git clone https://github.com/masatoshiitoh/easymmo.git && cd easymmo && sh devsetup.sh

EMMO_DEST=`pwd`

ERL_DEST=$HOME/otp_R16B03-1
REBAR_DEST=$HOME/rebar


## Install Erlang/OTP
cd $HOME
sudo apt-get update
sudo apt-get -y install apt-transport-https
sudo apt-get -y install wget make
sudo apt-get -y install libc6-dev gcc g++ zlib1g-dev
sudo apt-get -y install build-essential libncurses5-dev libssl-dev
wget http://download.basho.co.jp.cs-ap-e2.ycloud.jp/otp/download/otp_src_R16B03-1.tar.gz
tar xvf otp_src_R16B03-1.tar.gz
cd otp_src_R16B03-1
./configure -prefix=$ERL_DEST
make
sudo make install
echo "PATH=$ERL_DEST/bin:\$PATH" >> $HOME/.profile
PATH=$ERL_DEST/bin:$PATH


## Install RabbitMQ server
sudo apt-get -y install rabbitmq-server

## Install Riak
curl https://packagecloud.io/gpg.key | sudo apt-key add -
sudo apt-get -y install apt-transport-https
echo "# this file was generated by packagecloud.io for" > ./basho.list.fasd8f98wfksadf
echo "# the repository at https://packagecloud.io/basho/riak" >> ./basho.list.fasd8f98wfksadf
echo "deb https://packagecloud.io/basho/riak/ubuntu/ precise main" >> ./basho.list.fasd8f98wfksadf
echo "deb-src https://packagecloud.io/basho/riak/ubuntu/ precise main" >> ./basho.list.fasd8f98wfksadf
sudo mv ./basho.list.fasd8f98wfksadf /etc/apt/sources.list.d/basho.list
sudo apt-get update
sudo apt-get -y --force-yes install riak

## Install rebar
cd $HOME
sudo apt-get -y install make git
git clone https://github.com/rebar/rebar.git
cd rebar
make
cp rebar $EMMO_DEST

## Build easymmo
cd $EMMO_DEST
sudo apt-get -y install make
make release

## End of installation
echo "Please start riak."
echo "(you can reboot this system to start riak)."


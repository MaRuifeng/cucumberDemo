#!/bin/bash

# Get arguments as environment variables
export APP_BUILD=$1
export TEST_PHASE=$2

## Start the ssh service
/usr/sbin/sshd

## Clear the src folder
cd /src
rm -rf *

## Start the Xvfb virtual display service
cd 
# create an Xvfb virtual display in the background (another screen size: 1080x1440x24)
Xvfb :99 -ac -screen 0 1680x1080x24 &  
sleep 5 # wait for Xvfb display server session to be ready  
export DISPLAY=:99

## Start a vnc session to the virtual display created above
x11vnc -forever -usepw -display :99 &
# -geometry 1680x1080

# Grant file permission
chown -R cobalt /home/cobalt/

## Run cucumber, report handler, and convert nginx conf file
su cobalt <<'EOF'
cd
source /home/cobalt/.rvm/scripts/rvm
echo $(ruby -v)

mkdir $APP_BUILD
mkdir $APP_BUILD/$TEST_PHASE
mkdir $APP_BUILD/$TEST_PHASE/cucumber-result
mkdir $APP_BUILD/$TEST_PHASE/cucumber-result/logs
mkdir $APP_BUILD/$TEST_PHASE/cucumber-result/screenshots
mkdir $APP_BUILD/$TEST_PHASE/cucumber-result/cuke-report
mkdir $APP_BUILD/$TEST_PHASE/cucumber-result/junit

cd /home/cobalt/cucumber
echo "Xvfb display number:"
echo $DISPLAY
echo "Installing/updating gems in case of changes..."
bundle install
echo "Running cucumber..."
# bundle exec parallel_cucumber features/ -o "-p html_each"
cucumber -p html_each features/
ruby results_XML_handler.rb
erb /home/cobalt/cucumber/cucumber_nginx.conf.erb > /home/cobalt/cucumber/cucumber_nginx.conf
EOF

## Copy cucumber html results to the default Nginx content folder
# cp /home/cobalt/cucumber/results.html /usr/share/nginx/html
# cp -rf /home/cobalt/cucumber_results /usr/share/nginx/html

## Start Nginx server
# using global directive 'daemon off' to 
# ensure the docker container does not halt after Nginx spawns its processes
echo "Starting Nginx server with customized configuration..."
/usr/sbin/nginx -g 'daemon off;' -c /home/cobalt/cucumber/cucumber_nginx.conf

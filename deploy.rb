#############################################################
# Application
#############################################################

set :application, "APPNAME"
set :deploy_to, "/home/deploy/#{application}"

#############################################################
# Settings
#############################################################

default_run_options[:pty] = true
ssh_options[:forward_agent] = true
set :use_sudo, true
set :scm_verbose, true

#############################################################
# Servers
#############################################################

set :user, "USERNAME"
# set :user_passphrase, "PASSWORD"
set :domain, "DOMAIN"
server domain, :app, :web
role :db, domain, :primary => true

#############################################################
# Git
#############################################################

set :scm, :git
set :branch, "master"
set :scm_user, "GITUSERNAME"
# set :scm_passphrase, "GITPASSWORD"
set :repository, "REPO"
set :deploy_via, :remote_cache

#############################################################
# Server Setup
#############################################################

namespace :server_setup do
  desc "Setup Environment"
  task :setup_env do
    update_apt_get
    install_dev_tools
    install_git
    install_sqlite3
    install_sphinx
    install_prince
    install_rails_stack
    install_apache
    install_passenger
    config_passenger
    config_vhost
  end

  desc "Update apt-get sources"
  task :update_apt_get do
    sudo "apt-get update"
  end

  desc "Install Development Tools"
  task :install_dev_tools do
    sudo "apt-get install build-essential -y"
  end

  desc "Install Git"
  task :install_git do
    sudo "apt-get install git-core git-svn -y"
  end

  desc "Install Subversion"
  task :install_subversion do
    sudo "apt-get install subversion -y"
  end

  desc "Install MySQL"
  task :install_mysql do
    sudo "apt-get install mysql-server libmysql-ruby -y"
  end

  # desc "Install PostgreSQL"
  # task :install_postgres do
  #   sudo "apt-get install postgresql libpgsql-ruby -y"
  # end

  desc "Install SQLite3"
  task :install_sqlite3 do
    sudo "apt-get install sqlite3 libsqlite3-ruby -y"
  end
  
  task :install_sphinx do
    run  "cd ~/src"
    run  "wget http://www.sphinxsearch.com/downloads/sphinx-0.9.9.tar.gz"
    run  "tar xzvf sphinx-0.9.9.tar.gz"
    run  "cd sphinx-0.9.9"
    run  "./configure"
    run  "make"
    sudo "make install"
  end
  
  task :install_prince do
    run  "cd ~/src"
    run  "wget http://www.princexml.com/download/prince-7.0-ubuntu904-static.tar.gz"
    run  "tar xzvf prince-7.0-ubuntu904-static.tar.gz"
    run  "sudo ./install.sh\n"
    # need to press enter to set default directory
  end

  desc "Install Ruby, Gems, and Rails"
  task :install_rails_stack do
    [ "sudo apt-get install ruby ruby1.8-dev irb ri rdoc libopenssl-ruby1.8 -y",
      "mkdir -p src",
      "cd src",
      "wget http://rubyforge.org/frs/download.php/60718/rubygems-1.3.5.tgz",
      "tar xzvf rubygems-1.3.5.tgz",
      "cd rubygems-1.3.5/ && sudo ruby setup.rb",
      "sudo ln -s /usr/bin/gem1.8 /usr/bin/gem",
      "sudo gem update --system",
      "sudo gem install rails --no-ri --no-rdoc"
    ].each {|cmd| run cmd}
  end

  desc "Install MySQL Rails Bindings"
  task :install_mysql_bindings do
    sudo "aptitude install libmysql-ruby1.8"
  end

  desc "Install ImageMagick"
  task :install_imagemagick do
    sudo "apt-get install libxml2-dev libmagick9-dev imagemagick"
    sudo "gem install rmagick"
  end

  desc "Install Apache"
  task :install_apache do
    sudo "apt-get install apache2 apache2.2-common apache2-mpm-prefork
          apache2-utils libexpat1 apache2-prefork-dev libapr1-dev -y"
    sudo "chown :sudo /var/www"
    sudo "chmod g+w /var/www"
  end

  desc "Install Passenger"
  task :install_passenger do
    run "sudo gem install passenger --no-ri --no-rdoc"
    input = ''
    run "sudo passenger-install-apache2-module" do |ch,stream,out|
      next if out.chomp == input.chomp || out.chomp == ''
      print out
      ch.send_data(input = $stdin.gets) if out =~ /(Enter|ENTER)/
    end
  end

  desc "Configure Passenger"
  task :config_passenger do
    
    passenger_version = `gem search passenger`.scan(/(?:\(|, *)([^,)]*)/).flatten.first    
    
    passenger_config =<<-EOF
LoadModule passenger_module /usr/lib/ruby/gems/1.8/gems/passenger-#{passenger_version}/ext/apache2/mod_passenger.so
PassengerRoot /usr/lib/ruby/gems/1.8/gems/passenger-#{passenger_version}
PassengerRuby /usr/bin/ruby1.8    
    EOF
    put passenger_config, "src/passenger"
    sudo "mv src/passenger /etc/apache2/conf.d/passenger"
  end

  desc "Configure VHost"
  task :config_vhost do
    vhost_config =<<-EOF
    <VirtualHost *:80>
      ServerName YOURSITEADDRESS
      DocumentRoot #{deploy_to}/current/public
    </VirtualHost>
    EOF
    put vhost_config, "src/vhost_config"
    sudo "mv src/vhost_config /etc/apache2/sites-available/#{application}"
    sudo "a2ensite #{application}"
    sudo "sudo a2enmod rewrite"
  end

  desc "Reload Apache"
  task :apache_reload do
    sudo "/etc/init.d/apache2 reload"
  end
end

#############################################################
# Deploy for Passenger
#############################################################

namespace :deploy do

  desc "Restarting mod_rails with restart.txt"
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "touch #{current_path}/tmp/restart.txt"
  end

  [:start, :stop].each do |task|
    desc "#{task} task is a no-op with mod_rails"
    task t, :roles => :app do ; end
  end
end

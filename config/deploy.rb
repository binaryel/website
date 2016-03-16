require 'mina/bundler'
require 'mina/rails'
require 'mina/git'
require 'mina/rvm' # for rvm support. (http://rvm.io)
# require 'mina_sidekiq/tasks'


server = 'ec2-52-37-228-0.us-west-2.compute.amazonaws.com'
env = 'development'

user = %x(git config user.name).delete("\n")

branch = (ENV['branch'].nil? ? %x(git symbolic-ref --short -q HEAD).delete("\n") : ENV['branch'])
branch = "master" if branch == ""

puts "Please select the server."
puts "1. development"
puts "2. staging"
puts "3. production"

STDOUT.flush
input = STDIN.gets.chomp
case input.upcase
  when "1"
    server = 'ec2-52-37-228-0.us-west-2.compute.amazonaws.com' # this is development instance
    server_uri = 'ec2-52-37-228-0.us-west-2.compute.amazonaws.com'
    env = 'development' # the dev server is in test env
  when "2"
    server = 'ec2-52-37-228-0.us-west-2.compute.amazonaws.com'
    server_uri = 'ec2-52-37-228-0.us-west-2.compute.amazonaws.com'
    env = 'staging'  # the dev server is in test env
  when "3"
    server = 'ec2-52-37-228-0.us-west-2.compute.amazonaws.com' # this is staging instance
    server_uri = 'ec2-52-37-228-0.us-west-2.compute.amazonaws.com'
    env = 'production'
    branch = "master" # Only master to be deployed on staging.
  else
    abort("Please select a valid server and try again.")
end


# print "Skip asset pre-compilation.. skipping not recommended (y/n): "
# input = STDIN.gets.chomp.downcase
# skip_migration = (input == 'y')
#
# puts "Skipping Asset precompilation... " if skip_migration

set :domain, server
set :deploy_to, '/var/app/binaryEl'
set :repository, 'git@github.com:binaryel/website.git'
set :branch, branch
set :rails_env, env

# For system-wide RVM install.
#   set :rvm_path, '/usr/local/rvm/bin/rvm'

# Manually create these paths in shared/ (eg: shared/config/database.yml) in your server.
# They will be linked in the 'deploy:link_shared_paths' step.
set :shared_paths, ['config/database.yml', 'log']

# Optional settings:
set :user, 'ubuntu' # Username in the server to SSH to.
set :port, '22' # SSH port number.
set :forward_agent, true # SSH forward_agent.

# This task is the environment that is loaded for most commands, such as
# `mina deploy` or `mina rake`.
task :environment do
  # If you're using rbenv, use this to load the rbenv environment.
  # Be sure to commit your .ruby-version or .rbenv-version to your repository.
  # invoke :'rbenv:load'

  # For those using RVM, use this to load an RVM version@gemset.
  invoke :'rvm:use[ruby-2.2.0@binaryEl]'
end

# Put any custom mkdir's in here for when `mina setup` is ran.
# For Rails apps, we'll make some of the shared paths that are shared between
# all releases.
task :setup => :environment do
  # sidekiq needs a place to store its pid file and log file
  queue! %[mkdir -p "#{deploy_to}/#{shared_path}/pids"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/#{shared_path}/pids"]

  queue! %[mkdir -p "#{deploy_to}/#{shared_path}/log"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/#{shared_path}/log"]

  queue! %[mkdir -p "#{deploy_to}/#{shared_path}/config"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/#{shared_path}/config"]

  queue! %[touch "#{deploy_to}/#{shared_path}/config/database.yml"]
  queue %[echo "-----> Be sure to edit '#{deploy_to}/#{shared_path}/config/database.yml'."]
end

desc "Deploys the current version to the server."
task :deploy => :environment do
  deploy do
    # Put things that will set up an empty directory into a fully set-up
    # invoke :'sidekiq:quiet'
    # instance of your project.
    invoke :'git:clone'
    invoke :'deploy:link_shared_paths'
    invoke :'bundle:install'
    invoke :'rails:db_migrate'
    invoke :'rails:assets_precompile' #unless skip_migration
    invoke :'deploy:cleanup'

    to :launch do
      queue "mkdir -p #{deploy_to}/#{current_path}/tmp/"
      queue "touch #{deploy_to}/#{current_path}/tmp/restart.txt"
      # invoke :'sidekiq:restart'
    end
  end
end

# For help in making your deploy script, see the Mina documentation:
#
#  - http://nadarei.co/mina
#  - http://nadarei.co/mina/tasks
#  - http://nadarei.co/mina/settings
#  - http://nadarei.co/mina/helpers


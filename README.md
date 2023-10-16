# Readme document for Part Two: Scripting and Automating

## This github repo contains 

README.md:

This Readme file contains all the details of the decisions I made as well as the how to install Ansible to set the environment up for Part two a), where to put the others files included in the Github Repository to show how you can simultaneously ssh into 20 servers and what Ansible command achieves this.

This file also contains the initial setup for Part two b)  that sets up a PostgreSQL 15 environment and all the steps considered to perform a PostgreSQL upgrade to version 16 and document other steps that might be needed if the system was more complex.

Finally this Readme file discusses Part two c), about the two ways to kill a long running web user session that has been running for over 1 minute, I will also cover what I setup and how I tested this works.

hosts:

This file contains the Ansible inventory of the servers we are going to simultaneously ssh into for Part 2) a) 

upgrade_postgres.sh: 

This is the script that will be used to perform the PostgreSQL upgrade from version 15 to version 16. It will stop both clusters, ensure that all configs are in places pg_upgrade expects, perform a dry run of the pg_upgrade, then do the actual pg_upgrade, start upgraded cluster, gather statistics, check can login and that database looks ok. 

cancel_web_sessions_over1minute.sql:

This Sql script will look for any sessions on a PostgreSQL cluster that have been running for over 1 minute using the database user web. This script will attempt to cancel any such sessions in a nice way. 

kill_web_sessions_over1minute.sql:

This Sql script will look for any sessions on a postgreSQL cluster that have been running for over 1 minute using the database user web. This script will brutally kill any such sessions but should only be used if the above cancel script does not work. 


### Detail of Part 2 a) Simultaneously open SSH connections to 20 VM’s with the following IP range 192.168.100-120.

Disclaimer: Now maybe I read the question wrong but ip address's are made up of 4 parts and the question has an ip address of 192.168.100 to 120 supposedly so technically that is 21 servers. I have answered the question accordingly but it obviously wont work and if you want me to update the answer i can and will if asked.

While I am no expert on using Ansible, I used to use an Ansible based deployment tool at EnterpriseDB called Trusted Postgres Architect and was going to use that as it is now open sourced but you still a basic a basic community 360 account that costs money. So I tried using basic Ansible instead.

### Assumptions for this part
I created a Debian based development environment on my wife's Chromebook, installed Ansible on that and created a Debian 11 vm in Microsoft Azure. I will provide all the steps to setup Ansible in Debian (10 and 11, i used 11) 

First need to install Ansible on Debian and I used this guide to install Ansible.

https://docs.ansible.com/ansible/latest/installation_guide/installation_distros.html#installing-ansible-on-debian

#### Step 1) Add Repository for Ansible 

Run the following add the repository for Ansible 

```sh
sudo su - 
vi /etc/apt/sources.list

``` 

If using debian 10, 
add line: 
deb http://ppa.launchpad.net/ansible/ansible/ubuntu bionic main 

otherwise using debian 11, 
add line: 
deb http://ppa.launchpad.net/ansible/ansible/ubuntu focal main 

to the above open file in vi then save it by pressing the escape key and :wq! to save the changes

#### Step 2) add key, update server index files and then install Ansible

Now run the following commands and  type  y when if ask if you want to install yes or no and press enter to continue.

```sh
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367
sudo apt update
sudo apt install ansible

``` 
Now Ansible should be installed.

#### Step 3) copy the hosts file from the git repository, set permissions on file and check it installed correctly

Next take the hosts file located in the github repository for this question, first copy to your server where you are going to test it and copy it into this location using the commands like this

```sh
sudo su - 
cp /uploaded_location/hosts /etc/ansible/hosts
cd /etc/ansible/
chown root:root hosts
``` 

Now to check that the hosts file is installed correctly run the following command as not root user

```sh
ansible-inventory --list -y
``` 

#### Step 4) setup ssh connectivity to the 20 hosts

Now to be able to connect to this list of servers, the ssh key information could be put into the ansible.cfg file using private_key_file= but its best in this case to add the ssh key using this method, go to your hidden .ssh directory and add private key to the ssh-agent using the following commands and check its added. 

```sh
cd .ssh
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/nameofprivatekey
ssh-add -l
``` 

This does assume the ssh public keys to the other 20 servers has already been using 

```sh
ssh-copy-id -i ~/.ssh/nameofpublickey user@host (possibly debian) 
ssh-keyscan -H host
``` 

#### Step 5) check that Ansible can ssh to each server and check get facts about each server

Now finally that Ansible is installed, that the Ansible hosts file is in place and tested working, and the ssh private key has been added to ssh-agent and that the public key is all the other servers then to check that you can ssh to them via Ansible and run a simple command use the following command

```sh
ansible all -m ping -u user (possibly debian) 
ansible all -m ansible.builtin.setup -u user (possibly debian) 
``` 

The first command did a ping test and the second command should return a load of information about each server. That should prove this part works.


### Detail of Part 2 b) Upgrade Postgres Server (Debian)

I will provide all the steps that are needed to perform a basic PostgreSQL upgrade, depending on what is installed in your Postgres cluster there maybe some extra steps which i will document but not run.

## Assumptions for this part
What I am going do is provide all the steps to build out a Postgres 15 cluster and then upgrade it to Postgres 16 which was released in September. I will test the approach on both my Debian Chromebook environment and my Debian 11 Azure based vm to check for issues.

#### Step 0a) To setup a Debian server with PostgreSQL 15:

Following the guide in https://www.postgresql.org/download/linux/debian/

```sh
sudo sh -c 'echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get -y install postgresql-15

``` 

This installed PostgreSQL cluster into Data_Directory = /var/lib/postgresql/15/main/ and the config files located = /etc/postgresql/15/main/

#### Step 0b) Now install PostgreSQL 16:

Run the following command to install PostgreSQL 16 into a new data directory

```sh
sudo apt-get -y install  postgresql-16

``` 
This installed a new postgreSQL cluster into Data_Directory = /var/lib/postgresql/16/main/ and the config files located = /etc/postgresql/16/main/ and initdb was run as well.
Now we have both a source PostgreSQL 15 cluster and a Target PostgreSQL 16 cluster we can start the upgrade process.

#### Step 1) Install extension shared object files and Copy custom full-text search files (optional)

If this was a production PostgreSQL cluster that had extra features installed or have full-text search in use, should ensure new cluster has those features installed and copied any full-text search files over.

#### Step 2) Stop both source and target PostgreSQL clusters

Run the following commands to stop both PostgreSQL Clusters before we start the upgrade process as postgres user

```sh
sudo su - postgres
/usr/lib/postgresql/15/bin/pg_ctl -D /var/lib/postgresql/15/main stop
/usr/lib/postgresql/16/bin/pg_ctl -D /var/lib/postgresql/16/main stop

``` 

#### Step 3) Prepare for standby server upgrades (optional)

If this was a production server that was in a psr (physical streaming replication) setup then we would have to consider the standby servers. 
Use the following command to check the status of the replication as postgres user against the old primary and old standby's

```sh
sudo su - postgres
/usr/lib/postgresql/15/bin/pg_controldata -D /var/lib/postgresql/15/main |grep 'Latest checkpoint location'

```
and only stop the standby's once they have caught up to the old primary. At this point supposedly need to ensure new primary does not have wal_level=minimal.
What I say here is copy all relevant settings across anyway such settings in pg_hba.conf and postgresql.conf that are key to the system running smoothly.

#### Step 4) Run pg_upgrade in Dry Run mode

Because the config files are located in /etc/postgresql/15/main/ for source database and  /etc/postgresql/16/main/ for the target database I had to do some pre-work to make the pg_upgrade function correctly.

For the source database I copied the *.conf files into the Data Directory and edited the postgresql.conf file to set the port = 5433 on source cluster

```sh
sudo su - postgres
cd /etc/postgresql/15/main/
cp *.conf /var/lib/postgresql/15/main/
mkdir /var/lib/postgresql/15/main/conf.d
cd /var/lib/postgresql/15/main/
vi postgresql.conf

```

Similarly for the target database I copied the *.conf files into the Data Directory and edited the postgresql.conf file to set the port = 5432 on target cluster

```sh
sudo su - postgres
cd /etc/postgresql/16/main/
cp *.conf /var/lib/postgresql/16/main/
mkdir /var/lib/postgresql/16/main/conf.d
cd /var/lib/postgresql/16/main/
vi postgresql.conf
  
```

To perform the dry run of pg_upgrade run the following command,

```sh
sudo su - postgres
/usr/lib/postgresql/16/bin/pg_upgrade -b /usr/lib/postgresql/15/bin -B /usr/lib/postgresql/16/bin \
                                      -d /var/lib/postgresql/15/main -D /var/lib/postgresql/16/main \
                                      --check --link --verbose -p 5433 -P 5432
```

Assuming the dry run completes with `*Clusters are compatible*` proceed to the real upgrade.

#### Step 5) Run pg_upgrade

To perform the actual pg_upgrade run the following command,

```sh
sudo su - postgres
/usr/lib/postgresql/16/bin/pg_upgrade -b /usr/lib/postgresql/15/bin -B /usr/lib/postgresql/16/bin \
                                      -d /var/lib/postgresql/15/main -D /var/lib/postgresql/16/main \
                                      --link --verbose -p 5433 -P 5432
```
Assuming the pg_upgrade completes with `Upgrade Complete` proceed with final steps 

#### Step 6) Check that the new cluster is working correctly 

First restart the upgraded cluster
```sh
sudo su - postgres
/usr/lib/postgresql/16/bin/pg_ctl -D /var/lib/postgresql/16/main start
```

Then login to postgres and run a simple command
```sql
sudo su - postgres
psql 
select version();
```

#### Step 7) Run vacuumdb to create Optimizer statistics

To update the Optimizer Statistics run the following command
```sh
sudo su - postgres
/usr/lib/postgresql/16/bin/vacuumdb --all --analyze-in-stages
```

#### Step 8) Delete old cluster (optional)

Eventually once you are happy with the newly upgraded cluster could delete the old cluster

```sh
sudo su - postgres
/var/lib/postgresql/16/main/delete_old_cluster.sh
```

Now above were all the steps taken to perform an upgrade from postgreSQL 15 to postgreSQL 16. 

I have packaged all of steps 1 to 7 in a bash script namely upgrade_postgres.sh
To run it once PostgreSQL 15 and PostgreSQL 16 are installed as by step 0a) and step 0b)

Below simply uploads the upgrade_postgres.sh script, and ensure its owned by postgres and has execute privileges, does not matter where it's located really.

```sh
sudo su - 
cp /uploaded_location/upgrade_postgres.sh /var/lib/postgresql/
cd /var/lib/postgresql/
chown postgres:postgres upgrade_postgres.sh
chmod 755 upgrade_postgres.sh
```

Then when you want to run the script

```sh
sudo su - postgres
cd /var/lib/postgresql/
./upgrade_postgres.sh
```



### Detail of Part 2 c) Find all long running (> 1 mins) queries for user “web”, and kill them.

### Assumptions for this part
I created a user on a postgres cluster called web using the following sql

```sql
create user web LOGIN;
alter user web with encrypted password 'mypass';

```

I then logged as web and run this query to mimic a long running query.

```sh
sudo su - postgres
psql -U web -h 127.0.0.1 postgres
select pg_sleep(5 * 60);

```

#### Step 1) Here is a general SQL query to check for long running sessions over 5 minutes

```sql
SELECT pid
      ,usename
      ,pg_stat_activity.query_start
      ,now() - pg_stat_activity.query_start AS query_time
      ,query
      ,state
      ,wait_event_type
      ,wait_event
FROM  pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes';

```

So to find sessions for web user that run longer than 1 minute here is the query.

```sql
SELECT pid
      ,usename
      ,pg_stat_activity.query_start
      ,now() - pg_stat_activity.query_start AS query_time
      ,query
      ,state
      ,wait_event_type
      ,wait_event
FROM  pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '1 minute'
AND   usename = 'web';

```
 
Now to kill a postgres session there are two ways of performing this task from psql

#### Step 2) To Cancel a query (safest approach)
try to use pg_cancel_backend(pid) as this tries to cancel the session in a nice way. Now the dynamic SQL below prints out any number of commands required to cancel web user sessions that have been running for over 1 minute

```sql
SELECT 'SELECT pg_cancel_backend(' || pid || ');'
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '1 minute'
AND   usename = 'web';

```

#### Step 3) To kill/terminate a query (can impact database)
if the session then does not disappear get the dba hammer out and use pg_terminate_backend(pid) but this can have side effects. Now the dynamic SQL below prints out any number of commands required to kill/terminate web user sessions that have been running for over 1 minute

```sql
SELECT 'SELECT pg_terminate_backend(' || pid || ');'
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '1 minute'
AND   usename = 'web';

```

#### Step 4) In the github repository there are two sql scripts

In the github repo I shared there are  two sql scripts, cancel_web_sessions_over1minute.sql and kill_web_sessions_over1minute.sql

that a) find the web user sessions that are over 1 minute and then b) either cancel or kill the session.

To run the sql scripts upload them to the database server, ensure they are owned by postgres using commands below. 
Also ensure the sql files exist in a directory that postgres owns as they create output files to run in order to work.

```sh
sudo su - 
cp /uploaded_location/cancel_web_sessions_over1minute.sql  /home/postgres/
cp /uploaded_location/kill_web_sessions_over1minute.sql  /home/postgres/
cd /home/postgres/
chown postgres:postgres cancel_web_sessions_over1minute.sql 
chown postgres:postgres kill_web_sessions_over1minute.sql 
```

Now i could have created them as shell scripts but decided to just leave them as sql scripts. To run them use the following.

```sh
sudo su - postgres
cd /home/postgres/
psql 
\i cancel_web_sessions_over1minute.sql 
```

or 

```sh
sudo su - postgres
cd /home/postgres/
psql 
\i kill_web_sessions_over1minute.sql 
```



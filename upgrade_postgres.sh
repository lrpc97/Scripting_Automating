#!/bin/bash
echo "step 1: optionally add any extension so's into new cluster and move any full text search files across too"

echo "step 2: stop both source Postgres 15 cluster and target Postgres 16 cluster"
/usr/lib/postgresql/15/bin/pg_ctl -D /var/lib/postgresql/15/main stop
/usr/lib/postgresql/16/bin/pg_ctl -D /var/lib/postgresql/16/main stop

echo "step 3: optionally prepare any standby clusters"

echo "step 4a: move the source cluster  *.conf files from /etc/postgresql/15/main/ and change source port to 5433"
cd /etc/postgresql/15/main/
cp *.conf /var/lib/postgresql/15/main/
mkdir /var/lib/postgresql/15/main/conf.d
cd /var/lib/postgresql/15/main/
echo "port = 5433" >> postgresql.conf

echo "step 4b: move target cluster *.conf files from /etc/postgresql/16/main/ and change target port to 5432"
cd /etc/postgresql/16/main/
cp *.conf /var/lib/postgresql/16/main/
mkdir /var/lib/postgresql/16/main/conf.d
cd /var/lib/postgresql/16/main/
echo "port = 5432" >> postgresql.conf

echo "step 4c: perform pg_upgrade dry run"
/usr/lib/postgresql/16/bin/pg_upgrade -b /usr/lib/postgresql/15/bin -B /usr/lib/postgresql/16/bin \
                                      -d /var/lib/postgresql/15/main -D /var/lib/postgresql/16/main \
                                      --check --link --verbose -p 5433 -P 5432
				      
echo "step 5: perform actual pg_upgrade"
/usr/lib/postgresql/16/bin/pg_upgrade -b /usr/lib/postgresql/15/bin -B /usr/lib/postgresql/16/bin \
                                      -d /var/lib/postgresql/15/main -D /var/lib/postgresql/16/main \
                                      --link --verbose -p 5433 -P 5432

echo "step 6: check upgraded cluster is working"

echo "step 6a: restart the upgraded target Postgres 16 cluster"
/usr/lib/postgresql/16/bin/pg_ctl -D /var/lib/postgresql/16/main start

echo "step 6b: check postgres is accepting connections"
psql << EOF
SELECT VERSION();
EOF

echo "step 7: run vaacumdb"
/usr/lib/postgresql/16/bin/vacuumdb --all --analyze-in-stages

exit 0


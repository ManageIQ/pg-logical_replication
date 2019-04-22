set -v

echo -e "wal_level = 'logical'\nmax_worker_processes = 10\nmax_replication_slots = 10\nmax_wal_senders = 10" | sudo tee -a /etc/postgresql/10/main/postgresql.conf
echo -e "local replication all trust" | sudo tee -a /etc/postgresql/10/main/pg_hba.conf
sudo service postgresql restart 10

set +v

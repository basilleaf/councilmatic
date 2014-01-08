#!/usr/bin/env bash

apt-get update
apt-get install -y git python python-pip postgresql libpq-dev postgis postgresql-9.1-postgis poppler-utils python-dev gdal-bin vim

cd /vagrant
sudo pip install -r requirements.txt

sed -i.bak 's/local   all             postgres                                peer/local   all             postgres                                trust/' /etc/postgresql/9.1/main/pg_hba.conf
sed -i.bak 's/local   all             all                                     peer/local   all             all                                     md5/' /etc/postgresql/9.1/main/pg_hba.conf
/etc/init.d/postgresql restart
psql -U postgres -w -d postgres -c "UPDATE pg_database SET datistemplate='true' WHERE datname='template_postgis';"
POSTGIS_SQL_PATH=`pg_config --sharedir`/contrib/postgis-1.5
createdb -U postgres -w -E UTF8 -T template0 --locale=en_US.utf8 template_postgis
psql -U postgres -w -d template_postgis -f $POSTGIS_SQL_PATH/postgis.sql
psql -U postgres -w -d template_postgis -f $POSTGIS_SQL_PATH/spatial_ref_sys.sql
psql -U postgres -w -d template_postgis -c "GRANT ALL ON geometry_columns TO PUBLIC;"
psql -U postgres -w -d template_postgis -c "GRANT ALL ON spatial_ref_sys TO PUBLIC;"
psql -U postgres -w -c "CREATE USER councilmatic WITH NOSUPERUSER ENCRYPTED PASSWORD 'councilmatic';"
createdb -U postgres -w -T template_postgis councilmatic

cd /vagrant
gunzip oakland-fullscrape-db.dump.gz
cat oakland-fullscrape-db.dump | psql -U postgres -w councilmatic
psql -U postgres -w -d councilmatic -c "GRANT ALL ON ALL TABLES IN SCHEMA public to councilmatic;"
psql -U postgres -w -d councilmatic -c "GRANT ALL ON ALL SEQUENCES IN SCHEMA public to councilmatic;"
psql -U postgres -w -d councilmatic -c "GRANT ALL ON ALL FUNCTIONS IN SCHEMA public to councilmatic;"

cd councilmatic
cp oakland_local_settings.py.template local_settings.py
python manage.py syncdb --noinput
python manage.py migrate
# python manage.py updatelegfiles
# python manage.py rebuild_index --noinput
python manage.py collectstatic --noinput
# python manage.py runserver 0.0.0.0:8000
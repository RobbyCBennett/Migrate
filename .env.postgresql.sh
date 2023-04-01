#!/bin/sh

# Location of migration SQL files, ending with a slash
migration_sql_dir='../../db/'

# Access
admin=postgres
database=my_cool_project
user=my_cool_project

# Driver command
driver=psql
driver_cmd='-c'
driver_only_results='-qtAX'
driver_file='-v ON_ERROR_STOP=1 -a -f'
driver_db='-d'

# Colors for the migration command-line interface
color_header='\033[0;34m'
color_up='\033[0;32m'
color_down='\033[0;31m'

# Query: create a user/role to access the project database
query_create_user()
{
	echo "CREATE ROLE $user LOGIN"
}

# Query: create a project database
query_create_database()
{
	echo "CREATE DATABASE $database OWNER $user"
}

# Query: create the table for migrations
query_create_migrations_table()
{
	echo 'CREATE TABLE migrations(id SERIAL, name VARCHAR(255) UNIQUE NOT NULL, up BOOLEAN)'
}

# Query: get the migration status
query_select_all_for_migration_status()
{
	echo 'SELECT * FROM migrations ORDER BY ID ASC'
}

# Query: get name of migration for the next './migrate.sh up'
query_select_name_for_migration_up()
{
	echo 'SELECT name FROM migrations WHERE NOT up ORDER BY ID ASC LIMIT 1'
}

# Query: given a name, mark a migration as up because it was successfully done
query_update_for_migration_up()
{
	echo "UPDATE migrations SET up = true WHERE name = '$1'"
}

# Query: get name of migration for the next './migrate.sh down'
query_select_name_for_migration_down()
{
	echo 'SELECT name FROM migrations WHERE up ORDER BY ID DESC LIMIT 1'
}

# Query: given a name, mark a migration as down because it was successfully undone
query_update_for_migration_down()
{
	echo "UPDATE migrations SET up = false WHERE name = '$1'"
}

# Query: given a name, create a migration in the migrations table
query_insert_migration()
{
	echo "INSERT INTO migrations (name, up) VALUES ('$1', false);"
}


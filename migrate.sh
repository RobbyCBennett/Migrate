#!/bin/sh


# Get information for database: access, driver, queries, etc.
. ./.env.sh


parse_up_down_args()
{
	count=1
	yes=''
	for arg in "$@"; do
		if [ "$arg" = "$arg_yes_short" ] || [ "$arg" = "$arg_yes_long" ]; then
			yes=1
		elif [ "$arg" -gt 1 ] 2>/dev/null; then
			count=$arg
		fi
	done
}


find_one_file()
{
	# Find the files that match either of the 2 patterns
	pattern=$1
	count=`find $migration_sql_dir -type f -name $pattern -exec printf %c {} + | wc -c`
	file=`find $migration_sql_dir -type f -name $pattern`

	# Error if there are more than 1
	if [ $count -gt 1 ]; then
		echo "Error: too many files for the migration name $name"
		echo "find $migration_sql_dir -type f -name $pattern"
		exit
	fi

	# Echo the only name
	echo $file
}


color_end='\033[0m'
echo_header()
{
	echo -e "$color_header$1$color_end"
}


echo_migration_up()
{
	echo -e "Migration name: $color_up$1$color_end"
}


echo_migration_down()
{
	echo -e "Migration name: $color_down$1$color_end"
}


confirm_migration()
{
	choice=''
	while [ "$choice" != 'y' ]; do
		printf 'Are you sure? (y/m/n) '
		read choice
		if [ "$choice" = 'n' ]; then
			echo 'Cancelled'
			exit
		elif [ "$choice" = 'm' ]; then
			cat $file
		fi
	done
}


init()
{
	query0=`query_create_user`
	query1=`query_create_database`
	query2=`query_create_migrations_table`

	me=`whoami`
	if [ $me = 'root' ]; then
		echo_header 'Creating user'
		su $admin -c "$driver $driver_cmd \"$query0\""
		echo
		echo_header 'Creating database'
		su $admin -c "$driver $driver_cmd \"$query1\""
		echo
		echo_header 'Creating migrations table'
		su $admin -c "$driver $driver_db $database $driver_cmd \"$query2\""
	elif [ $me = "$admin" ]; then
		echo_header 'Creating user'
		$driver $driver_cmd "$query0"
		echo
		echo_header 'Creating database'
		$driver $driver_cmd "$query1"
		echo
		echo_header 'Creating migrations table'
		$driver $driver_db $database $driver_cmd "$query2"
	else
		echo_header 'Creating user and database'
		echo "Run as $admin/root to create a user and a database"
		echo
		echo_header 'Creating migrations table'
		$driver $driver_db $database $driver_cmd "$query2"
	fi
}


migration_status()
{
	echo_header 'Migration status'

	# Get the status of migrations
	query=`query_select_all_for_migration_status`
	$driver $driver_db $database $driver_cmd "$query"
}


migrate_up()
{
	echo_header 'Migrating up'

	# Get name of migration
	query=`query_select_name_for_migration_up`
	name=`$driver $driver_db $database $driver_only_results $driver_cmd "$query"`
	if [ $? -ne 0 ]; then
		exit
	fi

	# Finished if all migrations are up
	if [ "$name" = '' ]; then
		echo 'All migrations are up'
		exit
	fi

	# Get path of the SQL file
	file=`find_one_file *-$name-up.sql`

	# Get confirmation
	echo_migration_up $name
	if ! [ "$yes" ]; then
		confirm_migration
	fi

	# Run the SQL file
	$driver $driver_db $database $driver_file "$file"
	if [ $? -ne 0 ]; then
		exit
	fi

	echo
	echo_header 'Marking the migration as up'

	# Mark the migration as up
	query=`query_update_for_migration_up $name`
	$driver $driver_db $database $driver_cmd "$query"
}


migrate_down()
{
	echo_header 'Migrating down'

	# Get name of migration
	query=`query_select_name_for_migration_down`
	name=`$driver $driver_db $database $driver_only_results $driver_cmd "$query"`

	# Finished if all migrations are down
	if [ "$name" = '' ]; then
		echo 'All migrations are down'
		exit
	fi

	# Get path of the SQL file
	file=`find_one_file *-$name-down.sql`

	# Get confirmation
	echo_migration_down $name
	if ! [ "$yes" ]; then
		confirm_migration
	fi

	# Run the SQL file
	$driver $driver_db $database $driver_file "$file"
	if [ $? -ne 0 ]; then
		exit
	fi

	echo
	echo_header 'Marking the migration as down'

	# Mark the migration as down
	query=`query_update_for_migration_down $name`
	$driver $driver_db $database $driver_cmd "$query"
}


sort_migrations_by_prefix_and_get_names()
{
	pattern=*-*-up.sql
	find $migration_sql_dir -type f -name $pattern | rev | cut -d / -f 1 | rev | sort | rev | cut -d - -f 2 | rev
}


create_all_migrations()
{
	echo_header 'Making sure that all SQL migration names are in the database'

	total=0
	for name in `sort_migrations_by_prefix_and_get_names`; do
		query=`query_insert_migration $name`
		result=`$driver $driver_db $database $driver_cmd "$query" 2> /dev/null | cut -d ' ' -f 3`
		if [ "$result" ] && [ $result -eq 1 ]; then
			total=$(($total + 1))
			echo "Inserted $name"
		fi
	done
	echo "Inserted $total names of existing SQL migration files"
}


create_migration()
{
	echo_header 'Inserting row into migrations table'

	# Insert into database
	name=$1
	query=`query_insert_migration $name`
	$driver $driver_db $database $driver_cmd "$query"

	echo
	echo_header 'Creating files for migration'

	# Error if file exists
	up=`find_one_file *-$name-up.sql`
	down=`find_one_file *-$name-down.sql`
	if [ "$up" ] || [ "$down" ]; then
		echo 'Error: an SQL file with that migration name already exists'
		if [ "$up" ]; then echo $up; fi
		if [ "$down" ]; then echo $down; fi
		exit
	fi

	# Create files
	date=`date +%Y-%m-%d-%H-%M-%S`
	up="$migration_sql_dir$date-$name-up.sql"
	down="$migration_sql_dir$date-$name-down.sql"
	touch $up
	touch $down
	echo $up
	echo $down
}


help()
{
	echo_header 'Migration help'
	echo
	echo '    Usage:'
	echo '        ./migrate.sh MIG_NAME'
	echo '        ./migrate.sh up EXTRA_ARGS'
	echo '        ./migrate.sh down EXTRA_ARGS'
	echo
	echo '    Examples:'
	echo '        ./migrate.sh init'
	echo '        ./migrate.sh create_users_table'
	echo '        ./migrate.sh up'
	echo '        ./migrate.sh up 2'
	echo '        ./migrate.sh down 3 yes'
	echo '        ./migrate.sh status'
	echo
	echo '    Primary Arguments:'
	echo '        init:        Initialize the database and create the migrations table'
	echo
	echo '        MIG_NAME:    Create a migration (usually snake_case) with the given migration name'
	echo
	echo '        up:          Use a migration to change the database'
	echo '        down:        Undo a migration to change the database back'
	echo
	echo '        status:      Get the status of all migrations'
	echo
	echo '    Extra Arguments (EXTRA_ARGS):'
	echo '        yes:         Ignore confirmation for each migration (dangerous)'
	echo '        INTEGER:     Instead of only 1 migration, migrate up/down many times'
	echo
	echo '    Tips:'
	echo '        Folders:     Organize SQL files into folders if you want to'
}


# Main: parse arguments
if [ "$1" = "$arg_init_short" ] || [ "$1" = "$arg_init_long" ]; then
	init
	echo
	create_all_migrations
elif [ "$1" = "$arg_status_short" ] || [ "$1" = "$arg_status_long" ]; then
	create_all_migrations
	echo
	migration_status
elif [ "$1" = "$arg_up_short" ] || [ "$1" = "$arg_up_long" ]; then
	create_all_migrations
	echo
	parse_up_down_args $*
	i=0
	while [ $i -lt $count ]; do
		migrate_up
		if [ $count -gt 1 ]; then
			echo
		fi
		i=$(($i + 1))
	done
elif [ "$1" = "$arg_down_short" ] || [ "$1" = "$arg_down_long" ]; then
	create_all_migrations
	echo
	parse_up_down_args $*
	i=0
	while [ $i -lt $count ]; do
		migrate_down
		if [ $count -gt 1 ]; then
			echo
		fi
		i=$(($i + 1))
	done
elif [ "$1" = '' ] || [ "$1" = "$arg_help_short" ] || [ "$1" = "$arg_help_long" ] || [ "$1" = '--help' ]; then
	help
else
	create_all_migrations
	echo
	create_migration $1
fi


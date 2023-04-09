# Migrate

Portable database migration shell script

# 🧠 Design Philosophy

* Simple to use and portable
* Migrate up/down multiple times with one command
* Review each migration if you want to
* Extensible via the environment script

# 📥 Installation

Clone the repository, which includes the migrate script, and an example environment script for PostgreSQL

Create an environment script and edit it, especially `migration_sql_dir`, `database`, and `user`

```sh
cd MY_EXISTING_REPO_HERE
git submodule add git@github.com:RobbyCBennett/migrate.git
cd migrate
cp .env.postgresql.sh .env.sh
edit .env.sh
```

# 📚 Help

```sh
./migrate.sh
```

```
Migration help

    Usage:
        ./migrate.sh MIG_NAME
        ./migrate.sh up EXTRA_ARGS
        ./migrate.sh down EXTRA_ARGS

    Examples:
        ./migrate.sh init
        ./migrate.sh create_users_table
        ./migrate.sh up
        ./migrate.sh up 2
        ./migrate.sh down 3 yes
        ./migrate.sh status

    Primary Arguments:
        init:        Initialize the database and create the migrations table

        MIG_NAME:    Create a migration (usually snake_case) with the given migration name

        up:          Use a migration to change the database
        down:        Undo a migration to change the database back

        status:      Get the status of all migrations

    Extra Arguments (EXTRA_ARGS):
        yes:         Ignore confirmation for each migration (dangerous)
        INTEGER:     Instead of only 1 migration, migrate up/down many times

    Tips:
        Folders:     Organize SQL files into folders if you want to
```


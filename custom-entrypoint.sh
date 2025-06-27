#!/bin/bash
set -e

# Path to the flag file within the container
FLAG_FILE="/tmp/first_run_done"

# Check if the flag file exists
if [ ! -f "$FLAG_FILE" ]; then
    echo "Running custom first-time setup for Zammad..."

    # Wait for PostgreSQL to be ready - more robust than fixed sleep
    echo "Waiting for zammad-postgresql to be available..."
    until pg_isready -h "$POSTGRESQL_HOST" -p "$POSTGRESQL_PORT" -U "$POSTGRESQL_USER"; do
      echo >&2 "Postgres is unavailable - sleeping"
      sleep 1
    done
    echo "Postgres is up - continuing"

    # --- REMOVED MANUAL DATABASE.YML GENERATION ---
    # The official Zammad entrypoint handles this based on environment variables.
    echo "Manual database.yml generation skipped, using Zammad's default via environment variables."

    # Run Rails console to create the admin user and assign the Admin role
    echo "Creating admin user..."

    # Run the Rails console commands directly inside the container
    bundle exec rails runner "
      user = User.find_or_initialize_by(email: '$ZAMMAD_EMAIL')
      if user.new_record?
        user.assign_attributes(
          login: '$ZAMMAD_USER',
          firstname: 'Admin',
          lastname: 'User',
          password: '$ZAMMAD_PASSWORD',
          active: true,
          created_by_id: 1,
          updated_by_id: 1
        )
        user.save!
        puts 'New Admin user created.'
      else
        puts 'Admin user already exists.'
      end

      # Assign roles and groups only if not already assigned
      user = User.find_by(email: '$ZAMMAD_EMAIL')
      if user
        ['Admin', 'Agent'].each do |role_name|
          role = Role.find_by(name: role_name)
          if role && !user.roles.include?(role)
            user.roles << role
            puts \"Assigned #{role_name} role to admin user.\"
          end
        end

        group = Group.find_by(name: 'Users')
        if group && !user.groups.include?(group)
          user.groups << group
          puts \"Assigned Users group to admin user.\"
        end
      end

      puts 'Admin user creation/update script finished.'
    "

    echo "Custom first-time setup completed."
    touch "$FLAG_FILE"
fi

# IMPORTANT: Always execute the original Zammad entrypoint at the end.
# This ensures all necessary Zammad internal setup (like STORAGE_BACKEND processing)
# and the actual Rails server startup are handled correctly.
exec /docker-entrypoint.sh "$@"

#!/bin/bash

# Path to the flag file
FLAG_FILE="/tmp/first_run_done"

# Check if the flag file exists
if [ ! -f "$FLAG_FILE" ]; then
# Wait for Zammad to be up and running
echo "Waiting for Zammad to start..."

echo "# This is a database configuration file for Zammad, ready to use with a PostgreSQL DB." > /opt/zammad/config/database.yml
echo "# Copy or symlink this file to config/database.yml to use it." >> /opt/zammad/config/database.yml
echo "" >> /opt/zammad/config/database.yml
echo "default: &default" >> /opt/zammad/config/database.yml
echo "  # For details on connection pooling, see Rails configuration guide" >> /opt/zammad/config/database.yml
echo "  # http://guides.rubyonrails.org/configuring.html#database-pooling" >> /opt/zammad/config/database.yml
echo "  pool: 50" >> /opt/zammad/config/database.yml
echo "  encoding: unicode" >> /opt/zammad/config/database.yml
echo "  username: $POSTGRESQL_USER">> /opt/zammad/config/database.yml
echo "  password: $POSTGRESQL_PASS" >> /opt/zammad/config/database.yml
echo "" >> /opt/zammad/config/database.yml
echo "  ##### PostgreSQL config #####" >> /opt/zammad/config/database.yml
echo "  adapter: postgresql" >> /opt/zammad/config/database.yml
echo "  host: $POSTGRESQL_HOST  # Use environment variable POSTGRES_HOST or default to 'zammad-postgresql'" >> /opt/zammad/config/database.yml
echo "  port: $POSTGRESQL_PORT            # Use environment variable POSTGRES_PORT or default to '5432'" >> /opt/zammad/config/database.yml
echo "" >> /opt/zammad/config/database.yml
echo "production:" >> /opt/zammad/config/database.yml
echo "  <<: *default" >> /opt/zammad/config/database.yml
echo "  database: $POSTGRESQL_DB  # Use environment variable POSTGRES_DB or default to 'zammad_production'" >> /opt/zammad/config/database.yml
echo "" >> /opt/zammad/config/database.yml
echo "development:" >> /opt/zammad/config/database.yml
echo "  <<: *default" >> /opt/zammad/config/database.yml
echo "  database: zammad_development  # Use environment variable POSTGRES_DB or default to 'zammad_development'" >> /opt/zammad/config/database.yml
echo "" >> /opt/zammad/config/database.yml
echo "# Warning: The database defined as \"test\" will be erased and" >> /opt/zammad/config/database.yml
echo "# re-generated from your development database when you run \"rake\"." >> /opt/zammad/config/database.yml
echo "# Do not set this db to the same as development or production." >> /opt/zammad/config/database.yml
echo "test:" >> /opt/zammad/config/database.yml
echo "  <<: *default" >> /opt/zammad/config/database.yml
echo "  database: zammad_test  # Use environment variable POSTGRES_DB or default to 'zammad_test'" >> /opt/zammad/config/database.yml

echo "database.yml created"

sleep 30  # Adjust the sleep time if necessary

# Run Rails console to create the admin user and assign the Admin role
echo "Creating admin user..."

# Run the Rails console commands directly inside the container
bundle exec rails runner "
  user = User.create!(
    email: '$ZAMMAD_EMAIL',
    login: '$ZAMMAD_USER',
    firstname: 'Admin',
    lastname: 'User',
    password: '$ZAMMAD_PASSWORD',
    active: true,
    created_by_id: 1,
    updated_by_id: 1
  )

  # Assign the 'Admin' role to the new user
  role = Role.find_by(name: 'Admin')
  permission = Permission.find_by(name: 'ticket.agent')
  role.permissions << permission
  user.roles << role
  role2 = Role.find_by(name: 'Agent')
  user.roles << role2
  group = Group.find_by(name: 'Users')
  user.groups << group

  puts 'Admin user created and role assigned successfully!'
"

# Ensure Zammad starts up after the user creation
echo "Admin user creation script finished."

touch "$FLAG_FILE"

export RAILS_ENV=production
exec bin/rails server -b '0.0.0.0'

fi

# Start the Rails server
exec bin/rails server -b '0.0.0.0'
#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# db-user.sh — Create / Delete / List database users with isolated access
#
# Usage:
#   ./db-user.sh <engine> create <username> <password> [db1,db2,...]
#   ./db-user.sh <engine> delete <username>
#   ./db-user.sh <engine> list
#
# Engines: postgres | mongodb | mysql | redis
#
# Examples:
#   ./db-user.sh postgres create myapp 'SecurePass123!' myapp_dev,myapp_staging
#   ./db-user.sh mongodb create myapp 'SecurePass123!' orders,inventory,users
#   ./db-user.sh mysql   create myapp 'SecurePass123!' myapp_dev,myapp_staging
#   ./db-user.sh redis   create myapp 'SecurePass123!'
#
#   ./db-user.sh postgres delete myapp
#   ./db-user.sh mongodb delete myapp
#   ./db-user.sh mysql   delete myapp
#   ./db-user.sh redis   delete myapp
#
#   ./db-user.sh postgres list
#   ./db-user.sh mongodb list
#   ./db-user.sh mysql   list
#   ./db-user.sh redis   list
#
# Notes:
#   - Postgres: creates role + databases, revokes public connect
#   - MongoDB:  creates user in each DB with readWrite role
#   - MySQL:    creates user + databases, grants per-DB privileges
#   - Redis:    creates ACL user with full command access
#   - All commands run via kubectl exec against the databases namespace
###############################################################################

NAMESPACE="databases"

die() { echo "ERROR: $*" >&2; exit 1; }

usage() {
  sed -n '3,36p' "$0" | sed 's/^# \?//'
  exit 1
}

# --- Postgres ---------------------------------------------------------------
postgres_create() {
  local user="$1" pass="$2" dbs="$3"
  [[ -z "$dbs" ]] && die "Postgres requires at least one database name"

  local sql="CREATE ROLE ${user} WITH LOGIN PASSWORD '${pass}';"
  IFS=',' read -ra DB_ARRAY <<< "$dbs"
  for db in "${DB_ARRAY[@]}"; do
    sql+="
CREATE DATABASE ${db} OWNER ${user};
GRANT ALL PRIVILEGES ON DATABASE ${db} TO ${user};
REVOKE ALL ON DATABASE ${db} FROM PUBLIC;"
  done

  echo "Creating Postgres user '${user}' with databases: ${dbs}"
  kubectl exec -n "$NAMESPACE" deploy/postgres -- \
    psql -U postgres -c "$sql"
  echo "Done."
}

postgres_delete() {
  local user="$1"

  # Find all databases owned by this user
  local dbs
  dbs=$(kubectl exec -n "$NAMESPACE" deploy/postgres -- \
    psql -U postgres -tAc "SELECT datname FROM pg_database WHERE datdba = (SELECT oid FROM pg_roles WHERE rolname = '${user}');")

  if [[ -n "$dbs" ]]; then
    local sql=""
    while IFS= read -r db; do
      [[ -z "$db" ]] && continue
      sql+="DROP DATABASE IF EXISTS ${db};"
    done <<< "$dbs"
    sql+="DROP ROLE IF EXISTS ${user};"

    echo "Dropping Postgres user '${user}' and databases: $(echo "$dbs" | tr '\n' ',' | sed 's/,$//')"
    kubectl exec -n "$NAMESPACE" deploy/postgres -- \
      psql -U postgres -c "$sql"
  else
    echo "Dropping Postgres user '${user}' (no databases found)"
    kubectl exec -n "$NAMESPACE" deploy/postgres -- \
      psql -U postgres -c "DROP ROLE IF EXISTS ${user};"
  fi
  echo "Done."
}

postgres_list() {
  echo "=== Postgres Users & Databases ==="
  kubectl exec -n "$NAMESPACE" deploy/postgres -- \
    psql -U postgres -c "
SELECT r.rolname AS username,
       COALESCE(string_agg(d.datname, ', '), '(none)') AS databases
FROM pg_roles r
LEFT JOIN pg_database d ON d.datdba = r.oid
WHERE r.rolcanlogin = true AND r.rolname NOT LIKE 'pg_%'
GROUP BY r.rolname
ORDER BY r.rolname;"
}

# --- MongoDB ----------------------------------------------------------------
mongodb_create() {
  local user="$1" pass="$2" dbs="$3"
  [[ -z "$dbs" ]] && die "MongoDB requires at least one database name"

  IFS=',' read -ra DB_ARRAY <<< "$dbs"
  local roles="["
  local first=true
  for db in "${DB_ARRAY[@]}"; do
    $first || roles+=","
    roles+="{role:'readWrite',db:'${db}'}"
    first=false
  done
  roles+="]"

  # Create user in the first DB (auth source)
  local auth_db="${DB_ARRAY[0]}"
  local js="db.getSiblingDB('${auth_db}').createUser({user:'${user}',pwd:'${pass}',roles:${roles}});"

  # Create placeholder collection in each DB so they show up
  for db in "${DB_ARRAY[@]}"; do
    js+="db.getSiblingDB('${db}').createCollection('_init');"
  done

  echo "Creating MongoDB user '${user}' (authSource=${auth_db}) with databases: ${dbs}"
  kubectl exec -n "$NAMESPACE" deploy/mongodb -- \
    mongosh -u admin -p "$(mongodb_root_pass)" --authenticationDatabase admin --eval "$js" --quiet
  echo "Done."
}

mongodb_delete() {
  local user="$1"

  # Find the user across all databases
  local js="
var found = false;
db.adminCommand({listDatabases:1}).databases.forEach(function(d) {
  var users = db.getSiblingDB(d.name).getUsers().users;
  users.forEach(function(u) {
    if (u.user === '${user}') {
      // Drop all databases this user has readWrite on
      u.roles.forEach(function(r) {
        if (r.role === 'readWrite') {
          print('Dropping database: ' + r.db);
          db.getSiblingDB(r.db).dropDatabase();
        }
      });
      print('Dropping user: ' + u.user + ' from db: ' + d.name);
      db.getSiblingDB(d.name).dropUser('${user}');
      found = true;
    }
  });
});
if (!found) print('User not found: ${user}');
"
  echo "Deleting MongoDB user '${user}' and associated databases..."
  kubectl exec -n "$NAMESPACE" deploy/mongodb -- \
    mongosh -u admin -p "$(mongodb_root_pass)" --authenticationDatabase admin --eval "$js" --quiet
  echo "Done."
}

mongodb_list() {
  echo "=== MongoDB Users & Databases ==="
  local js="
db.adminCommand({listDatabases:1}).databases.forEach(function(d) {
  if (['admin','config','local'].indexOf(d.name) !== -1) return;
  var users = db.getSiblingDB(d.name).getUsers().users;
  users.forEach(function(u) {
    var dbs = u.roles.filter(function(r){return r.role==='readWrite'}).map(function(r){return r.db});
    print(u.user + ' -> ' + (dbs.length ? dbs.join(', ') : '(no dbs)'));
  });
});
"
  kubectl exec -n "$NAMESPACE" deploy/mongodb -- \
    mongosh -u admin -p "$(mongodb_root_pass)" --authenticationDatabase admin --eval "$js" --quiet
}

mongodb_root_pass() {
  kubectl get secret mongodb-secret -n "$NAMESPACE" -o jsonpath='{.data.MONGO_INITDB_ROOT_PASSWORD}' | base64 -d
}

# --- MySQL ------------------------------------------------------------------
mysql_create() {
  local user="$1" pass="$2" dbs="$3"
  [[ -z "$dbs" ]] && die "MySQL requires at least one database name"

  local sql="CREATE USER IF NOT EXISTS '${user}'@'%' IDENTIFIED BY '${pass}';"
  IFS=',' read -ra DB_ARRAY <<< "$dbs"
  for db in "${DB_ARRAY[@]}"; do
    sql+="
CREATE DATABASE IF NOT EXISTS \`${db}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON \`${db}\`.* TO '${user}'@'%';"
  done
  sql+="FLUSH PRIVILEGES;"

  echo "Creating MySQL user '${user}' with databases: ${dbs}"
  kubectl exec -n "$NAMESPACE" deploy/mysql -- \
    mysql -u root -p"$(mysql_root_pass)" -e "$sql"
  echo "Done."
}

mysql_delete() {
  local user="$1"

  # Find databases this user has access to
  local dbs
  dbs=$(kubectl exec -n "$NAMESPACE" deploy/mysql -- \
    mysql -u root -p"$(mysql_root_pass)" -sNe \
    "SELECT DISTINCT TABLE_SCHEMA FROM information_schema.SCHEMA_PRIVILEGES WHERE GRANTEE = \"'${user}'@'%'\";")

  local sql=""
  if [[ -n "$dbs" ]]; then
    while IFS= read -r db; do
      [[ -z "$db" ]] && continue
      sql+="DROP DATABASE IF EXISTS \`${db}\`;"
    done <<< "$dbs"
    echo "Dropping MySQL user '${user}' and databases: $(echo "$dbs" | tr '\n' ',' | sed 's/,$//')"
  else
    echo "Dropping MySQL user '${user}' (no databases found)"
  fi
  sql+="DROP USER IF EXISTS '${user}'@'%'; FLUSH PRIVILEGES;"

  kubectl exec -n "$NAMESPACE" deploy/mysql -- \
    mysql -u root -p"$(mysql_root_pass)" -e "$sql"
  echo "Done."
}

mysql_list() {
  echo "=== MySQL Users & Databases ==="
  kubectl exec -n "$NAMESPACE" deploy/mysql -- \
    mysql -u root -p"$(mysql_root_pass)" -e "
SELECT u.User AS username,
       COALESCE(GROUP_CONCAT(DISTINCT s.TABLE_SCHEMA), '(none)') AS databases
FROM mysql.user u
LEFT JOIN information_schema.SCHEMA_PRIVILEGES s
  ON s.GRANTEE = CONCAT('''', u.User, '''@''', u.Host, '''')
WHERE u.User NOT IN ('root', 'mysql.sys', 'mysql.session', 'mysql.infoschema', 'debian-sys-maint')
GROUP BY u.User
ORDER BY u.User;"
}

mysql_root_pass() {
  kubectl get secret mysql-secret -n "$NAMESPACE" -o jsonpath='{.data.MYSQL_ROOT_PASSWORD}' | base64 -d
}

# --- Redis ------------------------------------------------------------------
redis_create() {
  local user="$1" pass="$2"

  echo "Creating Redis user '${user}'"
  kubectl exec -n "$NAMESPACE" deploy/redis -- \
    redis-cli --user admin --pass "$(redis_admin_pass)" \
    ACL SETUSER "$user" on ">$pass" '~*' '&*' +@all
  # Persist to disk
  kubectl exec -n "$NAMESPACE" deploy/redis -- \
    redis-cli --user admin --pass "$(redis_admin_pass)" ACL SAVE
  echo "Done."
}

redis_delete() {
  local user="$1"
  [[ "$user" == "admin" || "$user" == "default" ]] && die "Cannot delete '$user' user"

  echo "Deleting Redis user '${user}'"
  kubectl exec -n "$NAMESPACE" deploy/redis -- \
    redis-cli --user admin --pass "$(redis_admin_pass)" ACL DELUSER "$user"
  kubectl exec -n "$NAMESPACE" deploy/redis -- \
    redis-cli --user admin --pass "$(redis_admin_pass)" ACL SAVE
  echo "Done."
}

redis_list() {
  echo "=== Redis Users ==="
  kubectl exec -n "$NAMESPACE" deploy/redis -- \
    redis-cli --user admin --pass "$(redis_admin_pass)" ACL LIST 2>/dev/null
}

redis_admin_pass() {
  # Hardcoded in ACL file — update if you change it
  echo "adminRedis2024!"
}

# --- Main -------------------------------------------------------------------
[[ $# -lt 2 ]] && usage

ENGINE="$1"
ACTION="$2"
USERNAME="${3:-}"
PASSWORD="${4:-}"
DATABASES="${5:-}"

case "$ENGINE" in
  postgres|mongodb|mysql|redis) ;;
  *) die "Unknown engine: $ENGINE (use: postgres, mongodb, mysql, redis)" ;;
esac

case "$ACTION" in
  create)
    [[ -z "$USERNAME" ]] && die "Username required"
    [[ -z "$PASSWORD" ]] && die "Password required"
    ${ENGINE}_create "$USERNAME" "$PASSWORD" "$DATABASES"
    ;;
  delete)
    [[ -z "$USERNAME" ]] && die "Username required"
    read -rp "Delete user '${USERNAME}' and all their databases from ${ENGINE}? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
    ${ENGINE}_delete "$USERNAME"
    ;;
  list)
    ${ENGINE}_list
    ;;
  *)
    die "Unknown action: $ACTION (use: create, delete, list)"
    ;;
esac

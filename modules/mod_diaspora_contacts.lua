-- Prosody module to import diaspora contacts into a users roster.
-- Inspired by mod_auth_sql and mod_groups of the Prosody software.
--
-- As with mod_groups the change is not permanent and thus any changes
-- to the imported contacts will be lost.
--
-- The MIT License (MIT)
--
-- Copyright (c) <2014> <Jonne Haß <me@jhass.eu>>
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.

local log = require "util.logger".init("diaspora_contacts")
local DBI = require "DBI"
local jid, datamanager = require "util.jid", require "util.datamanager"
local jid_prep = jid.prep
local rostermanager = require "core.rostermanager"

local module_host = module:get_host()
local host = prosody.hosts[module_host]

local connection
local params = module:get_option("diaspora_contacts", module:get_option("auth_diaspora", module:get_option("auth_sql", module:get_option("sql"))))

local function test_connection()
  if not connection then return nil; end

  if connection:ping() then
    return true
  else
    module:log("debug", "Database connection closed")
    connection = nil
  end
end

local function set_encoding(conn)
  if params.driver ~= "MySQL" then return; end
  local set_names_query = "SET NAMES '%s';"
  local stmt = assert(conn:prepare("SET NAMES 'utf8mb4';"));
  assert(stmt:execute());
end

local function connect()
  if not test_connection() then
    prosody.unlock_globals()
    local dbh, err = DBI.Connect(
      params.driver, params.database,
      params.username, params.password,
      params.host, params.port
    )
    prosody.lock_globals()
    if not dbh then
      module:log("debug", "Database connection failed: %s", tostring(err))
      return nil, err
    end
    set_encoding(dbh);
    module:log("debug", "Successfully connected to database")
    dbh:autocommit(true) -- don't run in transaction
    connection = dbh
    return connection
  end
end

do -- process options to get a db connection
  assert(params.driver and params.database, "Both the SQL driver and the database need to be specified")

  assert(connect())
end

local function getsql(sql, ...)
  if params.driver == "PostgreSQL" then
    sql = sql:gsub("`", "\"")
  elseif params.driver == "MySQL" then
    sql = sql:gsub(";$", " CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci';")
  end

  if not test_connection() then connect(); end

  -- do prepared statement stuff
  local stmt, err = connection:prepare(sql)
  if not stmt and not test_connection() then error("connection failed"); end
  if not stmt then module:log("error", "QUERY FAILED: %s %s", err, debug.traceback()); return nil, err; end
  -- run query
  local ok, err = stmt:execute(...)
  if not ok and not test_connection() then error("connection failed"); end
  if not ok then return nil, err; end

  return stmt;
end

local function get_contacts(username)
  module:log("debug", "loading contacts for %s", username)
  local contacts = {}

  local stmt, err = getsql([[
    SELECT people.diaspora_handle AS jid,
           COALESCE(NULLIF(CONCAT(first_name, ' ', last_name), ' '), people.diaspora_handle) AS name,
           CONCAT(aspects.name, ' (Diaspora)') AS group_name,
           CASE
             WHEN sharing = true  AND receiving = true  THEN 'both'
             WHEN sharing = true  AND receiving = false THEN 'to'
             WHEN sharing = false AND receiving = true  THEN 'from'
             ELSE                                            'none'
           END AS subscription
    FROM contacts
      JOIN people ON people.id = contacts.person_id
      JOIN profiles ON profiles.person_id = people.id
      JOIN users ON users.id = contacts.user_id
      JOIN aspect_memberships ON aspect_memberships.contact_id = contacts.id
      JOIN aspects ON aspects.id = aspect_memberships.aspect_id
    WHERE (receiving = true OR sharing = true)
      AND chat_enabled = true
      AND username = ?
  ]], username)

  if stmt then
    for row in stmt:rows(true) do
      if not contacts[row.jid] then
        contacts[row.jid] = {}
        contacts[row.jid].subscription = row.subscription
        contacts[row.jid].name = row.name
        contacts[row.jid].groups = {}
      end

      contacts[row.jid].groups[row.group_name] = true
    end

    return contacts
  end
end

local function update_roster(roster, contacts, update_action)
  if not contacts then return; end

  for user_jid, contact in pairs(contacts) do
    local updated = false

    if not roster[user_jid] then
      roster[user_jid] = {}
      roster[user_jid].subscription = contact.subscription
      roster[user_jid].name = contact.name
      roster[user_jid].persist = false
      updated = true
    end

    if not roster[user_jid].groups then
      roster[user_jid].groups = {}
    end

    for group in pairs(contact.groups) do
      if not roster[user_jid].groups[group] then
        roster[user_jid].groups[group] = true
        updated = true
      end
    end

    for group in pairs(roster[user_jid].groups) do
      if not contact.groups[group] then
        roster[user_jid].groups[group] = nil
        updated = true
      end
    end

    if updated and update_action then
      update_action(user_jid)
    end
  end

  for user_jid, contact in pairs(roster) do
    if contact.persist == false then
      if not contacts[user_jid] then
        roster[user_jid] = nil

        if update_action then
          update_action(user_jid)
        end
      end
    end
  end
end

function bump_roster_version(roster)
  if roster[false] then
    roster[false].version = (tonumber(roster[false].version) or 0) + 1
  end
end

local function update_roster_contacts(username, host, roster)
  update_roster(roster, get_contacts(username), function (user_jid)
    module:log("debug", "pushing roster update to %s for %s", jid.join(username, host), user_jid)
    bump_roster_version(roster)
    rostermanager.roster_push(username, host, user_jid)
  end)
end

function inject_roster_contacts(event, var2, var3)
  local username = ""
  local host = ""
  local roster = {}
  if type(event) == "table" then
    module:log("debug", "Prosody 0.10 or trunk detected. Use event variable.")
    username = event.username
    host = event.host
    roster = event.roster
  else
    module:log("debug", "Prosody 0.9.x detected, Use old variable style.")
    username = event
    host = var2
    roster = var3
  end
  local fulljid = jid.join(username, host)
  module:log("debug", "injecting contacts for %s", fulljid)
  update_roster(roster, get_contacts(username))

  bump_roster_version(roster)
end


function update_all_rosters()
  module:log("debug", "updating all rosters")

  for username, user in pairs(host.sessions) do
    module:log("debug", "Updating roster for %s", jid.join(username, module_host))
    update_roster_contacts(username, module_host, rostermanager.load_roster(username, module_host))
  end

  return 300
end

function remove_virtual_contacts(username, host, datastore, roster)
  if host == module_host and datastore == "roster" then
    module:log("debug", "removing injected contacts before storing roster of %s", jid.join(username, host))

    local new_roster = {}
    for jid, contact in pairs(roster) do
      if contact.persist ~= false then
        new_roster[jid] = contact
      end
    end
    if roster[false] then
      new_roster[false] = {}
      new_roster[false].version = roster[false].version
    end
    return username, host, datastore, new_roster
  end

  return username, host, datastore, roster
end

function module.load()
  module:hook("roster-load", inject_roster_contacts)
  module:add_timer(300, update_all_rosters)
  datamanager.add_callback(remove_virtual_contacts)
end

function module.unload()
  datamanager.remove_callback(remove_virtual_contacts)
end

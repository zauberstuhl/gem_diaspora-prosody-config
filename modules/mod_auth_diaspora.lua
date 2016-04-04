-- Based on Simple SQL Authentication module for Prosody IM
-- Copyright (C) 2011 Tomasz Sterna <tomek@xiaoka.com>
-- Copyright (C) 2011 Waqas Hussain <waqas20@gmail.com>
--
-- 25/05/2014: Modified for Diaspora by Anahuac de Paula Gil - anahuac@anahuac.eu
-- 06/08/2014: Cleaned up and fixed SASL auth by Jonne Haß <me@jhass.eu>
-- 22/11/2014: Allow token authentication by Jonne Haß <me@jhass.eu>

local log = require "util.logger".init("auth_diaspora")
local new_sasl = require "util.sasl".new
local DBI = require "DBI"
local bcrypt = require "bcrypt"

local connection
local params = module:get_option("auth_diaspora", module:get_option("auth_sql", module:get_option("sql")))

local resolve_relative_path = require "core.configmanager".resolve_relative_path

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
    module:log("debug", "Successfully connected to database");
    dbh:autocommit(true); -- don't run in transaction
    connection = dbh
    return connection
  end
end

do -- process options to get a db connection
  params = params or { driver = "SQLite3" }

  if params.driver == "SQLite3" then
    params.database = resolve_relative_path(prosody.paths.data or ".", params.database or "prosody.sqlite")
  end

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

  return stmt
end

local function get_password(username)
  local stmt, err = getsql("SELECT encrypted_password FROM users WHERE locked_at IS NULL AND username = ?", username)
  if stmt then
    for row in stmt:rows(true) do
      return row.encrypted_password
    end
  end
end

local function get_token(username)
  local stmt, err = getsql("SELECT authentication_token FROM users WHERE locked_at IS NULL AND username = ?", username)
  if stmt then
    for row in stmt:rows(true) do
      return row.authentication_token
    end
  end
end

local function test_password(username, password)
  -- pepper imported from diaspora/config/initializers/devise.rb
  local pepper = "065eb8798b181ff0ea2c5c16aee0ff8b70e04e2ee6bd6e08b49da46924223e39127d5335e466207d42bf2a045c12be5f90e92012a4f05f7fc6d9f3c875f4c95b"
  -- adding pepper to the regular password
  local pw_plus_pepper = password .. pepper

  -- Getting password from Diaspora database
  local pw_stored = get_password(username)

  -- Comparing password. If fail aborts
  return password and pw_stored and bcrypt.verify(pw_plus_pepper, pw_stored)
end

local function test_token(username, token)
  local stored_token = get_token(username)
  return stored_token and token == stored_token
end


provider = {};

function provider.test_password(username, password)
  return test_password(username, password) or test_token(username, password)
end

function provider.get_password(username)
  return get_password(username)
end

function provider.set_password(username, password)
  return nil, "Setting password is not supported."
end

function provider.user_exists(username)
  return get_password(username) and true
end

function provider.create_user(username, password)
  return nil, "Account creation/modification not supported."
end

function provider.get_sasl_handler()
  local profile = {
    plain_test = function(sasl, username, password, realm)
      return provider.test_password(username, password), true
    end
  }
  return new_sasl(module.host, profile)
end

function provider.users()
  local stmt, err = getsql("SELECT username FROM users WHERE locked_at IS NULL AND username != ''")
  if stmt then
    local next, state = stmt:rows(true)
    return function()
      for row in next, state do
        return row.username
      end
    end
  end
  return stmt, err
end


module:provides("auth", provider)

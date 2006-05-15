CREATE TABLE connections ("id" INTEGER PRIMARY KEY NOT NULL, "user_id" integer NOT NULL, "nick" varchar(40) NOT NULL, "realname" varchar(40) NOT NULL, "server" varchar(40) NOT NULL, "port" integer NOT NULL, "channel" varchar(80));
CREATE TABLE schema_info (version integer);
CREATE TABLE users ("id" INTEGER PRIMARY KEY NOT NULL, "login" varchar(40), "email" varchar(100), "crypted_password" varchar(40), "salt" varchar(40), "created_at" datetime, "updated_at" datetime);
INSERT INTO schema_info (version) VALUES (2)
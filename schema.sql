/* 
execute follow command.
$ sqlite3 database/chat_watch < schema.sql 
*/
CREATE TABLE chat (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL 
);
CREATE TABLE enter_log (
    id INTEGER PRIMARY KEY,
    nick_id INTEGER NOT NULL,
    room_id INTEGER NOT NULL,
    epoch INTEGER NOT NULL,

    FOREIGN KEY(nick_id) REFERENCES nick(id),
    FOREIGN KEY(room_id) REFERENCES room(id)
);
CREATE TABLE enter_range (
    id INTEGER PRIMARY KEY,
    nick_id INTEGER NOT NULL,
    room_id INTEGER NOT NULL,
    epoch1 INTEGER NOT NULL,
    epoch2 INTEGER NOT NULL,

    FOREIGN KEY(nick_id) REFERENCES nick(id),
    FOREIGN KEY(room_id) REFERENCES room(id)
);
CREATE TABLE nick (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL 
);
CREATE TABLE room (
    id INTEGER PRIMARY KEY,
    chat_id INTEGER NOT NULL,
    unique_key text NOT NULL,
    name TEXT NOT NULL,
    url  TEXT NOT NULL,

    FOREIGN KEY(chat_id) REFERENCES chat(id)
);
CREATE UNIQUE INDEX chat_name on chat(name);
CREATE INDEX enter_log_nick_id on enter_log(nick_id);
CREATE INDEX enter_log_room_id_epoch on enter_log(room_id, epoch);
CREATE INDEX enter_range_nick_id_epoch2 on enter_range(nick_id, epoch2);
CREATE INDEX enter_range_nick_id_room_id_epoch2 
       on enter_range(nick_id, room_id, epoch2);
CREATE INDEX enter_range_room_id_epoch1_epoch2 
       on enter_range(room_id, epoch1, epoch2);
CREATE UNIQUE INDEX nick_name on nick(name);
CREATE UNIQUE INDEX room_unique_key on room(unique_key);

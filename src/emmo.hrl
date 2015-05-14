
-record(character, {name = "", hp = 0, mp = 0, speed = 0, near_objects = [], bye = []}).
-record(loc, {map_id = 0, x = 0, y = 0}).


-record(account, {login_id = "", password = ""}).
-record(token, {expire_unixtime = 0, token = ""}).


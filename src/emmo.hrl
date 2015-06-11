
-record(character, {name = "", hp = 0, mp = 0, speed = 0, near_objects = [], bye = []}).
-record(loc, {map_id = 0, x = 0, y = 0}).


-record(account, {login_id = "", password = ""}).


-record(mqinfo, {
	server_ip = "",
	upstream_exchange = "",		%% From Client exchange name
	downstream_exchange = "",	%% To Client exchange name
	connection = "",
	uplink_channel = "",		%% From Client Channel
	downlink_channel = ""}).	%% To Client Channel

%% -record(mqinfo, {server_ip, connection, channel, exchange}).

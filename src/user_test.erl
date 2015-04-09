-module(user_test).


-export([test/0]).


test() ->
	{ok, UID, TOKEN1} = login("ichiro", "1111"),
	{ok, CID, TOKEN2} = online(UID, TOKEN1),
	{ok, CID, TOKEN3} = get(CID, TOKEN2),
	{ok, CID, TOKEN4} = talk(CID, TOKEN3, "hello world!"),
	{ok, CID, TOKEN5} = move_rel(CID, TOKEN4, 1, -1),
	{ok, CID, TOKEN6} = get(CID, TOKEN5),
	{ok, CID, TOKEN7} = offline(CID, TOKEN6),
	{ok, UID, TOKEN8} = logout(UID, TOKEN7).

	
login(Id, Pass) -> 0.

online(UID, TOKEN1) -> 0.
get(CID, TOKEN2) -> 0.
talk(CID, TOKEN3, Payload) -> 0.
move_rel(CID, TOKEN4, XDelta, YDelta) -> 0.
offline(CID, TOKEN6) -> 0.
logout(UID, TOKEN7) -> 0.





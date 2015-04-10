-module(user_test).


-export([test/0]).


test() ->
	{ok, UID, TOKEN1} = login("ichiro", "1111"),
	{ok, CID, TOKEN2} = online(UID, TOKEN1),
	{ok, List1, CID, TOKEN3} = get(CID, TOKEN2),
	{ok, CID, TOKEN4} = talk(CID, TOKEN3, "hello world!"),
	{ok, CID, TOKEN5} = move_rel(CID, TOKEN4, 1, -1),
	{ok, List2, CID, TOKEN6} = get(CID, TOKEN5),
	{ok, CID, TOKEN7} = offline(CID, TOKEN6),
	{ok, UID, TOKEN8} = logout(UID, TOKEN7).

	
login(Id, Pass) ->
	case emmo_auth:login(Id,Pass) of
		{ok, Cid, Token} -> {ok, Cid, Token};
		error -> error
	end.

online(UID, TOKEN1) ->
	pc_pool:online(UID, TOKEN1).

get(CID, TOKEN2) -> 2.

talk(CID, TOKEN3, Payload) ->
	chat_srv:broadcast(Payload).

move_rel(CID, TOKEN4, XDelta, YDelta) ->
	move_srv:move_rel(XDelta, YDelta).

offline(CID, TOKEN6) ->
	pc_pool:offline(CID, TOKEN6).

logout(UID, TOKEN7) ->
	emmo_auth:logout(UID,TOKEN7).





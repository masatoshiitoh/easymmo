-module(user_test).

-export([test/0]).

test() ->
	%% prepare test character.
	emmo_auth:test(),

	{ok, UID, TOKEN1} = login("ichiro", "1111"),
	case online(UID, TOKEN1) of
		{ok, CID, TOKEN2} ->

			{ok, List1, CID, TOKEN3} = get(CID, TOKEN2),
			{ok, CID, TOKEN4} = talk(CID, TOKEN3, "hello world!"),
			{ok, CID, TOKEN5} = move_rel(CID, TOKEN4, 1, -1),
			{ok, List2, CID, TOKEN6} = get(CID, TOKEN5),
			{ok, CID, TOKEN7} = offline(CID, TOKEN6),
			{ok, UID, TOKEN8} = logout(UID, TOKEN7);

		error ->
			io:format("create user~n"),
			{ok, CID2, TOKEN2N} = online_new_pc(UID, TOKEN1),

			{ok, List1, CID2, TOKEN3} = get(CID2, TOKEN2N),
			{ok, CID2, TOKEN4} = talk(CID2, TOKEN3, "hello world!"),
			{ok, CID2, TOKEN5} = move_rel(CID2, TOKEN4, 1, -1),
			{ok, List2, CID2, TOKEN6} = get(CID2, TOKEN5),
			{ok, CID2, TOKEN7} = offline(CID2, TOKEN6),
			{ok, UID, TOKEN8} = logout(UID, TOKEN7)
	end.

	
login(Id, Pass) ->
	case emmo_auth:login(Id,Pass) of
		{ok, Cid, Token} ->
			{ok, Cid, Token};
		error ->
			error
	end.

online(UID, TOKEN1) ->
	pc_pool:online(UID, TOKEN1).

get(CID, TOKEN2) -> {ok, [], CID, TOKEN2}.

talk(CID, TOKEN3, Payload) ->
	chat_srv:broadcast(CID, Payload),
	{ok, CID, TOKEN3}.

move_rel(CID, TOKEN4, XDelta, YDelta) ->
	move_srv:move_rel(CID, XDelta, YDelta),
	{ok, CID, TOKEN4}.

offline(CID, TOKEN6) ->
	pc_pool:offline(CID),
	{ok, CID, TOKEN6}.

logout(UID, TOKEN7) ->
	emmo_auth:logout(UID,TOKEN7),
	{ok, UID, TOKEN7}.


online_new_pc(UID, TOKEN1) ->
	{ok, Cid} = pc_pool:add(),
	{ok, Cid, BinNewToken} = pc_pool:get_token(Cid),
	A = pc_pool:online(Cid, BinNewToken),
	{A, Cid, BinNewToken}.
	




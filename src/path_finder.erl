%%
%%


-module(path_finder).
-behaviour(gen_server).

-export([make_map_from_arraymap/1, arraymap/0]).
-export([lookup_path/3]).
-export([start_link/0, stop/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-export([test/0]).

test() ->
	lookup_path({map_id, "hibari", 1}, {pos, 1,1 }, {pos, 8,8}).

start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

stop() ->
	gen_server:call(?MODULE, stop).

lookup_path({map_id, SvId, MapId}, StartPos, DestPos) ->
	gen_server:call(?MODULE, {lookup, {map_id, SvId, MapId}, StartPos, DestPos}).

init([]) ->
	MapId1 = {map_id, "hibari", 1},
	MapValue1 = make_entry_from_arraymap(arraymap()),
	{ok,
		dict:from_list([{MapId1,MapValue1}])}.

% How to use multiple maps:
%
% 1. Hold multiple G/Map/PosList/VertexDict/RevDict sets.
% 2. Hold one G, multiple Map/PosList/VertexDict/RevDict sets.

make_entry_from_arraymap(ArrayMap) ->
	G = digraph:new(),	% setup digraph.
	Map = make_map_from_arraymap(ArrayMap),	% Make an array holds map tupples.
	{G, PList } = make_all_vertex(Map,G),	% map tupples to vertex.  PList holds {Pos, Vertex} tupple.
	VertexDict = dict:from_list(PList),	% dictionary for pos tupple - vertex reference.
	make_all_edges(Map, G, VertexDict, PList),	% fill connected path by Map into G
	RevDict = dict:from_list([{V,P} || {P,V} <- dict:to_list(VertexDict)]),	% dictionary for vertex - pos reference.
	{map, Map, G, PList, VertexDict, RevDict}.

handle_call({lookup, MapId, StartPos, DestPos}, _From, Maps) ->
	{ok, {map, Map, G, PList, VertexDict, RevDict}} = dict:find(MapId, Maps),
	{reply,
		{ok,
			pick_path(G, VertexDict, RevDict, StartPos, DestPos)},
			Maps};

handle_call(stop, _From, State) ->
	{stop, normal, stopped, State}.

handle_cast(_Msg, State) -> {noreply, State}.
handle_info(_Info, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.
code_change(_OldVsn, State, _Extra) -> {ok, State}.


% path top is current position ( not a first waypoint! )
pick_path(G, VertexDict, RevDict, StartPos, DestPos) ->
	{ok, StartVertex} = dict:find(StartPos, VertexDict),
	{ok, DestVertex} = dict:find(DestPos, VertexDict),
	Path = digraph:get_short_path(G, StartVertex, DestVertex),
	case is_list(Path) of
		true ->
			Result = lists:map(fun(X) -> {ok, P} = dict:find(X, RevDict), P end, Path);
		false ->
			Result = []
	end,
	% io:format("path finder pick_path: ~p~n", [Result]),
	Result.

make_all_edges(Map, G, VertexDict, PosList) ->
	lists:map(fun(X) -> {P,_V} = X, make_edges_for_one_cell(Map, G, VertexDict, P) end, PosList).

make_edges_for_one_cell(Map, G, VertexDict, Pos) ->
	NeighborList = neighbors(Pos),
	% io:format("make_edges_for_one_cell ~p~n", [NeighborList]),
	lists:map(fun(X) -> make_edge(Map, G, VertexDict, Pos, X) end, NeighborList).

make_edge(Map, G, VertexDict, S, D) ->
	StartPosValue = get_value(S, Map),
	DestPosValue = get_value(D, Map),
	if
		(StartPosValue == 0) and ( DestPosValue == 0) ->
			{ok, StartVertex} = dict:find(S, VertexDict),
			{ok, DestVertex} = dict:find(D, VertexDict),
			Result = digraph:add_edge(G, StartVertex, DestVertex),
			%io:format("make_edge ~p to ~p  ", [S, D]),
			%io:format("ok with ~p~n", [Result]),
			Result ;
		true ->
			0
	end.


make_all_vertex(Map) ->
	{map, _SizeX, _SizeY, _Array} = Map,
	PosList = get_all_pos(Map),
	G = digraph:new(),
	PosList2 = [{P, digraph:add_vertex(G)} || P <- PosList],
	{G, PosList2}.

make_all_vertex(Map, G) ->
	{map, _SizeX, _SizeY, _Array} = Map,
	PosList = get_all_pos(Map),
	PosList2 = [{P, digraph:add_vertex(G)} || P <- PosList],
	{G, PosList2}.




get_all_pos(Map) ->
	{map, SizeX, SizeY, _} = Map,
	lists:flatten(
		lists:map(
			fun(Y) -> lists:map(fun(X) -> {pos, X, Y} end,lists:seq(0, SizeX - 1)) end,
			lists:seq(0, SizeY - 1))).

neighbors({pos, X, Y}) ->
	[{pos, X + DX, Y + DY} || {pos, DX, DY} <- get_eight_dir()].

get_eight_dir() -> [
	{pos, -1,-1},{pos, 0,-1},{pos, 1,-1},
	{pos, -1, 0},            {pos, 1, 0},
	{pos, -1, 1},{pos, 0, 1},{pos, 1, 1}
].

arraymap()-> {arraymap,
10, %% size X
10, %% size Y
[
	[1,1,1,1,1,1,1,1,1,1],
	[1,0,0,0,0,0,0,0,0,1],
	[1,0,1,0,0,0,0,0,0,1],
	[1,0,1,0,0,0,0,0,0,1],
	[1,0,1,0,0,0,0,0,0,1],
	[1,0,1,1,1,0,1,1,1,1],
	[1,0,1,0,0,0,0,0,0,1],
	[1,0,1,0,0,0,0,0,0,1],
	[1,0,1,0,0,0,0,0,0,1],
	[1,1,1,1,1,1,1,1,1,1]
]}.

get_width(Map) ->
	{map, SizeX, _SizeY, _} = Map,
	SizeX.

get_height(Map) ->
	{map, _SizeX, SizeY, _} = Map,
	SizeY.

get_value({pos, X, Y}, Map) ->
	{map, SizeX, SizeY, Array} = Map,
	if
		(X >= 0) and (X < SizeX) and (Y >= 0) and (Y < SizeY)
			-> array:get((X + Y * SizeX), Array);
		true
			->void
	end.

get_value(X, Y, Map) ->
	{map, SizeX, SizeY, Array} = Map,
	if
		(X >= 0) and (X < SizeX) and (Y >= 0) and (Y < SizeY)
			-> array:get((X + Y * SizeX), Array);
		true
			->void
	end.

make_map_from_arraymap({arraymap, SizeX, SizeY, Arraymap}) ->
	{map, SizeX, SizeY, array:from_list(lists:flatten(Arraymap))}.



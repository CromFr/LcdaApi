import vibe.data.json;


class Config {
	this(){
		table = Json.emptyObject;
	}
	this(Json config){
		table = config;
	}
	this(in string config){
		table = parseJsonString(config);
	}

	///Overrides one config with another.
	/// - Values and arrays are overridden
	/// - Objects are overridden member by member
	/// - If sth is in newConfig and not in the current config, it will be added
	void overrideConfig(in Json newConfig){
		import std.algorithm : each;

		void ovr(in Json fromNode, ref Json toNode){

			//if(fromNode.type != toNode.type)

			switch(fromNode.type){
				case Json.Type.object:
					if(toNode.type != Json.Type.object)
						toNode = Json.emptyObject;

					//foreach()

					foreach(key, ref from ; fromNode.get!(Json[string])){
						ovr(from, toNode[key]);
					}
					//fromNode.each!((string key, ref from){
					//		ovr(from, toNode[key]);
					//	});
					return;

				case Json.Type.null_, Json.Type.undefined:
					return;

				default:
					toNode = fromNode.clone;
					return;
			}
		}

		ovr(newConfig, table);
	}

	void overrideConfig(in string newConfig){
		overrideConfig(parseJsonString(newConfig));
	}




	alias table this;
	Json table;
}


unittest{
	import std.stdio;
	import std.conv;
	import std.algorithm;
	writeln(__MODULE__);

	enum baseConfig = `
		{
			"amiperfect": true,
			"array": [1, 2, 3],
			"array2": [666, 33],
			"object": {
				"name": "Custom object",
				"id": 42,
				"age": {
					"years": 2,
					"days": 256
				}
			}
		}
		`;

	enum ovrConfig = `
		{
			"array": [6, 7, 8],
			"array2": [],
			"object": {
				"id": 46,
				"age": {
					"days": 257
				}
			},
			"amiperfect": false,
			"addon": "hello",
			"addon_object": {
				"a": 5,
				"b": 42
			}
		}
		`;

	auto cfg = new Config(baseConfig);
	cfg.overrideConfig(ovrConfig);

	assert(cfg["amiperfect"] == false);
	assert(cfg["array"][].equal([6,7,8]));
	assert(cfg["array2"][].equal(cast(int[])[]));
	assert(cfg["object"] == Json([
		"name": Json("Custom object"),
		"id": Json(46),
		"age": Json(["years": Json(2), "days": Json(257)])
	]));
	assert(cfg["addon"] == "hello");
	assert(cfg["addon_object"] == Json(["a": Json(5), "b": Json(42)]));

}
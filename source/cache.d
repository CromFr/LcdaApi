module cache;

import std.traits;
import std.datetime: SysTime, Clock;

class Cache {
static:

	auto ref T get(T)(in string name, bool function(in T cachedObject, SysTime created) isExpired, T delegate() ctor)
	if(is(T: CopyConstness!(T, Object))){

		static if(is(T == const) || is(T == immutable))
			alias cache = sharedCache;
		else
			alias cache = tlsCache;

		auto cacheTable = typeid(T) in cache;
		if(!cacheTable){
			cache[typeid(T)] = null;
			cacheTable = typeid(T) in cache;
		}

		auto cacheEntry = name in *cacheTable;
		if(cacheEntry && !isExpired(cast(T)cacheEntry.data, cacheEntry.created)){
			// return existing
			return cast(T)cacheEntry.data;
		}
		// Insert new one
		return cast(T)
			((*cacheTable)[name] = CacheEntry(
				cast(Object)ctor(),
				cast(bool function(in Object, SysTime))isExpired,
				Clock.currTime())
			).data;
	}

	auto ref T get(T)(in string name, bool function(in T cachedObject, SysTime created) isExpired, T delegate() ctor)
	if(!is(T: CopyConstness!(T, Object))){

		alias Type = CopyConstness!(T, Wrapper!T);
		return get!Type(
			name,
			function(in Type wrap, SysTime created){ return wrap.isExpired(wrap.inner, created); },
			() => new Type(ctor(), isExpired)
		).inner;
	}

	/// Warning: the retrieved object must exist
	auto ref T get(T)(in string name) inout{
		static if(is(T == const) || is(T == immutable))
			alias cache = sharedCache;
		else
			alias cache = tlsCache;
		return cache[typeid(T)][name];
	}

	/// Reduce cache size by removing expired cache objects
	void reduce(){
		foreach(ref cache ; [tlsCache, sharedCache]){
			foreach(ref table ; cache){
				string[] keysToRemove;
				foreach(ref name, ref value ; table){
					if(value.isExpired(value.data, value.created)){
						keysToRemove ~= name;
					}
				}
				foreach(ref key ; keysToRemove)
					table.remove(key);
			}
		}

	}

private:

	CacheEntryTable[TypeInfo] tlsCache;
	__gshared CacheEntryTable[TypeInfo] sharedCache;

	alias CacheEntryTable = CacheEntry[string];
	static struct CacheEntry{
		Object data;
		bool function(in Object, SysTime) isExpired;
		SysTime created;
	}

	static class Wrapper(T){
		this(T inner, bool function(in T, SysTime) isExpired){
			this.inner = inner;
			this.isExpired = isExpired;
		}

		T inner;
		bool function(in T, SysTime) isExpired;
	}

}

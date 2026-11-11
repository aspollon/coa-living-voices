#ifndef UI_CLIENT_PLUGINS_H
#define UI_CLIENT_PLUGINS_H

#include <cstddef>

struct lua_State;

// What a plugin DLL in Plugins\ gets: the Lua calls it may make, by pointer, so it needs no Lua of its own.
struct CoaPluginLua {
    int version;                    // CoA64_PLUGIN_VERSION
    int globalsIndex;               // LUA_GLOBALSINDEX
    const char* gameDir;            // the folder of the exe, with a trailing backslash
    int (*gettop)(lua_State* L);
    int (*type)(lua_State* L, int index);
    void (*pushnil)(lua_State* L);
    void (*pushnumber)(lua_State* L, double n);
    void (*pushstring)(lua_State* L, const char* s);
    void (*pushboolean)(lua_State* L, int b);
    void (*pushcclosure)(lua_State* L, int (*fn)(lua_State*), int n);
    void (*createtable)(lua_State* L, int narr, int nrec);
    void (*setfield)(lua_State* L, int index, const char* key);
    const char* (*checklstring)(lua_State* L, int index, size_t* len);
    double (*checknumber)(lua_State* L, int index);
    const char* (*tolstring)(lua_State* L, int index, size_t* len);
    double (*tonumber)(lua_State* L, int index);
};

#define CoA64_PLUGIN_VERSION 1

// A plugin exports: extern "C" __declspec(dllexport) void CoaPlugin_OpenLua(const CoaPluginLua* api, lua_State* L);
// called each time the in-game Lua state is built (login, /reload), before add-ons load.
void ClientPluginsOpenLua(lua_State* L);

#endif

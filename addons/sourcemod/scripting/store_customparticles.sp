#include <sourcemod> 
#include <sdktools>
#include <sdkhooks>
#include <store> 
#include <clientprefs>
#include <zephstocks> 

#pragma semicolon 1
#pragma newdecls required

enum CustomParticles
{
  String:szParticleName[PLATFORM_MAX_PATH],
  String:szEffectName[PLATFORM_MAX_PATH],
  Float:fPosition[3],
  iCacheID,
}

int g_eCustomParticles[STORE_MAX_ITEMS][CustomParticles];
int g_iCustomParticless = 0;
int g_unClientParticle[MAXPLAYERS+1]={INVALID_ENT_REFERENCE,...};
int g_unSelectedParticle[MAXPLAYERS+1]={-1,...};
bool g_bHide[MAXPLAYERS+1]={false,...};
bool g_bHideSelf[MAXPLAYERS+1]={false,...};
Handle c_ShowParticles = null;
Handle c_ShowSelfParticles = null;

public Plugin myinfo =
{
  name = "Custom Particles",
  author = "Invex | Byte",
  description = "Add Custom Particles to Zephyrus Store",
  version = "1.00",
  url = "http://www.invexgaming.com.au"
}

public void OnPluginStart() 
{
  Store_RegisterHandler("CustomParticles", "effectname", CustomParticlesOnMapStart, CustomParticlesReset, CustomParticlesConfig, CustomParticlesEquip, CustomParticlesRemove, true);
  
  RegConsoleCmd("sm_toggleparticles", Command_Toggle_Particles, "Turn custom particles visibility ON or OFF");
  RegConsoleCmd("sm_toggleselfparticles", Command_Toggle_Self_Particles, "Turn your particles visibility ON or OFF");
  
  //Register cookie
  c_ShowParticles = RegClientCookie("ShowParticles", "Whether to show client custom particles or not", CookieAccess_Public);
  c_ShowSelfParticles = RegClientCookie("ShowSelfParticles", "Whether to show client self custom particles or not", CookieAccess_Public);
  
  HookEvent("player_spawn", Particles_PlayerSpawn);
  HookEvent("player_death", Particles_PlayerDeath);  
} 

public void CustomParticlesOnMapStart() 
{
  for(int i=0;i<g_iCustomParticless;++i)
  {
    g_eCustomParticles[i][iCacheID] = PrecacheGeneric(g_eCustomParticles[i][szParticleName], true);
    Downloader_AddFileToDownloadsTable(g_eCustomParticles[i][szParticleName]);
  }
} 

public void OnMapStart()
{
  if(g_iCustomParticless > 0)
  {
    for(int i=0;i<g_iCustomParticless;++i)
    {
      if(!IsModelPrecached(g_eCustomParticles[i][szParticleName]))
      {  
        g_eCustomParticles[i][iCacheID] = PrecacheGeneric(g_eCustomParticles[i][szParticleName], true);
        Downloader_AddFileToDownloadsTable(g_eCustomParticles[i][szParticleName]);
      }
    }
  }
} 

public void CustomParticlesReset() 
{ 
  g_iCustomParticless = 0; 
}

public int CustomParticlesConfig(Handle &kv, int itemid) 
{
  float m_fTemp[3];
  
  Store_SetDataIndex(itemid, g_iCustomParticless);
  KvGetString(kv, "particlename", g_eCustomParticles[g_iCustomParticless][szParticleName], PLATFORM_MAX_PATH);
  KvGetString(kv, "effectname", g_eCustomParticles[g_iCustomParticless][szEffectName], PLATFORM_MAX_PATH);
  KvGetVector(kv, "position", m_fTemp);
  
  g_eCustomParticles[g_iCustomParticless][fPosition] = m_fTemp;
  
  ++g_iCustomParticless;
  
  for(int i=0;i<g_iCustomParticless;++i)
  {
    if(!IsModelPrecached(g_eCustomParticles[i][szParticleName]))
    {
      g_eCustomParticles[i][iCacheID] = PrecacheGeneric(g_eCustomParticles[i][szParticleName], true);
      Downloader_AddFileToDownloadsTable(g_eCustomParticles[i][szParticleName]);
    }
    return true;
  }

  return false;
}

public int CustomParticlesEquip(int client, int id)
{
  g_unSelectedParticle[client]=Store_GetDataIndex(id);
  
  RemoveCustomParticle(client);
  CreateCustomParticle(client);  
  
  return 0;
}

public Action Timer_CreateParticle(Handle timer, any client)
{
  if(IsValidClient(client))
    CreateCustomParticle(client);    
}

public int CustomParticlesRemove(int client, int id) 
{  
  g_unSelectedParticle[client]=-1;  
  RemoveCustomParticle(client);
  return 0;
}

public void OnClientPutInServer(int client)
{
  g_unSelectedParticle[client]=-1;
}

public void OnClientDisconnect(int client)
{
  g_unSelectedParticle[client]=-1;
}

void CreateCustomParticle(int client)
{  
  if(!IsValidClient(client))
    return;
    
  if(g_unSelectedParticle[client] == -1)
    return;  
  
  RemoveCustomParticle(client);
  
  if(!IsPlayerAlive(client))
    return;
  
  if(g_unClientParticle[client] != INVALID_ENT_REFERENCE)
    return;  
      
  int m_iData = g_unSelectedParticle[client];
  
  int m_unEnt = CreateEntityByName("info_particle_system");
  
  if (IsValidEntity(m_unEnt))
  {
    DispatchKeyValue(m_unEnt, "start_active", "1");
    DispatchKeyValue(m_unEnt, "effect_name", g_eCustomParticles[m_iData][szEffectName]);
    DispatchSpawn(m_unEnt);  
    
    float m_flPosition[3];
    GetClientAbsOrigin(client, m_flPosition);
    float m_fOffset[3];
    m_fOffset[0] = g_eCustomParticles[m_iData][fPosition][0];
    m_fOffset[1] = g_eCustomParticles[m_iData][fPosition][1];
    m_fOffset[2] = g_eCustomParticles[m_iData][fPosition][2];
    m_flPosition[0] = (m_flPosition[0] + m_fOffset[0]);
    m_flPosition[1] = (m_flPosition[1] + m_fOffset[1]);
    m_flPosition[2] = (m_flPosition[2] + m_fOffset[2]);

    TeleportEntity(m_unEnt, m_flPosition, NULL_VECTOR, NULL_VECTOR);
     
    SetVariantString("!activator");
    AcceptEntityInput(m_unEnt, "SetParent", client, m_unEnt, 0);
    
    ActivateEntity(m_unEnt);
    
    g_unClientParticle[client] = EntIndexToEntRef(m_unEnt);
    
    SetEdictFlags(m_unEnt, GetEdictFlags(m_unEnt)&(~FL_EDICT_ALWAYS));
    SDKHookEx(m_unEnt, SDKHook_SetTransmit, Hook_ParticleSetTransmit);
  }
}

void RemoveCustomParticle(int client)
{
  if(g_unClientParticle[client] == INVALID_ENT_REFERENCE)
    return;

  int m_unEnt = EntRefToEntIndex(g_unClientParticle[client]);
  g_unClientParticle[client] = INVALID_ENT_REFERENCE;
  if(m_unEnt == INVALID_ENT_REFERENCE)
    return;

  AcceptEntityInput(m_unEnt, "Kill");  
}

public Action Particles_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(GetEventInt(event, "userid"));
  if(!IsClientInGame(client) || !IsPlayerAlive(client) || !(2<=GetClientTeam(client)<=3))
    return Plugin_Continue;
  
  if(IsValidClient(client))
    CreateTimer(0.75, Timer_CreateParticle, client);

  return Plugin_Continue;    
}
public Action Particles_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(GetEventInt(event, "userid"));
  
  if(IsValidClient(client))
    RemoveCustomParticle(client);
  
  return Plugin_Continue;
}

bool IsValidClient(int client) 
{
  if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) || IsFakeClient(client) || IsClientSourceTV(client)) 
    return false; 
   
  return true; 
}

public void OnClientCookiesCached(int client)
{
  char showParticlesPref[3];
  char showSelfParticlesPref[3];
  GetClientCookie(client, c_ShowParticles, showParticlesPref, sizeof(showParticlesPref));
  GetClientCookie(client, c_ShowSelfParticles, showSelfParticlesPref, sizeof(showSelfParticlesPref));
  
  if (StrEqual(showParticlesPref, "0")) {
    g_bHide[client] = true;
  } else { //For 1 and other junk values
    g_bHide[client] = false;
  }
  
  if (StrEqual(showSelfParticlesPref, "0")) {
    g_bHideSelf[client] = true;
  } else { //For 1 and other junk values
    g_bHideSelf[client] = false;
  }
}

public Action Command_Toggle_Particles(int client, int args)
{
  if (!IsValidClient(client)) {
    ReplyToCommand(client, "[STORE] Your client cannot turn off particles.");
    return Plugin_Handled;
  }
  
  //Toggle
  g_bHide[client] = !g_bHide[client];
  
  if (AreClientCookiesCached(client)) {
    SetClientCookie(client, c_ShowParticles, g_bHide[client] ? "0" : "1");
  }
 
  ReplyToCommand(client, "[STORE] Particles have now been toggled: %s", g_bHide[client] ? "OFF" : "ON");
 
  return Plugin_Handled;
}

public Action Command_Toggle_Self_Particles(int client, int args)
{
  if (!IsValidClient(client)) {
    ReplyToCommand(client, "[STORE] Your client cannot turn off self particles.");
    return Plugin_Handled;
  }
  
  //Toggle
  g_bHideSelf[client] = !g_bHideSelf[client];
  
  if (AreClientCookiesCached(client)) {
    SetClientCookie(client, c_ShowSelfParticles, g_bHideSelf[client] ? "0" : "1");
  }
 
  ReplyToCommand(client, "[STORE] Self particles have now been toggled: %s", g_bHideSelf[client] ? "OFF" : "ON");
 
  return Plugin_Handled;
}

void setEdictFlags(int edict)
{
  if (GetEdictFlags(edict) & FL_EDICT_ALWAYS)
    SetEdictFlags(edict, (GetEdictFlags(edict) ^ FL_EDICT_ALWAYS));
} 

public Action Hook_ParticleSetTransmit(int entity, int client)
{
  setEdictFlags(entity);
  
  if (g_bHide[client])
    return Plugin_Handled;
   
  int m_unEnt = EntRefToEntIndex(g_unClientParticle[client]);
  if (g_bHideSelf[client] && entity == m_unEnt)
    return Plugin_Handled;
    
  return Plugin_Continue;
}

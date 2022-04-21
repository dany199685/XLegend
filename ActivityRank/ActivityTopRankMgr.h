#pragma once

#include "WorldServerPCH.h"
#include "AllObjects/DataType/TypeActivity.h"

namespace lapis {

class CCharacter;
struct SLeaderboardInfo;

class CTopRankInterface
{
public:
  virtual Int64 GetScore () = 0;
  virtual TScheduleTID GetScheduleID () = 0;
};

class CGuildActivityRank
{
public:
  void Update (CCharacter* _ch, CTopRankInterface* _rankInterface, bool _bReplace = true);
  void Remove (TCharID _ch_id);
  void Refresh ();
  Int64 GetTotalScore () const;
  
public:
  UInt m_nVersion;
  std::list<SLeaderboardInfo*> m_Rank;

protected:
  std::map<TCharID, SLeaderboardInfo*> m_UnorderRank;
};

class CActivityTopRankMgr {
public:
  CActivityTopRankMgr (TWarID _warID);

  void Initialize ();
  void Finalize ();

  CGuildActivityRank* RegistTopRank (EActivityScheduleType _type, TGuildID _guildID, TScheduleTID _scheduleID);
  
  bool UpdateTopRank (EActivityScheduleType _type, CCharacter* _ch, CTopRankInterface* _rankInterface);
  void RefreshRank (EActivityScheduleType _type, TGuildID _guildID, TScheduleTID _scheduleID);
  
  CGuildActivityRank* QueryTopRank (EActivityScheduleType _type, TGuildID _guildID, TScheduleTID _scheduleID);
  UInt QueryTopRank (EActivityScheduleType _type, TGuildID _guildID, TScheduleTID _scheduleId, UInt _version, UShort _step, std::vector <SLeaderboardInfo*>& _result);
  Int64 QueryTotalScore (EActivityScheduleType _type, TGuildID _guildID, TScheduleTID _scheduleId);

  bool RemoveRank (EActivityScheduleType _type, TGuildID _guildID);
  bool RemoveRank (EActivityScheduleType _type, TScheduleTID _scheduleID);
  bool RemoveMemberRank (EActivityScheduleType _type, TCharID _ch_id, TGuildID _guildId);

  static UShort QueryStepAmount;
  static UShort QueryMaxAmount;
public:
  TWarID m_nWarID;

protected:
  std::map<TGuildID, std::map<TScheduleTID, CGuildActivityRank*> >* GetActivityRank (EActivityScheduleType _type);

  std::map<TGuildID, std::map<TScheduleTID, CGuildActivityRank*> > AllDATopRank;
};

}
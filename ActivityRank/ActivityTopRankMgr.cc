#include "ActivityTopRankMgr.h"
#include "LifeEntityMgr.h"
#include "GuildMgr.h"
#include "ParameterMgr.h"
#include "AllObjects/Character.h"
#include "AllObjects/DataType/TypeLeaderboard.h"
#include "AllObjects/Guild.h"

namespace lapis {

void CGuildActivityRank::Update (CCharacter* _ch, CTopRankInterface* _rankInterface, bool _bReplace)
{
  TCharID ch_id = _ch->GetLifeID ();
  if (m_UnorderRank.find (ch_id) != m_UnorderRank.end ()) {
    if (_bReplace) {
      m_UnorderRank[ch_id]->Score = _rankInterface->GetScore ();
    }
    else {
      m_UnorderRank[ch_id]->Score += _rankInterface->GetScore ();
    }
  }
  else {
    SLeaderboardInfo* rank_info = LP_NEW (SLeaderboardInfo (_ch->GetLifeID ()));
    rank_info->Icon = _ch->CharData->Appearance.Value;
    rank_info->Title = _ch->GetName ();
    rank_info->Frame = _ch->CharData->FrameID;
    rank_info->Score = _rankInterface->GetScore ();
    if (CGuild* guild = CGuildMgr::GetGuild (_ch->CharData->GuildID))
      rank_info->SubTitle = LPrintf ("TextIndex|48|%s|%s|", guild->Tag.c_str (), guild->Name.c_str ());

    m_UnorderRank.emplace (ch_id, rank_info);
  }
}

void CGuildActivityRank::Remove (TCharID _ch_id)
{
  int removed_rank = -1;
  for (std::list<SLeaderboardInfo*>::iterator it_rank = m_Rank.begin () ;it_rank != m_Rank.end ();) {
    if ((*it_rank)->Key == _ch_id) {
      removed_rank = (*it_rank)->Rank;
      it_rank = m_Rank.erase (it_rank);
    }
    else {
      // Rank在移除者後面的排名通通往前遞增
      if (removed_rank > 0 && (*it_rank)->Rank < removed_rank) {
        (*it_rank)->Rank++;
        (*it_rank)->RankDiff = 1;
      }
      it_rank++;
    }
  }

  auto it = m_UnorderRank.find (_ch_id);
  if (it != m_UnorderRank.end ()) {
    LP_SAFE_DELETE (it->second);
    m_UnorderRank.erase (it);
  }
}

void CGuildActivityRank::Refresh ()
{
  m_Rank.clear ();

  // 依照分數進行先後排序
  for (const auto& it_score:m_UnorderRank) {
    std::list<SLeaderboardInfo*>::iterator it_pos = m_Rank.begin ();
    for (; it_pos != m_Rank.end (); ++it_pos) {
      if (it_score.second->Score > (*it_pos)->Score) {
        break;
      }
    }

    m_Rank.insert (it_pos, it_score.second);
  }

  // 更新Rank && RankDiff
  int old_rank;
  std::list<SLeaderboardInfo*>::iterator it_rank = m_Rank.begin ();
  for (; it_rank != m_Rank.end (); ++it_rank) {
    old_rank = (*it_rank)->Rank;
    (*it_rank)->Rank = std::distance (m_Rank.begin (), it_rank) + 1; // Begin from 0.
    (*it_rank)->RankDiff = old_rank - (*it_rank)->Rank;
  }

  m_nVersion = ICurrentTime::GetSec ();
}

Int64 CGuildActivityRank::GetTotalScore () const
{
  Int64 score = 0;
  for (const auto& it:m_Rank) {
    score += (*it).Score;
  }
  return score;
}

void CActivityTopRankMgr::Initialize ()
{
  QueryStepAmount = CParameterMgr::GetParameter (eFP_3151_ActivityRankShowMaxOneTime);
  QueryMaxAmount = CParameterMgr::GetParameter (eFP_3154_ActivityRankShowMax);
}

void CActivityTopRankMgr::Finalize ()
{
  for (auto& it:AllDATopRank) {
    StdMapDeleteContent (it.second);
  }
  AllDATopRank.clear ();
}

CActivityTopRankMgr::CActivityTopRankMgr (TWarID _warID)
  : m_nWarID (_warID)
{}

CGuildActivityRank* CActivityTopRankMgr::RegistTopRank (EActivityScheduleType _type, TGuildID _guildID, TScheduleTID _scheduleID)
{
  CGuildActivityRank* pkRank = NULL;
  std::map<TGuildID, std::map<TScheduleTID, CGuildActivityRank*> >* pkActivityRank = GetActivityRank (_type);
  if (pkActivityRank == NULL)
    return pkRank;

  std::map<TGuildID, std::map<TScheduleTID, CGuildActivityRank*> >& activity_rank = *pkActivityRank;
  if (activity_rank.find (_guildID) != activity_rank.end ()) {
    if (activity_rank[_guildID].find (_scheduleID) == activity_rank[_guildID].end ()) {
      pkRank = LP_NEW (CGuildActivityRank ());
      activity_rank[_guildID].emplace (_scheduleID, pkRank);
      LP_ACTIVITYLOG_DEBUG_NO_LEVEL (m_nWarID, NULL, "[CActivityTopRankMgr::RegistTopRank] Regists activity[%d] rank by guildID[%lld].", _scheduleID, _guildID);
    }
    else {
      pkRank = activity_rank[_guildID][_scheduleID];
    }
  }
  else {
    std::map<TScheduleTID, CGuildActivityRank*> rank_data;
    pkRank = LP_NEW (CGuildActivityRank ());
    rank_data.emplace (_scheduleID, pkRank);
    activity_rank.emplace (_guildID, rank_data);
    LP_ACTIVITYLOG_DEBUG_NO_LEVEL (m_nWarID, NULL, "[CActivityTopRankMgr::RegistTopRank] Regists activity[%d] rank by guildID[%lld].", _scheduleID, _guildID);
  }
  return pkRank;
}

bool CActivityTopRankMgr::UpdateTopRank (EActivityScheduleType _type, CCharacter* _ch, CTopRankInterface* _rankInterface)
{
  std::map<TGuildID, std::map<TScheduleTID, CGuildActivityRank*> >* pkActivityRank = GetActivityRank (_type);
  if (pkActivityRank == NULL)
    return false;

  CGuildActivityRank* pkRank = NULL;
  std::map<TGuildID, std::map<TScheduleTID, CGuildActivityRank*> >& activity_rank = *pkActivityRank;
  if (activity_rank.find (_ch->CharData->GuildID) != activity_rank.end ()) {
    if (activity_rank[_ch->CharData->GuildID].find (_rankInterface->GetScheduleID ()) != activity_rank[_ch->CharData->GuildID].end ()) {
      pkRank = activity_rank[_ch->CharData->GuildID][_rankInterface->GetScheduleID ()];
    }
  }

  if (pkRank) {
    pkRank->Update (_ch, _rankInterface);
    return true;
  }
  else {
    return false;
  }
}

void CActivityTopRankMgr::RefreshRank (EActivityScheduleType _type, TGuildID _guildID, TScheduleTID _scheduleID)
{
  std::map<TGuildID, std::map<TScheduleTID, CGuildActivityRank*> >* pkActivityRank = GetActivityRank (_type);
  if (pkActivityRank == NULL)
    return;

  std::map<TGuildID, std::map<TScheduleTID, CGuildActivityRank*> >& activity_rank = *pkActivityRank;
  if (activity_rank.find (_guildID) != activity_rank.end ()) {
    if (activity_rank[_guildID].find (_scheduleID) != activity_rank[_guildID].end ()) {
      activity_rank[_guildID][_scheduleID]->Refresh ();
    }
  }
}

UShort CActivityTopRankMgr::QueryStepAmount = 0;
UShort CActivityTopRankMgr::QueryMaxAmount = 0;

CGuildActivityRank* CActivityTopRankMgr::QueryTopRank (EActivityScheduleType _type, TGuildID _guildID, TScheduleTID _scheduleID)
{
  std::map<TGuildID, std::map<TScheduleTID, CGuildActivityRank*> >* pkActivityRank = GetActivityRank (_type);
  if (pkActivityRank == NULL)
    return NULL;

  std::map<TGuildID, std::map<TScheduleTID, CGuildActivityRank*> >& activity_rank = *pkActivityRank;
  if (activity_rank.find (_guildID) != activity_rank.end ()) {
    if (activity_rank[_guildID].find (_scheduleID) != activity_rank[_guildID].end ()) {
      return activity_rank[_guildID][_scheduleID];
    }
  }
  return NULL;
}

UInt CActivityTopRankMgr::QueryTopRank (EActivityScheduleType _type, TGuildID _guildID, TScheduleTID _scheduleId, UInt _version, UShort _step, std::vector <SLeaderboardInfo*>& _result)
{
  CGuildActivityRank* pkRank = QueryTopRank (_type, _guildID, _scheduleId);
  if (pkRank == NULL)
    return 0;
  
  if (_version == pkRank->m_nVersion)
		return 0;

  UShort size = pkRank->m_Rank.size ();
  UShort step_start = _step * QueryStepAmount;
  if (step_start >= QueryMaxAmount || step_start >= size)
    return 0;

  size_t i = 0;
  size = std::min<UShort> (size, step_start + QueryStepAmount);
  std::list<SLeaderboardInfo*>::iterator it_rank = pkRank->m_Rank.begin ();
  for (; it_rank != pkRank->m_Rank.end () && i < size; ++it_rank) {
    if (i < step_start)
      continue;
    
    _result.push_back (*it_rank);
    ++i;
  }

  return pkRank->m_nVersion;
}

Int64 CActivityTopRankMgr::QueryTotalScore (EActivityScheduleType _type, TGuildID _guildID, TScheduleTID _scheduleId)
{
  const CGuildActivityRank* pkRank = QueryTopRank (_type, _guildID, _scheduleId);
  if (!pkRank)
    return 0;
  
  return pkRank->GetTotalScore ();
}

bool CActivityTopRankMgr::RemoveRank (EActivityScheduleType _type, TGuildID _guildID)
{
  std::map<TGuildID, std::map<TScheduleTID, CGuildActivityRank*> >* pkActivityRank = GetActivityRank (_type);
  if (pkActivityRank == NULL)
    return false;

  std::map<TGuildID, std::map<TScheduleTID, CGuildActivityRank*> >& activity_rank = *pkActivityRank;
  std::map<TGuildID, std::map<TScheduleTID, CGuildActivityRank*> >::iterator it = activity_rank.find (_guildID);
  if (it == activity_rank.end ())
    return false;
  
  StdMapDeleteContent (it->second);
  activity_rank.erase (it);

  return true;
}

bool CActivityTopRankMgr::RemoveRank (EActivityScheduleType _type, TScheduleTID _scheduleID)
{
  std::map<TGuildID, std::map<TScheduleTID, CGuildActivityRank*> >* pkActivityRank = GetActivityRank (_type);
  if (pkActivityRank == NULL)
    return false;

  std::map<TGuildID, std::map<TScheduleTID, CGuildActivityRank*> >& activity_rank = *pkActivityRank;
  std::map<TGuildID, std::map<TScheduleTID, CGuildActivityRank*> >::iterator it = activity_rank.begin ();
  for (; it != activity_rank.end ();) {
    std::map<TScheduleTID, CGuildActivityRank*>::iterator it_rank = it->second.find (_scheduleID);
    if (it_rank != it->second.end ()) {
      LP_SAFE_DELETE (it_rank->second);
      it->second.erase (it_rank);

      if (it->second.empty ()) {
        activity_rank.erase (it++);
      }
    }
    else {
      it++;
    }
  }

  return true;
}

bool CActivityTopRankMgr::RemoveMemberRank (EActivityScheduleType _type, TCharID _ch_id, TGuildID _guildId)
{
  std::map<TGuildID, std::map<TScheduleTID, CGuildActivityRank*> >* pkActivityRank = GetActivityRank (_type);
  if (pkActivityRank == NULL)
    return false;

  std::map<TGuildID, std::map<TScheduleTID, CGuildActivityRank*> >& activity_rank = *pkActivityRank;
  if (activity_rank.find (_guildId) != activity_rank.end ()) {
    for (auto& it:activity_rank[_guildId]) {
      it.second->Remove (_ch_id);
    }
  }
  return false;
}

std::map<TGuildID, std::map<TScheduleTID, CGuildActivityRank*> >* CActivityTopRankMgr::GetActivityRank (EActivityScheduleType _type)
{
  switch (_type) {
    case eAST_Dice: return &AllDATopRank;

    default: return NULL;
  }
}

}
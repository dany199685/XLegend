local s_csUtil = CS.XLib.CUtil
local s_uObject = CS.UnityEngine.Object
local s_EItemType = require ("enum/match3_type").ItemType

local super
local Elm_Match3_Item = baseclass ()

function Elm_Match3_Item:Init (_go, _super)
  self.goSelf = _go
  if not super then super = _super end
  local kTransform = self.goSelf.transform

  self.iconImg =  kTransform:GetComponent ('Image')
  self.cvgImg =  kTransform:GetComponent ('CanvasGroup')
  self:SetUsing (false)
  self:SetMoving (false)
end

function Elm_Match3_Item:Destroy ()
  if super then super = nil end
  s_uObject.Destroy (self.goSelf)
  self.goSelf = nil
end

function Elm_Match3_Item:DestroyByMatches ()
  -- TODO:Destory animation.
  if self:IsObstacle () == false then
    super:AddScore (self.kGameData.ItemScore[self.nItemType])

    -- 清除&蒐集格子上的物品 (要消除"珠子類"才能取得，障礙物不行)
    super.kGridList[self.Indexes[1]][self.Indexes[2]].Grid:CallByItemMatch ()

    -- 攻擊周遭可攻擊的障礙物
    local kNearbyItems = super:GetNearbyValidItems (self.Indexes)
    for _, item in pairs (kNearbyItems) do
      item:DestroyByNeighbor ()
    end

    self:SetUsing (false)
    super:DestroyItemByIndex (self.Indexes)
  else
    -- 有可能被功能珠攻擊到
    self:DestroyByNeighbor ()
  end
end

--------------------------------
-- 受到四周珠子消除時的攻擊
-- NOTE:目前只有障礙物可以被攻擊到
--------------------------------
function Elm_Match3_Item:DestroyByNeighbor ()
  if self.nItemType == s_EItemType.Obstacle then
    super:AddScore (self.kGameData.ItemScore[self.nItemType])
    self:SetUsing (false)
    super:DestroyItemByIndex (self.Indexes)
  elseif self.nItemType == s_EItemType.DoubleObstacle then
    super:AddScore (self.kGameData.ItemScore[self.nItemType])
    self:SetType (s_EItemType.Obstacle) -- 摧毀雙層障礙後會遺留單層障礙
  end
end

function Elm_Match3_Item:GetItemScore ()
  return self.kGameData.ItemScore[self.nItemType]
end

function Elm_Match3_Item:UpdateData (_game_data)
  self.kGameData = _game_data
end

function Elm_Match3_Item:SetType (_itemType)
  if _itemType == s_EItemType.Item1 then
    RequestIcon ("icon_match3_item1", self.iconImg)
  elseif _itemType == s_EItemType.Item2 then
    RequestIcon ("icon_match3_item2", self.iconImg)
  elseif _itemType == s_EItemType.Item3 then
    RequestIcon ("icon_match3_item3", self.iconImg)
  elseif _itemType == s_EItemType.Item4 then
    RequestIcon ("icon_match3_item4", self.iconImg)
  elseif _itemType == s_EItemType.Item5 then
    RequestIcon ("icon_match3_item5", self.iconImg)
  elseif _itemType == s_EItemType.Item6 then
    RequestIcon ("icon_match3_item6", self.iconImg)
  elseif _itemType == s_EItemType.Obstacle then
    RequestIcon ("icon_match3_item_obstacle", self.iconImg)
  elseif _itemType == s_EItemType.DoubleObstacle then
    RequestIcon ("icon_match3_item_doubleobstacle", self.iconImg)
  elseif _itemType == s_EItemType.MissleHorizontal then
    RequestIcon ("icon_match3_item_missle_h", self.iconImg)
  elseif _itemType == s_EItemType.MissleVertical then
    RequestIcon ("icon_match3_item_missle_v", self.iconImg)
  elseif _itemType == s_EItemType.Dragonfly then
    RequestIcon ("icon_match3_item_dragonfly", self.iconImg)
  elseif _itemType == s_EItemType.Ray then
    RequestIcon ("icon_match3_item_ray", self.iconImg)
  elseif _itemType == s_EItemType.Bomb then
    RequestIcon ("icon_match3_item_bomb", self.iconImg)
  end

  self.nItemType = _itemType
end

function Elm_Match3_Item:TransformItemType (_itemType)
  -- TODO:Transform animation
  self:SetType (_itemType)
  -- self:SetSelectable (true) -- TODO:Be controlled by animation callback.
end

function Elm_Match3_Item:UpdateItemPosition (_row, _col, _bAnim)
  if _bAnim then
    self:SetMoving (true)
    s_csUtil.DoTweenMove (self.goSelf.transform, super.kGridList[_row][_col].Grid:GetPosition (), super.DF_ITEM_MOVE_ANIM_SECS, function()
      self:SetMoving (false)
    end)
  else
    self.goSelf.transform.position = super.kGridList[_row][_col].Grid:GetPosition ()
  end
  self.Indexes = {_row, _col}
end

-- NOTE:要預先設定好降落位置
function Elm_Match3_Item:StartFallingDown ()
  self:UpdateItemPosition (self.Indexes[1], self.Indexes[2], true)
end

function Elm_Match3_Item:CanDrag ()
  return self.bSelectable and not self:IsObstacle () and not self:IsMoving ()
end

function Elm_Match3_Item:CanDropDown ()
  return self.nItemType ~= s_EItemType.Obstacle and self.nItemType ~= s_EItemType.DoubleObstacle
end

-- TODO:規則暫定
function Elm_Match3_Item:CanTrackingByRay ()
  return not self:IsObstacle ()
  and not self:IsFunctionalItem ()
  and not self:IsMoving ()
end

-- TODO:規則暫定
function Elm_Match3_Item:CanTrackingByDragonfly ()
  return not self:IsFunctionalItem ()
         and not self:IsMoving ()
end

function Elm_Match3_Item:IsFunctionalItem ()
  return self.nItemType >= s_EItemType.MissleHorizontal and self.nItemType <= s_EItemType.Bomb
end

function Elm_Match3_Item:IsObstacle ()
  return self.nItemType == s_EItemType.Obstacle or self.nItemType == s_EItemType.DoubleObstacle
end

function Elm_Match3_Item:IsMatch (_targetType)
  return self.nItemType == _targetType
end

-------------------------------
-- 落珠機制中預先更新Item索引位置
-------------------------------
function Elm_Match3_Item:PreFallingDown ()
  if not self:CanDropDown () then return end

  local nRow, nCol, kGrid
  local direction = super.kFallingDirection[1]
  nRow = self.Indexes[1] + direction[1]
  nCol = self.Indexes[2] + direction[2]
  kGrid = super.kGridList[nRow] and super.kGridList[nRow][nCol] or nil

  -- 若目標格子有珠子正在移入時不能移入
  if kGrid and not kGrid.Item and kGrid.Grid:CanFallingInto () then
    self.Indexes = {nRow, nCol}
    self:SetMoving (true)
    return true
  else
    return false
  end
end

function Elm_Match3_Item:PreFallingDown2 ()
  if not self:CanDropDown () then return end

  local nRow, nCol
  local kGrid
  for _, direction in pairs (super.kFallingDirection) do
    nRow = self.Indexes[1] + direction[1]
    nCol = self.Indexes[2] + direction[2]
    kGrid = super.kGridList[nRow] and super.kGridList[nRow][nCol] or nil

    -- 若目標格子有珠子正在移入時不能移入
    if kGrid and not kGrid.Item and kGrid.Grid:CanFallingInto () then
      self.Indexes = {nRow, nCol}
      self:SetMoving (true)
      return true
    end
  end
  return false
end

function Elm_Match3_Item:SetMoving (_bMobing)
  self.bMoving = _bMobing == true
end

function Elm_Match3_Item:IsMoving ()
  return self.bMoving == true
end

function Elm_Match3_Item:SetSelectable (bool)
  self.bSelectable = bool
end

function Elm_Match3_Item:GetItemType ()
  return self.nItemType
end

function Elm_Match3_Item:SetUsing (_bUse)
  if self.bUsing ~= _bUse then
    self.bUsing = _bUse == true
    if self.bUsing then
      self.cvgImg.alpha = 1
    else
      self.nItemType = nil
      self.cvgImg.alpha = 0
    end
    self:SetSelectable (self.bUsing)
  end
end

function Elm_Match3_Item:SetActive (_bActive)
  self.goSelf:SetActive (_bActive)
end

return Elm_Match3_Item
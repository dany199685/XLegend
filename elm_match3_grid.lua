local s_csUtil = CS.XLib.CUtil
local s_uObject = CS.UnityEngine.Object
local s_csUiEventListenerFactory = CS.XLib.UiEventListenerFactory
local s_EGridType = require ("enum/match3_type").GridType
local s_EItemType = require ("enum/match3_type").ItemType
local s_ECollectionType = require ("enum/match3_type").TargetItemType

local super = nil

local Elm_Match3_Grid = baseclass ()

function Elm_Match3_Grid:Init (_go, _super, _indexes, _funcClickCallback)
  self.goSelf = _go
  if not super then super = _super end
  self.Indexes = _indexes
  self.iconBG = self.goSelf.transform:GetComponent ('Image')
  self.cvgSelf = self.goSelf.transform:GetComponent ('CanvasGroup')
  self.funcOnClickCallback = _funcClickCallback
  s_csUiEventListenerFactory.GetPointClick (self.goSelf):onPointerClick ("+", function () self:funcOnClickCallback () end)

  self.kGridIcon = {}
  self.kGridIcon[1] = {}
  local tra = s_csUtil.FindChildByRecursive (self.goSelf.transform, "icon_first")
  self.kGridIcon[1].icon = tra:GetComponent ('Image')
  self.kGridIcon[1].cvg = tra:GetComponent ('CanvasGroup')
  self.kGridIcon[2] = {}
  tra = s_csUtil.FindChildByRecursive (self.goSelf.transform, "icon_second")
  self.kGridIcon[2].icon = tra:GetComponent ('Image')
  self.kGridIcon[2].cvg = tra:GetComponent ('CanvasGroup')

  self.nGridType = s_EGridType.Normal
end

function Elm_Match3_Grid:Destroy ()
  if super then super = nil end
  s_uObject.Destroy (self.goSelf)
  self.goSelf = nil
end

function Elm_Match3_Grid:UpdateData (_game_data)
  self.kGameData = _game_data
end

-------------------------------------------------
-- nGridType：None、Normal、Frozen(可生成&降落珠子)
-- nItemType：一般珠子、障礙物、功能珠
-- nCollectionType：Block、Double-block
-- NOTE:Grid覆蓋在Collection上面
-------------------------------------------------
function Elm_Match3_Grid:SetType (_nGridType, _nItemType, _nCollectionType)
  if _nGridType ~= s_EGridType.None then
    if _nGridType == s_EGridType.Frozen then
      RequestIcon ("icon_match3_frozen", self.kGridIcon[2].icon)
      CanvasGroupVisible (self.kGridIcon[2].cvg, true)
    else
      CanvasGroupVisible (self.kGridIcon[2].cvg, false)
    end

    -- FirstIcon
    if _nCollectionType and _nCollectionType ~= s_ECollectionType.None then
      if _nCollectionType == s_ECollectionType.Collection1 then
        RequestIcon ("icon_match3_collection1", self.kGridIcon[1].icon)
      elseif _nCollectionType == s_ECollectionType.Collection2 then
        RequestIcon ("icon_match3_collection2", self.kGridIcon[1].icon)
      elseif _nCollectionType == s_ECollectionType.Collection3 then
        RequestIcon ("icon_match3_collection3", self.kGridIcon[1].icon)
      end

      self.kGridIcon[1].cvg.alpha = 1
    else
      self.kGridIcon[1].cvg.alpha = 0
    end

    CanvasGroupVisible (self.cvgSelf, true)
  else
    CanvasGroupVisible (self.cvgSelf, false)
  end

  self.nGridType        = _nGridType
  self.nInitItemType    = _nItemType -- 預設珠子類型
  self.nCollectionType  = _nCollectionType
end

------------------------------
-- NOTE:格子上的Item被消除時呼叫
-- 蒐集格子上的物品、解除冰凍效果
------------------------------
function Elm_Match3_Grid:CallByItemMatch ()
  -- TODO:Destroy collection animation.
  -- 解除冰凍效果
  if self.nGridType == s_EGridType.Frozen then
    self:SetType (s_EGridType.Normal, self.nInitItemType, self.nCollectionType)
    return
  end

  if self.nCollectionType ~= s_ECollectionType.None then
    super:AddCollectionItem (self.nCollectionType, 1)

    -- Collection2消除完會變成Collection1，而不是直接清除
    if self.nCollectionType == s_ECollectionType.Collection2 then
      self:SetType (self.nGridType, self.nInitItemType, s_EGridType.Collection1)
    else
      self:SetType (self.nGridType, self.nInitItemType, s_ECollectionType.None)
    end
  end
end

function Elm_Match3_Grid:CanDrag ()
  return self.nGridType ~= s_EGridType.Frozen
end

function Elm_Match3_Grid:IsNone ()
  return self.nGridType == s_EGridType.None
end

function Elm_Match3_Grid:IsCollectionExist ()
  return self.nCollectionType ~= s_ECollectionType.None
end

function Elm_Match3_Grid:CanFallingInto ()
  if self.nGridType == s_EGridType.None then
    return false
  else
    return super.kGridList[self.Indexes[1]][self.Indexes[2]].Item == nil
  end
end

function Elm_Match3_Grid:GetItemDefaultType ()
  return self.nInitItemType or s_EItemType.Random
end

function Elm_Match3_Grid:GetPosition ()
  return self.goSelf.transform.position
end

return Elm_Match3_Grid
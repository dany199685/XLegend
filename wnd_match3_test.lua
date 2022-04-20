local s_csUiEventListenerFactory = CS.XLib.UiEventListenerFactory
local s_uObject = CS.UnityEngine.Object
local s_csUtil = CS.XLib.CUtil
local s_Math = math
local s_EWndType = require ("enum/ui_enum").WndType
local s_ResLoader = require ("common/resloader")
local s_ProxyGameData = GetProxy ("Proxy_GameData")
local s_Logger = require ("common/logger")
local s_ELoadingType = require ("enum/loading_type")
local s_GameFrame = require ("manager/game_frame")
local s_ElmMatch3Grid = require ("ui/elm_match3_grid")
local s_ElmMatch3Item = require ("ui/elm_match3_item")

local s_EItemType = require ("enum/match3_type").ItemType
local s_EItemDestroyType = require ("enum/match3_type").ItemDestroyType
local s_ELimitType = require ("enum/match3_type").LimitType
local s_EGameMode = require ("enum/match3_type").GameMode
local s_ItemMatchType = require ("enum/match3_type").ItemMatchType

local DF_RESERVE_ROWS  = 3
local DF_ITEM_POOL_ADDITIONAL_NUM = 20
local DF_ITEM_TYPE_MAX_NUM = 3 -- 數量應該對照TargetItemType
local DF_GAMESTART_CHECK_COUNT = 10  -- 遊戲開始前檢查次數上限
local DF_ELM_MATHC3_GRID_PREFAB_NAME = "elm_match3_grid"

-- For testing
local DF_LIMIT_TIME_TEXT = "剩餘時間：{0} 秒"
local DF_LIMIT_STEPUSAGE_TEXT = "剩餘步數：{0}"
local DF_SCORE_TEXT = "分數：{0}"
local DF_SCORE_SPLITER_TEXT = "{0} / {1}"
local DF_STAR_TEXT = "星數：{0}"
local DF_ITEM_NUM_TEXT = "蒐集目標物{0}：{1} / {2}"
local DF_GAME_VICTORY = "遊戲勝利"
local DF_GAME_OVER = "遊戲結束"

local s_BaseUI = require ("ui/base_ui")
local Wnd_Match3_Test = baseclass (s_BaseUI)
local this = nil

local s_MatchTypeOfFuncItem = {
  [s_ItemMatchType.Dragonfly] = s_EItemType.Dragonfly,
  [s_ItemMatchType.MissleH] = s_EItemType.MissleHorizontal,
  [s_ItemMatchType.MissleV] = s_EItemType.MissleVertical,
  [s_ItemMatchType.Ray] = s_EItemType.Ray,
  [s_ItemMatchType.Bomb] = s_EItemType.Bomb,
}

local s_GameState = {
  Stop = 1,
  Playing = 2,
  GameOver = 3,
  FailedToGenerate = 4
}

function Wnd_Match3_Test.New (_name)
  this = Wnd_Match3_Test ()
  this.name = _name
  this.eWndType = s_EWndType.Pop
  this.eLoadType = s_ELoadingType.From.Package
  this:RegisterMessage ()
  return this
end

function Wnd_Match3_Test:ShowUI (_show)
  self.super.ShowUI (self, _show)
end

function Wnd_Match3_Test.Destroy ()
  this:ResetContent ()
  for _, cols in pairs (this.kGridList) do
    for _, obj in pairs (cols) do
      if obj.Item then
        obj.Item:Destroy ()
      end
      if obj.Grid then
        obj.Grid:Destroy ()
      end
    end
  end
  this.kGridList = {}

  for _, item in pairs (this.kItemPool) do
    item:Destroy ()
  end
  this.kItemPool = {}

  this.bInit = false
  this = nil
end

function Wnd_Match3_Test.Awake (_gameObj)
  this.super.Awake (this, _gameObj)
  this.Animator = this.kTransform:GetComponent ('Animator')
  -- RegisterEvent must after Awake
  this:RegisterEvent ()
  this:TriggerShow ()
end

function Wnd_Match3_Test:TriggerShow ()
  this.Animator:SetTrigger ("trigger_show")
end

function Wnd_Match3_Test.OnPreLoad (_name, _asyncRequest)
  _asyncRequest:Add ("elm_match3_grid", s_ELoadingType.Type.UI)
  _asyncRequest:Add ("elm_match3_item", s_ELoadingType.Type.UI)
end

function Wnd_Match3_Test:OnLoaded (_asyncRequest)
  self.super.OnLoaded (this)
  self.preElmGrid = _asyncRequest:get_Item('elm_match3_grid').Prefab
  self.preElmItem = _asyncRequest:get_Item('elm_match3_item').Prefab
end

function Wnd_Match3_Test.Start ()
  this.super.Start (this)
end

function Wnd_Match3_Test:CloseBack ()
  self.OnClickClose ()
  return true
end

function Wnd_Match3_Test:RegisterMessage ()
  self.super.RegisterMessage (self)
  self.kTabMsgFunc ['Open'] = function (_var)
    self:UpdateData (_var)
    self:ShowUI (true)
  end
end

function Wnd_Match3_Test:RegisterEvent ()
  if self.bInit then
    return
  end

  this = self
  local tra
  self.animAnimator = self.kTransform:GetComponent ('Animator')
  self.cvgCanvasGroup = self.kTransform:GetComponent ('CanvasGroup')
  UIRegEvent (s_csUtil.FindChildByRecursive(self.kTransform, "btn_close"):GetComponent("Button"), "onClick", self.OnClickClose)

  self.groupGrid = s_csUtil.FindChildByRecursive (self.kTransform, "group_grid")
  self.groupItem = s_csUtil.FindChildByRecursive (self.kTransform, "group_item")
  
  -- GameInformation
  tra = s_csUtil.FindChildByRecursive (self.kTransform, "text_limit")
  self.txtLimit = tra:GetComponent ('Text')
  self.cvgLimit = tra:GetComponent ('CanvasGroup')
  self.txtScore = s_csUtil.FindChildByRecursive (self.kTransform, "text_score"):GetComponent ('Text')
  self.txtStar = s_csUtil.FindChildByRecursive (self.kTransform, "text_star"):GetComponent ('Text')
  self.kItemNumber = {}
  for i = 1, DF_ITEM_TYPE_MAX_NUM do
    self.kItemNumber[i] = {}
    tra = s_csUtil.FindChildByRecursive (self.kTransform, "text_item" .. i .. "_num")
    self.kItemNumber[i].Text = tra:GetComponent ('Text')
    self.kItemNumber[i].cvg = tra:GetComponent ('CanvasGroup')
  end

  -- NOTE:可以分別由"拖曳"+"點擊"方式觸發珠子特殊功能
  local pointerDrag = s_csUiEventListenerFactory.GetPointerDrag (self.groupGrid.gameObject)
  pointerDrag:onDrag ("+", function (_goDrag, _eventData, _) self:OnDrag (_goDrag, _eventData, _) end)
  pointerDrag:onBeginDrag ("+", function (_goDrag, _eventData, _) self:OnBeginDrag (_goDrag, _eventData, _) end)

  local request = s_ResLoader:AsyncRequestAssets ('elm_match3_grid', s_ELoadingType.Type.UI, self.PreLoad, 0)
  request:Add ('elm_match3_item', s_ELoadingType.Type.UI, 0)
  s_ResLoader:SetLoadRequest (request)

  self.kGridList    = {}
  self.kItemPool    = {} -- 儲存尚未使用的Elm_item
  self.DF_ITEM_MOVE_ANIM_SECS = 0.2 -- TODO:改讀參數
  self.DF_DRAGONFLY_ATTACKS_DELAY_SECS = 1 -- TODO:改讀參數
  self.kFallingDirection = {{-1, 0}--[[下]], {-1, -1}--[[左下]], {-1, 1}--[[右下]]}
  self.kNeighborDirection = {{1, 0}--[[上]], {-1, 0}--[[下]], {0, -1}--[[左]], {0, 1}--[[右]]} -- 四周
  self.kCheckDirection = {{0, 1}--[[右]], {1, 0}--[[上]]} -- 右&上

  self.bInit = true
end

function Wnd_Match3_Test:OnClickClose()
  this:Close()
end

function Wnd_Match3_Test:ResetContent ()
  self.nMoveStep = 0
  self.nScore = 0
  self.nLimitValue = 0
  self.nStarCount = 0
  self.kCollectionState = {}

  ---------------------------------------------
  -- kMatches:
  -- Range                  -- 待清除item
  -- Center                 -- 待清除item
  -- DestroyType            -- 清除方式
  ---------------------------------------------
  self.kMatchData = {} -- <Key, <ItemMatchType, <kMatches>>>，待消除的ItemRange

  self.nScoreGoal = 0
  for _, v in pairs (self.kItemNumber) do
    CanvasGroupVisible (v.cvg, false)
  end

  self:RegistTimer (false)

  self.nGameState = s_GameState.Stop
  self.goBeginPressGrid = nil
end

function Wnd_Match3_Test:SetLayoutSize (_maxRow, _maxCol)
  self.nMaxRow, self.nMaxCol = _maxRow, _maxCol
end

function Wnd_Match3_Test:UpdateData (_queryId)
  if not self.bInit then return end
  
  self:ResetContent ()
  self.nGameId = _queryId
  self.kGameData = s_ProxyGameData.QueryData ("Match3", self.nGameId)
  if not self.kGameData then
    s_Logger.Error ("Wnd_Match3_Test::UpdateData:It cannnot find the gamedata[".. self.nGameId .. "].")
    self.nGameState = s_GameState.FailedToGenerate
    return
  end

  -- Limit
  self.nLimitValue = self.kGameData.Limit.value
  if self.kGameData.Limit.type == s_ELimitType.StepUsage then
    self:UpdateAndCheckGameLimit ()
  elseif self.kGameData.Limit.type == s_ELimitType.Time then
    -- 等待遊戲開始時才開始倒數
    self.txtLimit.text = FormatString (DF_LIMIT_TIME_TEXT, self.kGameData.Limit.value)
  else
    CanvasGroupVisible (self.cvgLimit, false)
  end

  -- Star
  self:UpdateStarCount ()

  -- Codition (時間等開始交換時才開始計算)
  if self.kGameData.Mode == s_EGameMode.Collect then
    for i, con in pairs (self.kGameData.Conditions) do
      if con.value ~= 0 then
        self.kCollectionState[i] = {}
        self.kCollectionState[i].num = 0
        self.kCollectionState[i].bDone = false
        CanvasGroupVisible (self.kItemNumber[i].cvg, true)
      end
    end
    self:UpdateAndCheckCollectionCount ()
  elseif self.kGameData.Mode == s_EGameMode.Score then
    self.nScoreGoal = self.kGameData.Conditions[1].value
    self:UpdateAndCheckScore ()
  end

  self:SetLayoutSize (self.kGameData.LayoutSize.maxRows, self.kGameData.LayoutSize.maxCols)
  self.nAllRow = self.nMaxRow + DF_RESERVE_ROWS

  if #self.kGridList == 0 then
    self:HandleLayoutData ()
  else
    self.nGameState = s_GameState.Playing
  end
end

function Wnd_Match3_Test:RegistTimer (_toggle)
  if _toggle then
    if not self.bRegistTimer then
      FacadeRegisterUpdator (self, self.OnUpdateTime, 1)
      self.bRegistTimer = true
    end
  else
    if self.bRegistTimer then
      FacadeUnRegisterUpdator (self, self.OnUpdateTime)
      self.bRegistTimer = false
    end
  end
end

function Wnd_Match3_Test:OnUpdateTime ()
  if self.nLimitValue >= s_GameFrame:GetServerSec () then
    self.txtLimit.text = FormatString (DF_LIMIT_TIME_TEXT, TimeToStringSec (self.nLimitValue - s_GameFrame:GetServerSec ()))
  else
    self:RegistTimer (false)
    
    local bGameVictory = false
    if self.kGameData.Mode == s_EGameMode.Score then
      if self:UpdateAndCheckScore () then bGameVictory = true end
    elseif self.kGameData.Mode == s_EGameMode.Collect then
      if self:UpdateAndCheckCollectionCount () then bGameVictory = true end
    end
    self.nGameState = s_GameState.Stop
    UISendMessage ('Wnd_Message', 'Open', 'icon_message01', bGameVictory and DF_GAME_VICTORY or DF_GAME_OVER)
  end
end

function Wnd_Match3_Test:UpdateStarCount ()
  for starCnt, score in pairs (self.kGameData.ScoreForStars) do
    if self.nScore < score then
      self.txtStar.text = FormatString (DF_STAR_TEXT, starCnt - 1)
      break
    end
  end
end

function Wnd_Match3_Test:UpdateAndCheckScore ()
  if self.nScoreGoal ~= 0 then
    self.txtScore.text = FormatString (DF_SCORE_TEXT, FormatString (DF_SCORE_SPLITER_TEXT, self.nScoreGoal, self.nScore))
    return self.nScore >= self.nScoreGoal
  else
    self.txtScore.text = FormatString (DF_SCORE_TEXT, self.nScore)
    return false
  end
end

function Wnd_Match3_Test:AddScore (_score)
  self.nScore = self.nScore + (_score or 0)
end

function Wnd_Match3_Test:AddCollectionItem (_type, _num)
  if self.kCollectionState[_type] then
    self.kCollectionState[_type].num = self.kCollectionState[_type].num + _num
  end
end

function Wnd_Match3_Test:UpdateAndCheckCollectionCount ()
  for type, data in pairs (self.kCollectionState) do
    for index, con in pairs (self.kGameData.Conditions) do
      if con.type == type then
        self.kItemNumber[index].Text.text = FormatString (DF_ITEM_NUM_TEXT, index, con.value, data.num)
        if data.num >= con.value then
          data.bDone = true
        end
        break
      end
    end
  end
  for _, data in pairs (self.kCollectionState) do
    if data.bDone == false then
      return false
    end
  end
  return true
end

function Wnd_Match3_Test:UpdateAndCheckGameLimit ()
  -- 時間由Updator去檢查
  if self.kGameData.Limit.type == s_ELimitType.StepUsage then
    self.txtLimit.text = FormatString (DF_LIMIT_STEPUSAGE_TEXT, self.nLimitValue - self.nMoveStep)
    return self.nMoveStep < self.nLimitValue
  end
  return true
end

function Wnd_Match3_Test:StartGamePreCheck ()
  -- 先篩選出相連的一般珠子
  local bRefresh = false
  local Item, id, rangeIds
  local kMatchRange = {}
  -- 只檢查玩家看的到的範圍
  for row = 1, self.nMaxRow do
    for col = 1, self.nMaxCol  do
      Item = self.kGridList[row][col].Item
      if not Item or Item:IsObstacle () then
        goto CONTINUE
      end

      if Item:IsFunctionalItem () then
        bRefresh = true
        break
      end

      -- 檢查是否已存在記錄範圍內，避免重複檢查
      id = self:GetItemIdByRowAndCol (row, col)
      for _, range in pairs (kMatchRange) do
        if range[id] then
          goto CONTINUE
        end
      end

      rangeIds = {}
      self:GetItemNeighbors (Item, rangeIds)

      -- 基本篩選掉不可能組合成功的組合
      if table.getTableLength (rangeIds) >= 3 then
        table.insert (kMatchRange, rangeIds)
      end

      ::CONTINUE::
    end
    if bRefresh then break end
  end
  -- 檢查篩選出來相連的組合是否可以消除
  local kMatch
  for _, ranges in pairs (kMatchRange) do
    kMatch = self:GetItemMatchByRange (ranges)
    if kMatch then
      bRefresh = true
      break
    end
  end

  if bRefresh then
    -- 若要刷新就整個版面都刷新
    self:UpdateItemLayout ()
  else
    -- 檢查2：檢查版面是否死局
    if self:IsGameDeadlock () then
      self:UpdateItemLayout ()
      bRefresh = true
    end
  end
  return not bRefresh
end

-- 死局條件：無功能珠 & 無移動後可消除組合
function Wnd_Match3_Test:IsGameDeadlock ()
  local checkRanges, itemType, targetRow, targetCol, row, col, nMatchTop, nMatchBottom, nMatchLeft, nMatchRight
  for Row = 1, self.nMaxRow do
    for Col = 1, self.nMaxCol do
      if not self.kGridList[Row][Col].Item
      or self.kGridList[Row][Col].Item:IsObstacle () then
        goto CONTINUE
      end

      if self.kGridList[Row][Col].Item:IsFunctionalItem () then
        return false
      end

      for _, direction in pairs (self.kCheckDirection) do
        targetRow = Row + direction[1]
        targetCol = Col + direction[2]

        if (targetRow > self.nMaxRow or targetRow < 1) or (targetCol > self.nMaxCol or targetCol < 1)
        or self.kGridList[targetRow][targetCol].Item == nil
        or self.kGridList[targetRow][targetCol].Item:CanDrag () == false then
          goto CONTINUE
        end

        -- NOTE:若要加入移動提示，可做在這邊
        -- 檢查如果把每個珠子往"右"、"上"移動後是否可以組合成消除組合(只檢查基本三消、蜻蜓珠(田字))
        self.kGridList[Row][Col].Item, self.kGridList[targetRow][targetCol].Item = self.kGridList[targetRow][targetCol].Item, self.kGridList[Row][Col].Item
        checkRanges = {{Row, Col}, {targetRow, targetCol}}
        for _, indexes in pairs (checkRanges) do
          itemType = self.kGridList[indexes[1]][indexes[2]].Item:GetItemType ()
          nMatchTop, nMatchBottom, nMatchLeft, nMatchRight = 0, 0, 0, 0
          
          -- 檢查上方
          for i = 1, 2 do
            row = indexes[1] + i
            if row <= self.nMaxRow and
               self.kGridList[row][indexes[2]].Item and
               self.kGridList[row][indexes[2]].Item:IsMatch (itemType) then
              nMatchTop = nMatchTop + 1
            else
              break
            end
          end
          if nMatchTop == 2 then
            self.kGridList[Row][Col].Item, self.kGridList[targetRow][targetCol].Item = self.kGridList[targetRow][targetCol].Item, self.kGridList[Row][Col].Item
            return false
          end
          
          -- 檢查下方
          for i = 1, 2 do
            row = indexes[1] - i
            if row > 0 and
               self.kGridList[row][indexes[2]].Item and
               self.kGridList[row][indexes[2]].Item:IsMatch (itemType) then
              nMatchBottom = nMatchBottom + 1
            else
              break
            end
          end
          if nMatchBottom == 2 or (nMatchTop + nMatchBottom) >= 2 then
            self.kGridList[Row][Col].Item, self.kGridList[targetRow][targetCol].Item = self.kGridList[targetRow][targetCol].Item, self.kGridList[Row][Col].Item
            return false
          end

          -- 檢查左方
          for i = 1, 2 do
            col = indexes[2] - i
            if col > 0 and
               self.kGridList[indexes[1]][col].Item and
               self.kGridList[indexes[1]][col].Item:IsMatch (itemType) then
              nMatchLeft = nMatchLeft + 1
            else
              break
            end
          end
          if nMatchLeft == 2 then
            self.kGridList[Row][Col].Item, self.kGridList[targetRow][targetCol].Item = self.kGridList[targetRow][targetCol].Item, self.kGridList[Row][Col].Item
            return false
          end

          -- 檢查右方
          for i = 1, 2 do
            col = indexes[2] + i
            if col <= self.nMaxCol and
               self.kGridList[indexes[1]][col].Item and
               self.kGridList[indexes[1]][col].Item:IsMatch (itemType) then
              nMatchRight = nMatchRight + 1
            else
              break
            end
          end
          if nMatchRight == 2 or (nMatchLeft + nMatchRight) >= 2 then
            self.kGridList[Row][Col].Item, self.kGridList[targetRow][targetCol].Item = self.kGridList[targetRow][targetCol].Item, self.kGridList[Row][Col].Item
            return false
          end

          -- 檢查田字(以田字左下角作為檢查基準點)
          if (nMatchTop == 1 and nMatchRight == 1)
          or (nMatchRight == 1 and nMatchBottom == 1)
          or (nMatchBottom == 1 and nMatchLeft == 1)
          or (nMatchLeft == 1 and nMatchTop == 1) then
            -- 此時的row, col為基準點在田字裡的斜對角Index
            row = (nMatchTop == 1) and (indexes[1] + 1) or (indexes[1] - 1)
            col = (nMatchRight == 1) and (indexes[2] + 1) or (indexes[2] - 1)
            if self.kGridList[row][col].Item and self.kGridList[row][col].Item:IsMatch (itemType) then
              self.kGridList[Row][Col].Item, self.kGridList[targetRow][targetCol].Item = self.kGridList[targetRow][targetCol].Item, self.kGridList[Row][Col].Item
              return false
            end
          end
        end
        self.kGridList[Row][Col].Item, self.kGridList[targetRow][targetCol].Item = self.kGridList[targetRow][targetCol].Item, self.kGridList[Row][Col].Item
        ::CONTINUE::
      end

      ::CONTINUE::
    end
  end

  return true -- 死局
end

--------------------------------------------
-- 取得周圍所有相同種類可消除的珠子(不含功能珠)
--------------------------------------------
function Wnd_Match3_Test:GetItemNeighbors (item, _range)
  local id = self:GetItemIdByRowAndCol (item.Indexes[1], item.Indexes[2])
  if _range[id] then
    return
  else
    _range[id] = true
  end

  -- 檢查上方
  local row, col = item.Indexes[1], item.Indexes[2] + 1
  if col <= self.nMaxCol and
     self.kGridList[row][col].Item and
     self.kGridList[row][col].Item:IsFunctionalItem () == false and
     self.kGridList[row][col].Item:IsMatch (item:GetItemType ()) then
    self:GetItemNeighbors (self.kGridList[row][col].Item, _range)
  end

  -- 檢查下方
  row, col = item.Indexes[1], item.Indexes[2] - 1
  if col > 0 and
     self.kGridList[row][col].Item and
     self.kGridList[row][col].Item:IsFunctionalItem () == false and
     self.kGridList[row][col].Item:IsMatch (item:GetItemType ()) then
    self:GetItemNeighbors (self.kGridList[row][col].Item, _range)
  end

  -- 檢查左方
  row, col = item.Indexes[1] - 1, item.Indexes[2]
  if row > 0 and
      self.kGridList[row][col].Item and
      self.kGridList[row][col].Item:IsFunctionalItem () == false and
      self.kGridList[row][col].Item:IsMatch (item:GetItemType ()) then
    self:GetItemNeighbors (self.kGridList[row][col].Item, _range)
  end

  -- 檢查右方
  row, col = item.Indexes[1] + 1, item.Indexes[2]
  if row <= self.nMaxRow and
      self.kGridList[row][col].Item and
      self.kGridList[row][col].Item:IsFunctionalItem () == false and
      self.kGridList[row][col].Item:IsMatch (item:GetItemType ()) then
    self:GetItemNeighbors (self.kGridList[row][col].Item, _range)
  end
end

------------------------------------------------
-- 從當前玩家所看到的版面找出可消除的組合(非功能珠)
------------------------------------------------
function Wnd_Match3_Test:GetMapMatchData ()
  local Item, id, rangeIds
  local kMatchRange = {}

  -- 只檢查玩家看的到的範圍
  for row = 1, self.nMaxRow do
    for col = 1, self.nMaxCol  do
      Item = self.kGridList[row][col].Item
      if not Item or Item:IsObstacle () then
        goto CONTINUE
      end

      if Item:IsFunctionalItem () then
        goto CONTINUE
      end

      -- 檢查是否已存在記錄範圍內，避免重複檢查
      id = self:GetItemIdByRowAndCol (row, col)
      for _, range in pairs (kMatchRange) do
        if range[id] then
          goto CONTINUE
        end
      end

      rangeIds = {}
      self:GetItemNeighbors (Item, rangeIds)
      if table.getTableLength (rangeIds) >= 3 then
        table.insert (kMatchRange, rangeIds)
      end

      ::CONTINUE::
    end
  end

  self.kMatchData = {}
  for _, range in pairs (kMatchRange) do
    local kMatch = self:GetItemMatchByRange (range)
    table.insert (self.kMatchData, kMatch)
  end
end

function Wnd_Match3_Test:HandleLayoutData ()
  self:InitGridLayout ()
  FixDelaySeconds (function ()
    self:UpdateItemLayout ()

    -- 檢查版面是否準備好(遊戲開始時的版面不可以有可以消除但未消除的組合 & 不可死局)
    local check_cnt = 1
    while check_cnt <= DF_GAMESTART_CHECK_COUNT do
      s_Logger.Debug ("ItemLayoutRefresh count：" .. check_cnt)
      if self:StartGamePreCheck () then
        break
      end

      check_cnt = check_cnt + 1
    end
    if check_cnt <= DF_GAMESTART_CHECK_COUNT then
      self.nGameState = s_GameState.Playing
    else
      self.nGameState = s_GameState.FailedToGenerate
      s_Logger.Error ("Failed to init item layout, check it!")
    end
  end, 0.1)
end

------------------------
-- 生成基底格子、ItemPool
------------------------
function Wnd_Match3_Test:InitGridLayout ()
  if not self.preElmGrid or not self.kGameData then return end

  -- TODO:若資料更新數量不足時需要更新
  local max_count = self.nAllRow * self.nMaxCol + DF_ITEM_POOL_ADDITIONAL_NUM
  for i = 1, max_count do
    local goElmItem = s_uObject.Instantiate (self.preElmItem, self.groupItem)
    local kElm = s_ElmMatch3Item ()
    kElm:Init (goElmItem, self)
    kElm:UpdateData (self.kGameData)
    table.insert (self.kItemPool, kElm)
  end
  
  -- 版面自適應
  local kGridLayoutGroup = self.groupGrid:GetComponent ('GridLayoutGroup')
  local kElmRect = self.preElmGrid.transform.rect
  local elmWidth, elmHeight = kElmRect.width, kElmRect.height
  local newWidth = elmWidth * self.nMaxCol + kGridLayoutGroup.spacing.x * (self.nMaxCol - 1)
  local newHeight = elmHeight * self.nMaxRow + kGridLayoutGroup.spacing.y * (self.nMaxRow - 1)
  kGridLayoutGroup.constraintCount = self.nMaxCol
  -- kGridLayoutGroup.transform.sizeDelta = s_csVector2 (newWidth, newHeight)
  -- kGridLayoutGroup.cellSize

  for _, kRow in pairs (self.kGridList) do
    for _, kElm in pairs (kRow) do
      kElm:Destroy ()
    end
  end

  self.kGridList = {}
  local nGridType, nItemType, nCollectionType, nConfig
  for row = 1, self.nAllRow do
    if not self.kGridList[row] then
      self.kGridList[row] = {}
    end
    for col = 1, self.nMaxCol do
      local goElmGrid = s_uObject.Instantiate (self.preElmGrid, self.groupGrid)
      goElmGrid.name = DF_ELM_MATHC3_GRID_PREFAB_NAME .. (self.nMaxCol * (row - 1) + col)
      local kElm = s_ElmMatch3Grid ()
      kElm:Init (goElmGrid, self, { row, col }, self.OnClickItemCallback)
      kElm:UpdateData (self.kGameData)
      if row <= self.nMaxRow then
        -- 格子設定是用四位數表示
        nConfig = self.kGameData.Layout[self.nMaxRow - (row - 1)][col]
        nGridType       = math.floor (nConfig / 100 % 10)     -- None, Normal, Frozen
        nItemType       = math.floor (nConfig / 10 % 10)      -- Item種類(隨機、一般、障礙物、功能珠)
        nCollectionType   = math.floor (nConfig % 10)         -- 關卡目標蒐集物
        kElm:SetType (nGridType, nItemType, nCollectionType)  -- GameData要倒過來讀(Item由左下方生成，最下Rol為1、最左Col為1)
      end
      self.kGridList[row][col] = {}
      self.kGridList[row][col].Grid = kElm
    end
  end

end

function Wnd_Match3_Test:SpawnItemToIndex (_index, _bItem)
  if #self.kItemPool > 0 then
    local Item = self.kItemPool[1]
    Item:SetUsing (true)
    if _bItem then
      Item:SetType (self:GetItemRandomType ())
    end
    Item:UpdateItemPosition (_index[1], _index[2])
    table.remove (self.kItemPool, 1)
    return Item
  end
  return nil
end

function Wnd_Match3_Test:DestroyItemByIndex (_index)
  table.insert (self.kItemPool, self.kGridList[_index[1]][_index[2]].Item)
  self.kGridList[_index[1]][_index[2]].Item = nil
end

function Wnd_Match3_Test:UpdateItemLayout ()
  for row , cols in pairs (self.kGridList) do
    for col, data in pairs (cols) do
      if data.Grid:IsNone () then
        goto CONTINUE
      end
    
      -- 生成珠子、障礙物
      if data.Item then
        -- 若重生版面時，珠子是功能珠的話不能清掉
        if data.Item:IsFunctionalItem () then
          goto CONTINUE
        end
      else
        data.Item = self:SpawnItemToIndex ({row, col})
        if not data.Item then
          self.nGameState = s_GameState.FailedToGenerate
          s_Logger.Error ("Wnd_Match3_Test::UpdateItemLayout:The number of ItemPool is not enough.")
          return
        end
      end
    
      local itemType = data.Grid:GetItemDefaultType ()
      if itemType == s_EItemType.Random then
        itemType = self:GetItemRandomType ()
      end
      data.Item:SetType (itemType)
      data.Item:SetSelectable (true)
    
      ::CONTINUE::
    end
  end
end

function Wnd_Match3_Test:OnBeginDrag (_, _eventData, _)
  if self.nGameState ~= s_GameState.Playing then
    return
  end

  -- 檢查起始拖曳的格子是否可以拖曳
  if string.find (_eventData.pointerEnter.name, DF_ELM_MATHC3_GRID_PREFAB_NAME) == nil then
    return
  end

  local _, nBeginEnd = string.find (_eventData.pointerEnter.name, DF_ELM_MATHC3_GRID_PREFAB_NAME)
  local beginIdx = tonumber (string.sub (_eventData.pointerEnter.name, nBeginEnd + 1, string.len (_eventData.pointerEnter.name)))
  local beginRow, beginCol = self:GetRowAndColById (beginIdx)
  if beginRow > self.nMaxRow or beginCol > self.nMaxCol then
    return
  end
  
  local kBegin = self.kGridList[beginRow][beginCol]
  if kBegin.Grid:CanDrag () == false or (not kBegin.Item or kBegin.Item:CanDrag () == false) then
    return
  end

  self.goBeginPressGrid = _eventData.pointerEnter
  self.kBeginDragIndexes = { beginRow, beginCol }
end

function Wnd_Match3_Test:OnDrag (_, _eventData, _)
  local CleanBeginDrag = function ()
    self.goBeginPressGrid = nil
    self.kBeginDragIndexes = nil
  end

  if _eventData.pointerEnter == nil
  or self.nGameState ~= s_GameState.Playing
  or self.goBeginPressGrid == nil then
    return
  end

  -- Exchange
  if _eventData.pointerEnter ~= self.goBeginPressGrid then
    if string.find (_eventData.pointerEnter.name, DF_ELM_MATHC3_GRID_PREFAB_NAME) == nil then
      CleanBeginDrag ()
      return
    end
    
    local _, nTargetEnd = string.find (_eventData.pointerEnter.name, DF_ELM_MATHC3_GRID_PREFAB_NAME)
    local targetIdx = tonumber (string.sub (_eventData.pointerEnter.name, nTargetEnd + 1, string.len (_eventData.pointerEnter.name)))
    local targetRow, targetCol = self:GetRowAndColById (targetIdx)
    if targetRow > self.nMaxRow or targetCol > self.nMaxCol then
      CleanBeginDrag ()
      return
    end

    local kTarget = self.kGridList[targetRow][targetCol]
    if kTarget.Grid:CanDrag () == false or (not kTarget.Item or kTarget.Item:CanDrag () == false) then
      CleanBeginDrag ()
      return
    end

    self:OnExchange (self.kBeginDragIndexes, { targetRow, targetCol})

    CleanBeginDrag ()
  end
end

function Wnd_Match3_Test:OnExchange (_kBegin, _kTarget)
  local kBegin = self.kGridList[_kBegin[1]][_kBegin[2]]
  local kTarget = self.kGridList[_kTarget[1]][_kTarget[2]]
  if kBegin == nil or kBegin.Item == nil
  or kTarget == nil or kTarget.Item == nil then
    return
  end

  if self.IsAdjacent (_kBegin, _kTarget) == false then
    return
  end

  self.nGameState = s_GameState.Stop

  -- 開始交換後開始倒數
  if not self.bRegistTimer and self.kGameData.Limit.type == s_ELimitType.Time then
    self.nLimitValue = s_GameFrame:GetServerSec () + self.nLimitValue
    self:RegistTimer (true)
  end

  local function funcAnimCallback ()
    self.kMatchData = self:GetItemExchangeMatches (_kBegin, _kTarget)

    -- if #rangeBegin > 0 or #rangeTarget > 0 then
    if #self.kMatchData > 0 then
      self:HandleItemMatchesDestroy ()

      -- 成功交換才要計算步數
      self.nMoveStep = self.nMoveStep + 1
      self:UpdateAndCheckGameLimit ()
    else
      -- 復原該次交換
      kBegin.Item, kTarget.Item = kTarget.Item, kBegin.Item
      kBegin.Item:UpdateItemPosition (_kBegin[1], _kBegin[2], true)
      kTarget.Item:UpdateItemPosition (_kTarget[1], _kTarget[2], true)
      FixDelaySeconds (function() self.nGameState = s_GameState.Playing end, self.DF_ITEM_MOVE_ANIM_SECS)
    end
  end

  kBegin.Item, kTarget.Item = kTarget.Item, kBegin.Item
  kBegin.Item:UpdateItemPosition (_kBegin[1], _kBegin[2], true)
  kTarget.Item:UpdateItemPosition (_kTarget[1], _kTarget[2], true)
  FixDelaySeconds (function() funcAnimCallback () end, self.DF_ITEM_MOVE_ANIM_SECS)
end

function Wnd_Match3_Test.OnClickItemCallback (_kElmGrid)
  if this.nGameState ~= s_GameState.Playing then
    return
  end

  local indexes = _kElmGrid.Indexes
  local Item = this.kGridList[indexes[1]][indexes[2]].Item
  -- TODO:點擊動畫，RoyalMatch每個Item都有點擊動畫(包含不可移動Item)
  if Item and Item:CanDrag () and Item:IsFunctionalItem () then
    this.kMatchData = {}
    table.insert (this.kMatchData, this:GetItemEffectRange (indexes))
    if #this.kMatchData > 0 then
      this.nMoveStep = this.nMoveStep + 1
      this:UpdateAndCheckGameLimit ()
      this:HandleItemMatchesDestroy ()
    end
  end
end

function Wnd_Match3_Test:DropDownItems (_kFallingCol)
  local LoopFallingCheck
  LoopFallingCheck = function ()
    local kFallingItems = {}
    -- 優先從消除的Item正上方掉落
    for col, _ in pairs (_kFallingCol) do
      for row = 1, self.nAllRow do
        local obj = self.kGridList[row][col]
        if obj.Item and obj.Item:PreFallingDown () then
          table.insert (kFallingItems, obj.Item)
          self.kGridList[obj.Item.Indexes[1]][obj.Item.Indexes[2]].Item, obj.Item =
          obj.Item, self.kGridList[obj.Item.Indexes[1]][obj.Item.Indexes[2]].Item
        end
      end
    end

    -- 若正上方沒得落珠再從側上方補
    local obj
    if #kFallingItems == 0 then
      for col = 1, self.nMaxCol do
        for row = 1, self.nAllRow do
          if not kFallingItems[col] then
          end
          obj = self.kGridList[row][col]
          if obj.Item and obj.Item:PreFallingDown2 () then
            table.insert (kFallingItems, obj.Item)
            self.kGridList[obj.Item.Indexes[1]][obj.Item.Indexes[2]].Item, obj.Item =
            obj.Item, self.kGridList[obj.Item.Indexes[1]][obj.Item.Indexes[2]].Item
          end
        end
      end
    end

    -- NOTE:補充預備區的珠子 (若預備區不夠多導致斷珠，則需要修改補充位置)
    for row = self.nMaxRow + 1, self.nAllRow do
      for col, obj in pairs (self.kGridList[row]) do
        if obj.Grid:CanFallingInto () then
          obj.Item = self:SpawnItemToIndex ({row, col}, true)
          if not obj.Item then
            break -- ItemPool不足
          end
        end
      end
    end

    if #kFallingItems > 0 then
      for _, item in pairs (kFallingItems) do
        item:StartFallingDown ()
      end
      FixDelaySeconds (function ()
        LoopFallingCheck ()
      end, self.DF_ITEM_MOVE_ANIM_SECS)
    else
      -- TODO:RoyalMatch在天降時是可以操作其他靜止的珠子的，與企劃討論是否也要相同，目前暫定天降時都不能操作

      self:GetMapMatchData () -- TODO:可傳入非靜止的Item去檢查就好
      if #self.kMatchData > 0 then
        self:HandleItemMatchesDestroy ()
      else
        -- NOTE:回合結束、進行條件與限制的統計與判斷
        local bGameVictory = nil -- nil:遊戲繼續 / true:通關成功 / false:通關失敗
        if self:UpdateAndCheckGameLimit () == false then bGameVictory = false end
        if self.kGameData.Mode == s_EGameMode.Score then
          if self:UpdateAndCheckScore () then bGameVictory = true end
        elseif self.kGameData.Mode == s_EGameMode.Collect then
          if self:UpdateAndCheckCollectionCount () then bGameVictory = true end
        end

        self:UpdateAndCheckScore () -- 暫定:分數常駐顯示

        if bGameVictory ~= nil then
          if self.nGameState ~= s_GameState.GameOver then
            -- NOTE:遊戲結束
            -- TODO:遊戲結算
            self:UpdateStarCount ()
            self:RegistTimer (false)
            self.nGameState = s_GameState.GameOver
            UISendMessage ('Wnd_Message', 'Open', 'icon_message01', bGameVictory and DF_GAME_VICTORY or DF_GAME_OVER)
          end
        else
          -- NOTE:死局檢查
          local check_cnt = 1
          if self:IsGameDeadlock () then -- 上面已經檢查過是否有可以組合消除的，故不需先用StartGamePreCheck檢查
            self:UpdateItemLayout ()
            while check_cnt <= DF_GAMESTART_CHECK_COUNT do
              s_Logger.Debug ("ItemLayoutRefresh count：" .. check_cnt)
              if self:StartGamePreCheck () then
                break
              end
        
              check_cnt = check_cnt + 1
            end
          end
          if check_cnt <= DF_GAMESTART_CHECK_COUNT then
            self.nGameState = s_GameState.Playing
          else
            self.nGameState = s_GameState.FailedToGenerate
            s_Logger.Error ("Failed to init item layout, check it!")
          end
        end
      end
    end
  end

  LoopFallingCheck ()
end

-------------------------------------------------------
-- 處理整理好的消除組合(kMatchData) & 生成對應組合的功能珠
-------------------------------------------------------
function Wnd_Match3_Test:HandleItemMatchesDestroy ()
  -- 消除順序：先處理一般珠子的消除&組合新功能珠(因為不能讓其他消除影響到當前的組合)，再處理功能珠的消除(有交換到功能珠的話)

  -- 先排列好消除順序(優先度高的組合要先消除，以免被優先度低的影響)
  table.sort (self.kMatchData, function (a, b)
    local matchTypeA = s_ItemMatchType.Normal
    for matchType, _ in pairs (a) do
      if matchType > matchTypeA then matchTypeA = matchType end
    end

    local matchTypeB = s_ItemMatchType.Normal
    for matchType, _ in pairs (b) do
      if matchType > matchTypeB then matchTypeB = matchType end
    end

    return matchTypeA >= matchTypeB
  end)

  local kFallingCol = {} -- 用來記錄有珠子消除的欄位
  local LoopDestroyItems
  LoopDestroyItems = function (_kMatchData)
    -- 先處理所有一般珠消除
    -- NOTE:消除優先度高的要先消除
    local kProcessOrder = {}
    for matchType, _ in pairs (_kMatchData) do
      table.insert (kProcessOrder, matchType)
    end
    table.sort (kProcessOrder, function(a, b) return a > b end)

    for _, matchType in pairs (kProcessOrder) do
      local kMatches = _kMatchData[matchType]
      for _, kMatch in pairs (kMatches) do
        if kMatch.DestroyType == s_EItemDestroyType.Normal then
          -- TODO:Destroy effect.

          -- 補加分數(一般珠轉變成功能珠，視為先消除一般珠再轉為功能珠)、合成功能珠
          if kMatch.Center and matchType ~= s_ItemMatchType.Normal then
            if self.kGridList[kMatch.Center[1]][kMatch.Center[2]].Item then
              self:AddScore (self.kGridList[kMatch.Center[1]][kMatch.Center[2]].Item:GetItemScore ())
              self.kGridList[kMatch.Center[1]][kMatch.Center[2]].Item:TransformItemType (s_MatchTypeOfFuncItem[matchType])
            end
          end

          for i, indexes in pairs (kMatch.Range) do
            local item = self.kGridList[indexes[1]][indexes[2]].Item
            if item and item:IsFunctionalItem () == false then
              item:DestroyByMatches ()
              kFallingCol[indexes[2]] = true
            end
          end
        end
      end
    end

    -- 處理剩餘功能珠消除
    for _, kMatches in pairs (_kMatchData) do
      for _, kMatch in pairs (kMatches) do
        if kMatch.DestroyType ~= s_EItemDestroyType.Normal then
          -- TODO:珠子"被"功能珠的攻擊的特效(非自己爆炸的特效)，Ex:炸藥桶的爆炸特效

          self.kGridList[kMatch.Center[1]][kMatch.Center[2]].Item:DestroyByMatches ()
          kFallingCol[kMatch.Center[2]] = true

          for _, indexes in pairs (kMatch.Range) do
            local item = self.kGridList[indexes[1]][indexes[2]].Item
            if item then
              if item:IsFunctionalItem () and (kMatch.Center[1] ~= indexes[1] or kMatch.Center[2] ~= indexes[2]) then -- 擋重複觸發
                LoopDestroyItems (self:GetItemEffectRange (indexes))
              else
                item:DestroyByMatches ()
                kFallingCol[indexes[2]] = true
              end
            end
          end

          -- 處理第二段攻擊，目前只使用在蜻蜓珠的第二段延遲攻擊
          if kMatch.Range2 then
            FixDelaySeconds (function ()
              local item
              kFallingCol = {}
              for _, indexes in pairs (kMatch.Range2) do
                item = self.kGridList[indexes[1]][indexes[2]].Item
                if item then
                  if item:IsFunctionalItem () then
                    LoopDestroyItems (self:GetItemEffectRange (indexes))
                  else
                    item:DestroyByMatches ()
                    kFallingCol[indexes[2]] = true
                  end
                end
              end
              self:DropDownItems (kFallingCol)
            end, self.DF_DRAGONFLY_ATTACKS_DELAY_SECS)
          end
        end
      end
    end
  end

  for _, kMatch in pairs (self.kMatchData) do
    LoopDestroyItems (kMatch)
  end
  self.kMatchData = {}
  self:DropDownItems (kFallingCol)
end

function Wnd_Match3_Test:GetRowAndColById (_index)
  _index = _index - 1
  return math.floor (_index / self.nMaxCol) + 1, (_index % self.nMaxCol) + 1
end


function Wnd_Match3_Test:GetItemRandomType ()
  return math.random (s_EItemType.Item1, self.kGameData.ColorLimit)
end

function Wnd_Match3_Test:GetNearbyValidItems (_index)
  local result, index = {}, 0

  index = _index[1] + 1 -- 上
  if index <= self.nMaxRow and self.kGridList[index][_index[2]].Item then
    table.insert (result, self.kGridList[index][_index[2]].Item)
  end

  index = _index[1] - 1 -- 下
  if index > 0 and self.kGridList[index][_index[2]].Item then
    table.insert (result, self.kGridList[index][_index[2]].Item)
  end

  index = _index[2] - 1 -- 左
  if index > 0 and self.kGridList[_index[1]][index].Item then
    table.insert (result, self.kGridList[_index[1]][index].Item)
  end

  index = _index[2] + 1 -- 右
  if index <= self.nMaxCol and self.kGridList[_index[1]][index].Item then
    table.insert (result, self.kGridList[_index[1]][index].Item)
  end

  return result
end

function Wnd_Match3_Test:GetItemIdByRowAndCol (_row, _col)
  return (self.nMaxCol * (_row - 1) + _col)
end

------------------------------------------------------------------------------------
-- 取得功能珠的攻擊範圍(障礙物也可以攻擊)
-- NOTE:功能珠的消除方式不可以使用s_EItemDestroyType.Normal，否則會干擾一般珠子的消除順序
------------------------------------------------------------------------------------
function Wnd_Match3_Test:GetItemEffectRange (_kFirst, _kSecond)
  local LoopGetRangeByTypes = nil
  LoopGetRangeByTypes = function (range, subRanges, typeFirst, comboType)
    -- NOTE:複合效果發動位置在功能珠移動到的目標位置上

    local nDestroyType
    if typeFirst == s_EItemType.MissleHorizontal then
      -----------------------------------------------------
      -- 水平火箭
      -- 攻擊範圍：該珠子x軸上的所有物件
      -- 拖曳(功能珠)：TODO
      -----------------------------------------------------
      if #range > 1 then
        -- TODO:複合功能，尚未規劃
      else
        local itemIdx = range[1]
        table.remove (range, 1) -- 先移除掉自己以免重複加入
        for currCol = 1, self.nMaxCol do
          if self.kGridList[itemIdx[1]][currCol].Item then
            table.insert (range, { itemIdx[1], currCol })
          end
        end
        nDestroyType = s_EItemDestroyType.MissleHorizontal
      end

    elseif typeFirst == s_EItemType.MissleVertical then
      -----------------------------------------------------
      -- 垂直火箭
      -- 攻擊範圍：該珠子y軸上的所有物件
      -- 拖曳(功能珠)：TODO
      -----------------------------------------------------
      if #range > 1 then
        -- TODO:複合功能，尚未規劃
      else
        local itemIdx = range[1]
        table.remove (range, 1) -- 先移除掉自己以免重複加入
        for currRow = 1, self.nMaxRow do
          if self.kGridList[currRow][itemIdx[2]].Item then
            table.insert (range, { currRow, itemIdx[2] })
          end
        end
      end
      nDestroyType = s_EItemDestroyType.MissleVertical

    elseif typeFirst == s_EItemType.Dragonfly then
      -----------------------------------------------
      -- 蜻蜓珠
      -- 攻擊範圍：二段式攻擊：
      -- 第一段：以自己為中心進行上下左右各一的十字爆炸
      -- 第二段：優先選擇以自身2格距離以上的靜止物件，沒有才選擇周遭的，物件種類選擇優先度：目標道具(Collection) > 一般珠子&障礙物
      -- 拖曳(功能珠)：TODO
      -----------------------------------------------
      if #range > 1 then
        -- TODO:複合功能，尚未規劃
      else
        -- 第一段
        local itemIdx = range[1]
        table.remove (range, 1)

        local Row, Col
        for _, direction in pairs (self.kNeighborDirection) do
          Row, Col = itemIdx[1] + direction[1], itemIdx[2] + direction[2]
          if self.kGridList[Row] and self.kGridList[Row][Col] and self.kGridList[Row][Col].Item then
            table.insert (range, {Row, Col})
          end
        end

        -- 第二段
        local trackingRange = {}
        local bTopBoundary = (itemIdx[1] + 2) > self.nMaxRow and self.nMaxRow or (itemIdx[1] + 2)
        local bBottomBoundary = (itemIdx[1] - 2) < 1 and 1 or (itemIdx[1] - 2)
        local bLeftBoundary = (itemIdx[2] - 2) < 1 and 1 or (itemIdx[2] - 2)
        local bRightBoundary = (itemIdx[2] + 2) > self.nMaxCol and self.nMaxCol or (itemIdx[2] + 2)
        
        -- 尋找範圍外的目標
        for row = 1, self.nMaxRow do
          for col = 1, self.nMaxCol do
            if (row > bTopBoundary or row < bBottomBoundary) or
               (col > bRightBoundary or col < bLeftBoundary) then
              if self.kGridList[row][col].Item and self.kGridList[row][col].Item:CanTrackingByDragonfly () then
                table.insert (trackingRange, {row, col})
              end
            end
          end
        end

        -- 尋找範圍內的目標
        if #trackingRange == 0 then
          for row = 1, self.nMaxRow do
            for col = 1, self.nMaxCol do
              if (row <= bTopBoundary and row >= bBottomBoundary) and
                 (col <= bRightBoundary and col >= bLeftBoundary) then
                if self.kGridList[row][col].Item and self.kGridList[row][col].Item:CanTrackingByDragonfly () then
                  table.insert (trackingRange, {row, col})
                end
              end
            end
          end
        end

        -- 優先找出關卡目標蒐集物，沒有再隨機找一個
        if #trackingRange > 0 then
          for _, indexes in pairs (trackingRange) do
            if self.kGridList[indexes[1]][indexes[2]].Grid:IsCollectionExist () then
              -- NOTE:若追蹤的目標有順序分別可在這邊判斷
              table.insert (subRanges, {indexes[1], indexes[2]})
              break
            end
          end
          if #subRanges == 0 then
            local randomIdx = math.random (1, #trackingRange)
            table.insert (subRanges, {trackingRange[randomIdx][1], trackingRange[randomIdx][2]})
          end
        end
        nDestroyType = s_EItemDestroyType.Dragonfly
      end

    elseif typeFirst == s_EItemType.Ray then
      -----------------------------------------------
      -- 雷射珠(魔王珠)
      -- 攻擊範圍：
      -- 直接點擊：以場上隨機一種色珠(Item1~6)作為目標種類，並攻擊場上全數目標種類
      -- 拖曳(一般珠)：以交換的色珠做為目標種類，並攻擊場上全數目標種類
      -- 拖曳(功能珠)：TODO
      -----------------------------------------------
      if #range > 1 then
        -- TODO:複合功能，尚未規劃
      else
        -- 隨機選擇場上存在的色珠種類
        table.remove (range, 1)

        -- 先分類
        local subRange, item, itemType = {}, nil, nil
        for row = 1, self.nMaxRow do
          for col = 1, self.nMaxCol do
            -- 自己是功能珠所以不會被列入
            item = self.kGridList[row][col].Item
            if item and item:CanTrackingByRay () then
              itemType = item:GetItemType ()
              if not subRange[itemType] then
                subRange[itemType] = {}
              end
              table.insert (subRange[itemType], { row, col })
            end
          end
        end

        local randPool = {}
        for type, _ in pairs (subRange) do
          table.insert (randPool, type)
        end
        if #randPool > 0 then
          itemType = randPool[math.random (1, #randPool)]
          for _, v in pairs (subRange[itemType]) do
            table.insert (range, v)
          end
        end
        nDestroyType = s_EItemDestroyType.Ray
      end

    elseif typeFirst == s_EItemType.Bomb then
      -----------------------------------------------
      -- 炸藥桶
      -- 攻擊範圍：以自身為中心進行5x5的範圍攻擊
      -----------------------------------------------
      if #range > 1 then
        -- TODO:複合功能，尚未規劃
      else
        local itemIdx = range[1]
        local beginRow, beginCol = itemIdx[1] - 2, itemIdx[2] - 2
        table.remove (range, 1) -- 先移除掉自己以免重複加入
        for row = beginRow, beginRow + 4 do
          for col = beginCol, beginCol + 4 do
            if self.kGridList[row] and self.kGridList[row][col] and self.kGridList[row][col].Item then
              table.insert (range, { row, col })
            end
          end
        end
        nDestroyType = s_EItemDestroyType.Bomb
      end
    end

    if comboType then
      return LoopGetRangeByTypes (range, subRanges, comboType)
    else
      return nDestroyType
    end
  end

  local typeFirst = self.kGridList[_kFirst[1]][_kFirst[2]].Item:GetItemType ()
  local comboType = _kSecond ~= nil and self.kGridList[_kSecond[1]][_kSecond[2]].Item:GetItemType () or nil

  local ranges, subRanges = {}, {}
  table.insert (ranges, { _kFirst[1], _kFirst[2] })
  local destroyType = LoopGetRangeByTypes (ranges, subRanges, typeFirst, comboType)
  return {[s_ItemMatchType.Normal] = {{
    Range = ranges,
    Range2 = #subRanges > 0 and subRanges or nil,
    Center = { _kFirst[1], _kFirst[2] },
    DestroyType = destroyType }}}
end

--------------------------------------
-- 找出兩個珠子拖曳交換後所產生的消除組合
--------------------------------------
function Wnd_Match3_Test:GetItemExchangeMatches (_kFirst, _kSecond)
  local kMatches = {}

  local item1 = self.kGridList[_kFirst[1]][_kFirst[2]].Item
  local item2 = self.kGridList[_kSecond[1]][_kSecond[2]].Item
  local bfuncItem1 = self.kGridList[_kFirst[1]][_kFirst[2]].Item:IsFunctionalItem ()
  local bfuncItem2 = self.kGridList[_kSecond[1]][_kSecond[2]].Item:IsFunctionalItem ()

  local kMatch, rangeIds = nil, {}
  if bfuncItem1 and bfuncItem2 then
    -- 功能珠複合功能
    table.insert (kMatches, self:GetItemEffectRange (item1.Indexes, item2.Indexes))
  elseif bfuncItem1 == false and bfuncItem2 == false then
    self:GetItemNeighbors (item1, rangeIds)
    kMatch = self:GetItemMatchByRange (rangeIds)
    if kMatch then
      table.insert (kMatches, kMatch)
    end
    rangeIds = {}
    self:GetItemNeighbors (item2, rangeIds)
    kMatch = self:GetItemMatchByRange (rangeIds)
    if kMatch then
      table.insert (kMatches, kMatch)
    end
  else
    if bfuncItem2 then
      item1, item2 = item2, item1
    end
    table.insert (kMatches, self:GetItemEffectRange (item1.Indexes))
    self:GetItemNeighbors (item2, rangeIds)
    kMatch = self:GetItemMatchByRange (rangeIds)
    if kMatch then
      table.insert (kMatches, kMatch)
    end
  end

  return kMatches
end

-------------------------------------------------------------------------------------------------------------------------------------------
-- NOTE:若有多個消除組合相鄰，只會組合成一個功能珠(優先度最高的)
-- NOTE:優先組合一般珠(組合新功能珠不能受到其他觸發的功能珠影響，不然玩家自己組合好的功能珠會被其他功能珠干擾而導致組合失敗)
-- NOTE:若遇到用功能珠與一般珠交換，此時一般珠可以組合成功能珠，另一個觸發的功能珠不會影響到新組合而成的功能珠，新的功能珠會留做下一次落珠完判斷是否使用
-- @param1:_rangeIds<ItemRangeIds, bool>
-------------------------------------------------------------------------------------------------------------------------------------------
function Wnd_Match3_Test:GetItemMatchByRange (_rangeIds)
  local kMatchRange = {} -- <ItemType, {Range, Center}>
  local rangeRow, rangeCol, rowCount, colCount, itemType, mainRow, mainCol, row, col, kGrid
  for id, _ in pairs (_rangeIds) do
    rangeRow, rangeCol = {}, {}
    mainRow, mainCol = self:GetRowAndColById (id)
    itemType = self.kGridList[mainRow][mainCol].Item:GetItemType ()

    -- 垂直檢查(上)
    row = mainRow + 1
    while row <= self.nMaxRow and
          self.kGridList[row][mainCol].Item and
          self.kGridList[row][mainCol].Item:IsMatch (itemType) do
      table.insert (rangeCol, {row, mainCol})
      row = row + 1
    end

    -- 垂直檢查(下)
    row = mainRow - 1
    while row > 0 and
          self.kGridList[row][mainCol].Item and
          self.kGridList[row][mainCol].Item:IsMatch (itemType) do
      table.insert (rangeCol, {row, mainCol})
      row = row - 1
    end

    -- 水平檢查(左)
    col = mainCol - 1
    kGrid = self.kGridList[mainRow][col]
    while kGrid and kGrid.Item and kGrid.Item:IsMatch (itemType) do
      table.insert (rangeRow, {mainRow, col})
      col = col - 1
      kGrid = self.kGridList[mainRow][col]
    end

    -- 水平檢查(右)
    col = mainCol + 1
    kGrid = self.kGridList[mainRow][col]
    while kGrid and kGrid.Item and kGrid.Item:IsMatch (itemType) do
      table.insert (rangeRow, {mainRow, col})
      col = col + 1
      kGrid = self.kGridList[mainRow][col]
    end

    ----------------------------------------
    -- 判斷珠子組合類型
    ----------------------------------------
    -- NOTE:下方長度判斷因為範圍還不含自己所以通通-1
    -- NOTE:若可以合成功能珠，則消除範圍不該把新功能珠的範圍列入
    -- NOTE:組合優先順序為(以較困難組合成的優先)：炸藥桶>魔王珠(雷色)>垂直/水平火箭>蜻蜓珠>一般三消
    -- NOTE:若已經有珠子組合出功能珠A組合，之後的珠子即便符合條件也不會再組合出另外的功能珠A組合，故先判斷的優先組合
    rowCount, colCount = #rangeRow, #rangeCol
    local CheckItemExist = function (_matchType)
      if not kMatchRange[_matchType] then
        kMatchRange[_matchType] = {}
      else
        -- 檢查是否已存在
        for _, kRange in pairs (kMatchRange[_matchType]) do
          for _, indexes in pairs (kRange.Range) do
            if indexes[1] == mainRow and indexes[2] == mainCol then
              return true
            end
          end
          if kRange.Center and kRange.Center[1] == mainRow and kRange.Center[2] == mainCol then
            return true
          end
        end
      end
      return false
    end

    -----------------------------------------------------
    -- 炸藥桶子
    -- 形成條件：最少五顆珠子相連組合成(十、T、L)
    -- 產生位置：垂直水平交會處
    -----------------------------------------------------
    if rowCount >= 2 and colCount >= 2 then
      if not CheckItemExist (s_ItemMatchType.Bomb) then
        local range = {}
        for _, v in pairs (rangeRow) do table.insert (range, v) end
        for _, v in pairs (rangeCol) do table.insert (range, v) end
        table.insert (kMatchRange[s_ItemMatchType.Bomb], { Range = range, Center = {mainRow, mainCol}, DestroyType = s_EItemDestroyType.Normal })
      end

    -----------------------------------------------------
    -- 魔王珠(雷色)
    -- 形成條件：單排超過5顆以上
    -- 產生位置：該組合中心處
    -----------------------------------------------------
    elseif rowCount >= 4 or colCount >= 4 then
      if not CheckItemExist (s_ItemMatchType.Ray) then
        local range = {}
        table.insert (range, {mainRow, mainCol})
        if rowCount >= 4 then
          for _, v in pairs (rangeRow) do table.insert (range, v) end
          table.sort (range, function (a, b) return a[1] < b[1] end)
        elseif colCount >= 4 then
          for _, v in pairs (rangeCol) do table.insert (range, v) end
          table.sort (range, function (a, b) return a[2] < b[2] end)
        end
        local center = math.ceil (#range / 2)
        local index = range[center]
        table.remove (range, center)
        table.insert (kMatchRange[s_ItemMatchType.Ray], { Range = range, Center = {index[1], index[2]}, DestroyType = s_EItemDestroyType.Normal })
      end

    -----------------------------------------------------
    -- 垂直火箭
    -- 形成條件：4顆橫排
    -- 產生位置：四顆中間兩顆隨機一顆
    -----------------------------------------------------
    elseif rowCount >= 3 then
      if not CheckItemExist (s_ItemMatchType.MissleV) then
        table.insert (rangeRow, {mainRow, mainCol})
        table.sort (rangeRow, function (a, b) return a[1] < b[1] end)
        local center = math.random (3, 4)
        local index = rangeRow[center]
        table.remove (rangeRow, center)
        table.insert (kMatchRange[s_ItemMatchType.MissleV], { Range = rangeRow, Center = {index[1], index[2]}, DestroyType = s_EItemDestroyType.Normal })
      end

    -----------------------------------------------------
    -- 水平火箭
    -- 形成條件：4顆直排
    -- 產生位置：四顆中間兩顆隨機一顆
    -----------------------------------------------------
    elseif colCount >= 3 then
      if not CheckItemExist (s_ItemMatchType.MissleH) then
        table.insert (rangeCol, {mainRow, mainCol})
        table.sort (rangeCol, function (a, b) return a[2] < b[2] end)
        local center = math.random (3, 4)
        local index = rangeCol[center]
        table.remove (rangeCol, center)
        table.insert (kMatchRange[s_ItemMatchType.MissleH], { Range = rangeCol, Center = {index[1], index[2]}, DestroyType = s_EItemDestroyType.Normal })
      end

    -----------------------------------------------------
    -- 蜻蜓珠:
    -- 形成條件：由四顆珠子組合成(田)
    -- 產生位置：發起檢查並且配對到的那顆
    -- NOTE：蜻蜓珠的判斷範圍較特殊，故需額外判斷
    -----------------------------------------------------
    elseif rowCount >= 1 and colCount >= 1 then
      local range = {}
      for _, indexCol in pairs (rangeCol) do
        if s_Math.abs (indexCol[1] - mainRow) == 1 then
          for _, indexRow in pairs (rangeRow) do
            if s_Math.abs (indexRow[2] - mainCol) == 1 then
              if self.kGridList[indexCol[1]][indexRow[2]].Item and self.kGridList[indexCol[1]][indexRow[2]].Item:IsMatch (itemType) then
                if not CheckItemExist (s_ItemMatchType.Dragonfly) then
                  table.insert (range, {indexCol[1], mainCol})
                  table.insert (range, {mainRow, indexRow[2]})
                  table.insert (range, {indexCol[1], indexRow[2]})
                  table.insert (kMatchRange[s_ItemMatchType.Dragonfly], { Range = range, Center = {mainRow, mainCol}, DestroyType = s_EItemDestroyType.Normal })
                  break
                end
              end
            end
          end
        end
        if #range > 0 then break end
      end

    -----------------------------------------------------
    -- 一般三消:
    -- 形成條件：三顆橫排或直排的珠子
    -----------------------------------------------------
    else
      if #rangeRow >= 2 then
        if not CheckItemExist (s_ItemMatchType.Normal) then
          table.insert (rangeRow, {mainRow, mainCol})
          table.insert (kMatchRange[s_ItemMatchType.Normal], { Range = rangeRow, DestroyType = s_EItemDestroyType.Normal })
        end
      elseif #rangeCol >= 2 then
        if not CheckItemExist (s_ItemMatchType.Normal) then
          table.insert (rangeCol, {mainRow, mainCol})
          table.insert (kMatchRange[s_ItemMatchType.Normal], { Range = rangeCol, DestroyType = s_EItemDestroyType.Normal })
        end
      end
    end
  end

  if next (kMatchRange) then
    return kMatchRange
  else
    return nil
  end
end

function Wnd_Match3_Test.IsAdjacent (_kBegin, _kTarget)
  return (_kBegin[1] == _kTarget[1] and math.abs (_kTarget[2] - _kBegin[2]) == 1)
      or (_kBegin[2] == _kTarget[2] and math.abs (_kTarget[1] - _kBegin[1]) == 1)
end

return Wnd_Match3_Test

/*
 * 介面排版參考：Match 3 Jelly Garden Kit
 * https://assetstore.unity.com/packages/templates/systems/match-3-jelly-garden-kit-43260
 */

using System.Collections.Generic;
using System.IO;
using System.Text;
using UnityEngine;
using UnityEditor;
using System;
using UnityEditor.SceneManagement;

namespace SLG.Match3
{

[InitializeOnLoad]
public class Match3MakerEditor : EditorWindow
{
    static Match3MakerEditor Window;
    static int SelectedToolBar;
    static string[] toolbarTitles = new string[] {"Editor", "Maker Settings"};
    static Vector2 ScrollViewVector = Vector2.zero;
    static int ExportFileId = 1;  // 檔案名稱又為LuaQueryTable的Key，故以數字儲存

    // 當前格子選取屬性
    static EGridType UsingGridType;
    static EItemType UsingItemType;
    static EMatch3GameSubTarget UsingCollectionType;

    static CMatch3GameConfig currGameConfig;
    static Dictionary<EItemType, int> ItemScore = new Dictionary<EItemType, int>(); // 目前由EditorConfig讀入，而非GameConfig
    static Dictionary<EItemType, Color> ItemColor = new Dictionary<EItemType, Color>();
    static Dictionary<EGridType, string> GridImgName = new Dictionary<EGridType, string>();
    static Dictionary<EItemType, string> ItemImgName = new Dictionary<EItemType, string>();
    static Dictionary<EMatch3GameSubTarget, string> CollectionImgName = new Dictionary<EMatch3GameSubTarget, string>();
    static Dictionary<EGridType, Texture> GridImgs = new Dictionary<EGridType, Texture>();
    static Dictionary<EItemType, Texture> ItemImgs = new Dictionary<EItemType, Texture>();
    static Dictionary<EMatch3GameSubTarget, Texture> CollectionImgs = new Dictionary<EMatch3GameSubTarget, Texture>();
    private static Dictionary<EItemType, string> ItemDescription = new Dictionary<EItemType, string>();
    private static Dictionary<EGridType, string> GridDescription = new Dictionary<EGridType, string>();
    static Dictionary<int, CMatch3GameConfig> QueryTable;
    static string ExportQueryTableFolder = "/GDD";
    static string FullExportPath = "";
    enum EToolBar
    {
      Editor,
      Settings
    }

    [MenuItem ("傳奇工具包/Match-3-Maker Editor")]  // NOTE:自行修改工具路徑

    public static void Init ()
    {
      QueryTable = new Dictionary<int, CMatch3GameConfig>();

      // Init parameters.
      foreach (EGridType type in Enum.GetValues (typeof (EGridType)))
        GridImgName[type] = "";

      foreach (EItemType type in Enum.GetValues (typeof (EItemType))) {
        ItemColor[type] = new Color (1, 1, 1);
        ItemImgName[type] = ""; 
        ItemScore[type] = 0;
      }

      foreach (EMatch3GameSubTarget type in Enum.GetValues (typeof (EMatch3GameSubTarget)))
        CollectionImgName[type] = "";

      GridDescription[EGridType.NONE] = "None";
      GridDescription[EGridType.NORMAL] = "Normal";
      GridDescription[EGridType.FROZEN] = "Frozen";

      // Load editor config.
      string configDir = Application.dataPath + "/LibModules/Match3Editor/Editor/";
      string filePath = System.IO.Path.Combine (configDir, "Match3EditorConfig.txt");
      StreamReader sw = null;
      if (System.IO.File.Exists (filePath))
        sw = new StreamReader (filePath);
      
      if (sw != null) {
        List<string> strLines = new List<string>();
        string line;
        while ((line = sw.ReadLine ()) != null)
          strLines.Add (line);
        
        foreach (string strLine in strLines) {
          // Lua輸出路徑
          if (strLine.StartsWith ("QUERY_TABLE_EXPORT_PATH:")) {
            ExportQueryTableFolder = strLine.Replace ("QUERY_TABLE_EXPORT_PATH:", string.Empty);
            FullExportPath = DataQuery.ExcelParserWindows.AssetPath + ExportQueryTableFolder + DataQuery.ExcelParserWindows.ClientLuaPath;
          }

          // 格子圖片
          else if (strLine.StartsWith ("GRID_FROZEN_IMAGE:")) {
            string strImgName = strLine.Replace ("GRID_FROZEN_IMAGE:", string.Empty);
            GridImgName[EGridType.FROZEN] = strImgName.Replace ("\r", string.Empty);;
          }
          else if (strLine.StartsWith ("ITEM_OBSTACLE_IMAGE:")) {
            string strImgName = strLine.Replace ("ITEM_OBSTACLE_IMAGE:", string.Empty);
            ItemImgName[EItemType.Obstacle] = strImgName.Replace ("\r", string.Empty);;
          }
          else if (strLine.StartsWith ("ITEM_DOUBLE_OBSTACLE_IMAGE:")) {
            string strImgName = strLine.Replace ("ITEM_DOUBLE_OBSTACLE_IMAGE:", string.Empty);
            ItemImgName[EItemType.Double_obstacle] = strImgName.Replace ("\r", string.Empty);;
          }
          else if (strLine.StartsWith ("COLLECTION1_IMAGE:")) {
            string strImgName = strLine.Replace ("COLLECTION1_IMAGE:", string.Empty);
            CollectionImgName[EMatch3GameSubTarget.Collection1] = strImgName.Replace ("\r", string.Empty);;
          }
          else if (strLine.StartsWith ("COLLECTION2_IMAGE:")) {
            string strImgName = strLine.Replace ("COLLECTION2_IMAGE:", string.Empty);
            CollectionImgName[EMatch3GameSubTarget.Collection2] = strImgName.Replace ("\r", string.Empty);;
          }
          else if (strLine.StartsWith ("COLLECTION3_IMAGE:")) {
            string strImgName = strLine.Replace ("COLLECTION3_IMAGE:", string.Empty);
            CollectionImgName[EMatch3GameSubTarget.Collection3] = strImgName.Replace ("\r", string.Empty);;
          }

          // Item消除分數配置
          else if (strLine.StartsWith ("ITEM_SCORE:")) {
            string strScore = strLine.Replace ("ITEM_SCORE:", string.Empty);
            string[] strScores = strScore.Split (';');
            foreach (string strSubScore in strScores) {
              string[] strData = strSubScore.Split ('/');
              ItemScore[(EItemType)int.Parse (strData[0])] = int.Parse (strData[1]);
            }
          }
          // Item方塊顏色
          else if (strLine.StartsWith ("ITEM_COLOR:")) {
            string strItemColor = strLine.Replace ("ITEM_COLOR:", string.Empty);
            string[] strColors = strItemColor.Split (';');
            for (int i = 0; i < strColors.Length; i++) {
              string[] colors = strColors[i].Split ('/');
              ItemColor[(EItemType)i] = new Color (float.Parse (colors[0]), float.Parse (colors[1]), float.Parse (colors[2]));
            }
          }
        }
      }
      if (sw != null)
        sw.Close ();

      currGameConfig = new CMatch3GameConfig (1, in ItemScore);
      LoadDataFromLocal ();
      ParserLevelConfig (ExportFileId);

      Window = (Match3MakerEditor)EditorWindow.GetWindow (typeof (Match3MakerEditor));
      Window.Show ();
    }

    void OnDestroy ()
    {
      SaveEditorConfig ();
    }

    void SaveEditorConfig ()
    {
      string strSave = "";

      strSave += "QUERY_TABLE_EXPORT_PATH:" + ExportQueryTableFolder;
      strSave += "\n";
      strSave += "GRID_NORMAL_IMAGE:" + GridImgName[EGridType.NORMAL];
      strSave += "\n";
      strSave += "GRID_FROZEN_IMAGE:" + GridImgName[EGridType.FROZEN];
      strSave += "\n";
      strSave += "ITEM_OBSTACLE_IMAGE:" + ItemImgName[EItemType.Obstacle];
      strSave += "\n";
      strSave += "ITEM_DOUBLE_OBSTACLE_IMAGE:" + ItemImgName[EItemType.Double_obstacle];
      strSave += "\n";
      strSave += "COLLECTION1_IMAGE:" + CollectionImgName[EMatch3GameSubTarget.Collection1];
      strSave += "\n";
      strSave += "COLLECTION2_IMAGE:" + CollectionImgName[EMatch3GameSubTarget.Collection2];
      strSave += "\n";
      strSave += "COLLECTION3_IMAGE:" + CollectionImgName[EMatch3GameSubTarget.Collection3];

      // Item消除分數配置
      strSave += "\n";
      strSave += "ITEM_SCORE:";
      string strScoreConfig = "";
      foreach (EItemType type in Enum.GetValues (typeof (EItemType))) {
        if (strScoreConfig != "")
          strScoreConfig += ";";
        strScoreConfig += ((int)type).ToString () + "/" + ItemScore[type];
      }
      strSave += strScoreConfig;

      // 方塊顏色
      strSave += "\n";
      strSave += "ITEM_COLOR:";
      string strItemColor = "";
      foreach (var i in ItemColor) {
        if (strItemColor != "")
          strItemColor += ";";
        strItemColor += ItemColor[i.Key].r.ToString () + "/" + ItemColor[i.Key].g.ToString () + "/" + ItemColor[i.Key].b.ToString ();
      }
      strSave += strItemColor;

      string saveDir = Application.dataPath + "/LibModules/Match3Editor/Editor/";
      string filePath = System.IO.Path.Combine (saveDir, "Match3EditorConfig.txt");
      StreamWriter sw = new StreamWriter (filePath);
      sw.Write (strSave);
      sw.Close ();
      AssetDatabase.Refresh ();
    }

    void OnFocus ()
    {
    }

    void OnGUI ()
    {
      ScrollViewVector = GUI.BeginScrollView (new Rect (0, 0, position.width, position.height), ScrollViewVector, new Rect (0, 0, 600, 1400), false, false);
      GUILayout.Space (20);
      GUILayout.BeginHorizontal ();
      GUILayout.Space (30);
      int oldSelectedToolbar = SelectedToolBar;
      SelectedToolBar = GUILayout.Toolbar (SelectedToolBar, toolbarTitles, new GUILayoutOption[] { GUILayout.Width (300) });
      GUILayout.EndHorizontal ();

      if (oldSelectedToolbar != SelectedToolBar)
        ScrollViewVector = Vector2.zero;

      GUILayout.Space (10);
      if (SelectedToolBar == (int)EToolBar.Editor) {
          GUIEditorFile ();
          GUILayout.Space (10);

          GUITestLevel ();
          GUILayout.Space (10);

          GUITarget ();
          GUILayout.Space (10);

          GUILayoutParameters ();
          GUILayout.Space (10);

          GUIStars ();
          GUILayout.Space (10);

          GUIGridLayoutTools ();
          GUILayout.Space (10);
          
          if (currGameConfig.GameMode == EMatch3GameTarget.COLLECT) {
            GUICollectionType ();
            GUILayout.Space (10);
          }

          GUIItemType ();
          GUILayout.Space (10);

          GUIGridTypes ();
          GUILayout.Space (10);
          
          GUIGridLayout ();
          GUILayout.Space (10);
      }
      else if (SelectedToolBar == (int)EToolBar.Settings) {
        GUIMakerSetting ();
      }

      GUI.EndScrollView();
    }

    void GUIShowWarnningMsg (string msg)
    {
      GUILayout.Space (100);
      GUILayout.Label ("CAUTION!", EditorStyles.boldLabel, new GUILayoutOption[] {GUILayout.Width (600)});
      GUILayout.Label (msg, EditorStyles.boldLabel, new GUILayoutOption[] { GUILayout.Width (600) });
    }

    void GUIEditorFile ()
    {
      GUILayout.BeginHorizontal ();
      GUILayout.Space (30);
      GUILayout.Label ("Edit file:", EditorStyles.boldLabel, new GUILayoutOption[] { GUILayout.Width (100) });
      int FileName = EditorGUILayout.IntField (ExportFileId, new GUILayoutOption[] { GUILayout.Width (100) });
      if (FileName != ExportFileId)
        ParserLevelConfig (FileName);
      ExportFileId = FileName;

      if (GUILayout.Button ("Save", new GUILayoutOption[] { GUILayout.Width (50) })) {
        SaveLevel ();
      }
      GUILayout.EndHorizontal ();
    }

    void GUITestLevel ()
    {
      GUILayout.BeginHorizontal ();
      GUILayout.Space (30);
      GUILayout.Label ("Level editor:", EditorStyles.boldLabel, new GUILayoutOption[] { GUILayout.Width (100) });
      if (GUILayout.Button ("Test Level", new GUILayoutOption[] { GUILayout.Width (150) }))
        DoLevelTest ();
      GUILayout.EndHorizontal ();
    }

    void GUILayoutParameters ()
    {
      GUILayout.BeginHorizontal ();
      GUILayout.Space (30);
      GUILayout.BeginVertical ();
      GUILayout.Label ("Layout Parameters:", EditorStyles.boldLabel, new GUILayoutOption[] { GUILayout.Width (200) });

      // LayoutSize
      currGameConfig.MaxRows = EditorGUILayout.IntField ("Rows", currGameConfig.MaxRows, new GUILayoutOption[] { GUILayout.Width (50), GUILayout.MaxWidth (200) });
      currGameConfig.MaxCols = EditorGUILayout.IntField ("Cols", currGameConfig.MaxCols, new GUILayoutOption[] { GUILayout.Width (50), GUILayout.MaxWidth (200) });
      if (currGameConfig.MaxRows < CMatch3MakerInfo.ROWS_SIZE_MIN)
        currGameConfig.MaxRows = CMatch3MakerInfo.ROWS_SIZE_MIN;
      else if (currGameConfig.MaxRows > CMatch3MakerInfo.ROWS_SIZE_MAX)
        currGameConfig.MaxRows = CMatch3MakerInfo.ROWS_SIZE_MAX;

      if (currGameConfig.MaxCols < CMatch3MakerInfo.ROWS_SIZE_MIN)
        currGameConfig.MaxCols = CMatch3MakerInfo.COLUMNS_SIZE_MIN;
      else if (currGameConfig.MaxCols > CMatch3MakerInfo.COLUMNS_SIZE_MAX)
        currGameConfig.MaxCols = CMatch3MakerInfo.COLUMNS_SIZE_MAX;

      // Limit
      GUILayout.BeginHorizontal ();
      GUILayout.Label ("Limit", new GUILayoutOption[] { GUILayout.Width (105) });
      currGameConfig.LimitType = (ELimitType)EditorGUILayout.EnumPopup (currGameConfig.LimitType, GUILayout.Width (92));
      switch (currGameConfig.LimitType) {
        case ELimitType.NONE:
          currGameConfig.LimitVal = 0;
        break;

        case ELimitType.STEPUSAGE:
        {
          currGameConfig.LimitVal = EditorGUILayout.IntField (currGameConfig.LimitVal, new GUILayoutOption[] { GUILayout.Width (50) });
        }
        break;

        case ELimitType.TIME:
        {
          int nLimitMin = EditorGUILayout.IntField (currGameConfig.LimitVal / 60, new GUILayoutOption[] {  GUILayout.Width (30) });
          GUILayout.Label (":", new GUILayoutOption [] { GUILayout.Width (10) });
          int nLimitSec = EditorGUILayout.IntField (currGameConfig.LimitVal % 60, new GUILayoutOption[] {  GUILayout.Width (30) });
          currGameConfig.LimitVal = nLimitMin * 60 + nLimitSec;
        }
        break;
      }
      GUILayout.EndHorizontal ();

      // Color Limit
      GUILayout.BeginHorizontal ();
      GUILayout.Label ("ColorLimit", new GUILayoutOption[] { GUILayout.Width (110) });
      currGameConfig.ColorTypeLimit = (int)GUILayout.HorizontalSlider (currGameConfig.ColorTypeLimit, CMatch3MakerInfo.COLOR_TYPES_LIMIT_MIN, CMatch3MakerInfo.COLOR_TYPES_LIMIT_MAX, new GUILayoutOption[] { GUILayout.Width (87) });
      currGameConfig.ColorTypeLimit = EditorGUILayout.IntField (currGameConfig.ColorTypeLimit, new GUILayoutOption[] { GUILayout.Width (50) });
      if (currGameConfig.ColorTypeLimit < CMatch3MakerInfo.COLOR_TYPES_LIMIT_MIN)
        currGameConfig.ColorTypeLimit = CMatch3MakerInfo.COLOR_TYPES_LIMIT_MIN;
      else if (currGameConfig.ColorTypeLimit > CMatch3MakerInfo.COLOR_TYPES_LIMIT_MAX)
        currGameConfig.ColorTypeLimit = CMatch3MakerInfo.COLOR_TYPES_LIMIT_MAX;
      GUILayout.EndHorizontal ();
      // TODO:防呆:預防目標設定無法達成

      GUILayout.EndVertical ();
      GUILayout.EndHorizontal ();
    }

    void GUIStars ()
    {
      GUILayout.BeginHorizontal ();
      GUILayout.Space (30);
      GUILayout.BeginVertical ();
      GUILayout.Label ("Stars:", EditorStyles.boldLabel, new GUILayoutOption[] { GUILayout.Width (100) });

      GUILayout.BeginHorizontal ();
      GUILayout.Space (30);
      GUILayout.Label ("Star1", new GUILayoutOption[] { GUILayout.Width (100) });
      GUILayout.Label ("Star2", new GUILayoutOption[] { GUILayout.Width (100) });
      GUILayout.Label ("Star3", new GUILayoutOption[] { GUILayout.Width (100) });
      GUILayout.EndHorizontal ();

      GUILayout.BeginHorizontal ();
      GUILayout.Space (30);
      for (int i = 0; i < CMatch3MakerInfo.STARS_COUNT; ++i)
        currGameConfig.StarRequiredScore[i] = EditorGUILayout.IntField (currGameConfig.StarRequiredScore[i], new GUILayoutOption[] { GUILayout.Width (100) });
      GUILayout.EndHorizontal ();

      GUILayout.EndVertical ();
      GUILayout.EndHorizontal ();
    }

    void GUITarget ()
    {
      GUILayout.BeginHorizontal ();
      GUILayout.Space (30);
      GUILayout.BeginVertical ();
      GUILayout.Label ("Target:", EditorStyles.boldLabel, new GUILayoutOption[] { GUILayout.Width (100) });

      GUILayout.BeginHorizontal ();
      GUILayout.Space (30);
      GUILayout.BeginVertical ();

      EMatch3GameTarget oldGameMode = currGameConfig.GameMode;
      currGameConfig.GameMode = (EMatch3GameTarget)EditorGUILayout.EnumPopup (currGameConfig.GameMode, GUILayout.Width (100));
      // 切換GameMode就重製條件
      if (oldGameMode != currGameConfig.GameMode) {
        foreach (Match3Condition condition in currGameConfig.Conditions) {
          condition.type = EMatch3GameSubTarget.NONE;
          condition.value = 0;
        }
      }

      switch (currGameConfig.GameMode) {
        // 目標：達到基本星星分數
        case EMatch3GameTarget.SCORE:
        {
          ref List<Match3Condition> condition = ref currGameConfig.Conditions;
          currGameConfig.Conditions[0].type = EMatch3GameSubTarget.NONE;
          currGameConfig.Conditions[0].value = EditorGUILayout.IntField (currGameConfig.Conditions[0].value, new GUILayoutOption[] { GUILayout.Width (100) });
        }
        break;

        // 目標：消除並蒐集指定物件
        case EMatch3GameTarget.COLLECT:
        {
          foreach (Match3Condition condition in currGameConfig.Conditions) {
            GUILayout.BeginHorizontal ();
            condition.type = (EMatch3GameSubTarget)EditorGUILayout.EnumPopup (condition.type, GUILayout.Width (100));
            if (condition.type != EMatch3GameSubTarget.NONE)
              condition.value = EditorGUILayout.IntField (condition.value, new GUILayoutOption[] { GUILayout.Width (100) });
            else
              condition.value = 0;
            GUILayout.EndHorizontal ();
          }
        }
        break;
      }
      GUILayout.EndVertical ();
      GUILayout.EndHorizontal ();
      GUILayout.EndVertical ();
      GUILayout.EndHorizontal ();
    }

    void GUIGridLayoutTools ()
    {
      GUILayout.BeginHorizontal ();
      GUILayout.Space (30);
      // GUILayout.BeginVertical ();
      GUILayout.Label ("Layout Tools:", EditorStyles.boldLabel, new GUILayoutOption[] { GUILayout.Width (100) });
      if (GUILayout.Button ("Reset", new GUILayoutOption[] { GUILayout.Width (50), GUILayout.Height (50) })) {
        for  (int i = 0; i < currGameConfig.GridLayout.GetLength (0); ++i) {
          for (int j = 0; j < currGameConfig.GridLayout.GetLength (1); ++j) {
            currGameConfig.GridLayout[i, j].Grid = EGridType.NORMAL;
            currGameConfig.GridLayout[i, j].Item = EItemType.RANDOM;
            currGameConfig.GridLayout[i, j].Collection = EMatch3GameSubTarget.NONE;
          }
        }
      }
      GUILayout.EndHorizontal ();
    }

    void GUICollectionType ()
    {
      foreach (var it in CollectionImgName) {
        Texture image = Resources.Load (CMatch3MakerInfo.SOURCE_IMAGE_FOLDER + it.Value) as Texture;
        CollectionImgs[it.Key] = image;
      }

      GUILayout.BeginHorizontal ();
      GUILayout.Space (30);
      GUILayout.BeginVertical ();
      GUILayout.Label ("CollectionType:", EditorStyles.boldLabel);
      GUILayout.BeginHorizontal ();
      GUILayout.Space (30);

      List<string> strCollection = new List<string>() {"", "Item1", "Item2", "Item3"};
      foreach (EMatch3GameSubTarget type in Enum.GetValues (typeof (EMatch3GameSubTarget))) {
        if (type == EMatch3GameSubTarget.NONE) continue;
        if (CollectionImgs[type] != null) {
          if (GUILayout.Button (CollectionImgs[type], new GUILayoutOption[] { GUILayout.Width (50), GUILayout.Height (50) })) {
            UsingCollectionType = type;
          }
        }
        else {
          if (GUILayout.Button (strCollection[(int)type], new GUILayoutOption[] { GUILayout.Width (50), GUILayout.Height (50) })) {
            UsingCollectionType = type;
          }
        }
      }

      GUI.color = Color.white;
      GUILayout.EndHorizontal ();
      GUILayout.EndVertical ();
      GUILayout.EndHorizontal ();
    }
    void GUIItemType ()
    {
      foreach (var it in ItemImgName) {
        Texture image = Resources.Load (CMatch3MakerInfo.SOURCE_IMAGE_FOLDER + it.Value) as Texture;
        ItemImgs[it.Key] = image;
      }

      GUILayout.BeginHorizontal ();
      GUILayout.Space (30);
      GUILayout.BeginVertical ();
      GUILayout.Label ("ItemType:", EditorStyles.boldLabel);
      GUILayout.BeginHorizontal ();
      GUILayout.Space (30);

      EItemType[] itemTypes = new EItemType[] {
      // NormalItem
        EItemType.RANDOM,
        EItemType.Item1,
        EItemType.Item2,
        EItemType.Item3,
        EItemType.Item4,
        EItemType.Item5,
        EItemType.Item6,
        // ObstacleItem
        EItemType.Obstacle,
        EItemType.Double_obstacle,
      };

      short max_num_in_row = 7;
      GUILayout.BeginVertical ();
      for (int i = 0; i < itemTypes.Length; i += max_num_in_row) {
        GUILayout.BeginHorizontal ();
        for (int j = i; j < (i + max_num_in_row) && j < itemTypes.Length; ++j) {
          EItemType type = itemTypes[j];
          if (type == EItemType.Obstacle || type == EItemType.Double_obstacle)
            GUI.color = Color.white;
          else
            GUI.color = new Color (ItemColor[type].r, ItemColor[type].g, ItemColor[type].b);
          
          if (GUILayout.Button (ItemImgs[type], new GUILayoutOption[] { GUILayout.Width (50), GUILayout.Height (50) })) {
            UsingItemType = type;
          }
        }
        GUILayout.EndHorizontal ();
      }
      GUILayout.EndVertical ();

      GUI.color = Color.white;
      GUILayout.EndHorizontal ();
      GUILayout.EndVertical ();
      GUILayout.EndHorizontal ();
    }

    void GUIGridTypes ()
    {
      foreach (var it in GridImgName) {
        Texture image = Resources.Load (CMatch3MakerInfo.SOURCE_IMAGE_FOLDER + it.Value) as Texture;
        GridImgs[it.Key] = image;
      }

      GUILayout.BeginHorizontal ();
      GUILayout.Space (30);
      GUILayout.BeginVertical ();
      GUILayout.Label ("GridTypes:", EditorStyles.boldLabel);

      EGridType[] grid_types = new EGridType[] {
        EGridType.NONE, 
        EGridType.NORMAL, 
        EGridType.FROZEN, 
      };
      
      GUILayout.BeginHorizontal ();
      GUILayout.Space (30);
      GUILayout.BeginVertical ();
      int max_num_in_row = 2;
      for (int i = 0; i < grid_types.Length; i += max_num_in_row) {
        GUILayout.BeginHorizontal ();
        for (int j = i; j < (i + max_num_in_row) && j < grid_types.Length; ++j) {
          EGridType gridType = grid_types[j];
          GUI.color = (gridType != EGridType.NONE)? Color.white : CMatch3MakerInfo.GridNoneColor;
          if (GUILayout.Button (GridImgs[gridType], new GUILayoutOption[] {GUILayout.Width (50), GUILayout.Height (50)})) {
            UsingGridType = gridType;
          }
          GUILayout.Label (" - " + GridDescription[gridType], new GUILayoutOption[] { GUILayout.Width (200) });
        }
        GUILayout.EndHorizontal ();
      }
      GUILayout.EndVertical ();
      GUILayout.EndHorizontal ();
      GUILayout.EndVertical ();
      GUILayout.EndHorizontal ();
    }

    void GUIGridLayout ()
    {
      GUILayout.BeginHorizontal ();
      GUILayout.Space (50);
      GUILayout.BeginVertical ();
      GUILayout.Space (30);
      for (int row = 0; row < currGameConfig.MaxRows; row++) {
        GUILayout.BeginHorizontal ();
        for (int col = 0; col < currGameConfig.MaxCols; col++) {
          ref Match3Grid GridObj = ref currGameConfig.GridLayout[row, col];
          Color buttonColor;
          Texture buttonImg = null;
          if (GridObj.Grid == EGridType.NONE) {
            buttonColor = CMatch3MakerInfo.GridNoneColor;
          }
          else {
            // 格子配置顯示，因應企劃實際需求修改顯示優先度
            buttonColor = ItemColor[GridObj.Item];
            buttonImg = ItemImgs[GridObj.Item];
          }
          
          // 設定格子的預設狀態
          GUI.color = buttonColor;
          string toolTip = String.Format ("GridType：{0}\nItemType：{1}\nCollectionType：{2}", GridObj.Grid, GridObj.Item, GridObj.Collection);
          if (GUILayout.Button (new GUIContent (buttonImg, toolTip), new GUILayoutOption[] { GUILayout.Width (50), GUILayout.Height (50) })) {
            GridObj.Grid = UsingGridType;
            if (UsingGridType == EGridType.NONE) {
              GridObj.Item = EItemType.RANDOM;
              GridObj.Collection = EMatch3GameSubTarget.NONE;
            }
            else {
              GridObj.Item = UsingItemType;
              GridObj.Collection = UsingCollectionType;
            }
          }
        }
        GUILayout.EndHorizontal ();
      }
      GUILayout.EndVertical ();
      GUILayout.EndHorizontal ();
    }

    void GUIMakerSetting ()
    {
      GUILayout.BeginHorizontal ();
      GUILayout.Space (30);
      GUILayout.BeginVertical ();

      GUILayout.Space (30);
      ExportQueryTableFolder = EditorGUILayout.TextField ("Query table export path:", ExportQueryTableFolder, new GUILayoutOption[] { GUILayout.Width (300) });
      FullExportPath = DataQuery.ExcelParserWindows.AssetPath + ExportQueryTableFolder + DataQuery.ExcelParserWindows.ClientLuaPath;

      GUILayout.Label ("Score Settings:", EditorStyles.boldLabel);
      GUILayout.Space (10);
      GUILayout.BeginHorizontal ();
      GUILayout.Space (20);
      GUILayout.BeginVertical ();
      ItemScore[EItemType.Item1] = EditorGUILayout.IntField ("Score Item1", ItemScore[EItemType.Item1], new GUILayoutOption[] { GUILayout.Width (50), GUILayout.MaxWidth (250) });
      ItemScore[EItemType.Item2] = EditorGUILayout.IntField ("Score Item2", ItemScore[EItemType.Item2], new GUILayoutOption[] { GUILayout.Width (50), GUILayout.MaxWidth (250) });
      ItemScore[EItemType.Item3] = EditorGUILayout.IntField ("Score Item3", ItemScore[EItemType.Item3], new GUILayoutOption[] { GUILayout.Width (50), GUILayout.MaxWidth (250) });
      ItemScore[EItemType.Item4] = EditorGUILayout.IntField ("Score Item4", ItemScore[EItemType.Item4], new GUILayoutOption[] { GUILayout.Width (50), GUILayout.MaxWidth (250) });
      ItemScore[EItemType.Item5] = EditorGUILayout.IntField ("Score Item5", ItemScore[EItemType.Item5], new GUILayoutOption[] { GUILayout.Width (50), GUILayout.MaxWidth (250) });
      ItemScore[EItemType.Item6] = EditorGUILayout.IntField ("Score Item6", ItemScore[EItemType.Item6], new GUILayoutOption[] { GUILayout.Width (50), GUILayout.MaxWidth (250) });
      ItemScore[EItemType.Obstacle] = EditorGUILayout.IntField ("Score Obstacle", ItemScore[EItemType.Obstacle], new GUILayoutOption[] { GUILayout.Width (50), GUILayout.MaxWidth (250) });
      ItemScore[EItemType.Double_obstacle] = EditorGUILayout.IntField ("Score DoubleObstacle", ItemScore[EItemType.Double_obstacle], new GUILayoutOption[] { GUILayout.Width (50), GUILayout.MaxWidth (250) });
      ItemScore[EItemType.MissionHorizon] = EditorGUILayout.IntField ("Score MissionHorizon", ItemScore[EItemType.MissionHorizon], new GUILayoutOption[] { GUILayout.Width (50), GUILayout.MaxWidth (250) });
      ItemScore[EItemType.MissionVertical] = EditorGUILayout.IntField ("Score MissionVertical", ItemScore[EItemType.MissionVertical], new GUILayoutOption[] { GUILayout.Width (50), GUILayout.MaxWidth (250) });
      ItemScore[EItemType.Dragonfly] = EditorGUILayout.IntField ("Score Dragonfly", ItemScore[EItemType.Dragonfly], new GUILayoutOption[] { GUILayout.Width (50), GUILayout.MaxWidth (250) });
      ItemScore[EItemType.Ray] = EditorGUILayout.IntField ("Score Ray", ItemScore[EItemType.Ray], new GUILayoutOption[] { GUILayout.Width (50), GUILayout.MaxWidth (250) });
      ItemScore[EItemType.Bomb] = EditorGUILayout.IntField ("Score Bomb", ItemScore[EItemType.Bomb], new GUILayoutOption[] { GUILayout.Width (50), GUILayout.MaxWidth (250) });
      GUILayout.EndVertical ();
      GUILayout.EndHorizontal ();

      GUILayout.Space (30);
      GUILayout.Label ("Item Color Settings:", EditorStyles.boldLabel);
      GUILayout.Space (10);
      GUILayout.BeginHorizontal ();
      GUILayout.Space (20);
      GUILayout.BeginVertical ();
      ItemColor[EItemType.RANDOM] = EditorGUILayout.ColorField ("Random Color", ItemColor[EItemType.RANDOM], new GUILayoutOption[] {GUILayout.MaxWidth (200)});
      ItemColor[EItemType.Item1] = EditorGUILayout.ColorField ("Item1 Color", ItemColor[EItemType.Item1], new GUILayoutOption[] {GUILayout.MaxWidth (200)});
      ItemColor[EItemType.Item2] = EditorGUILayout.ColorField ("Item2 Color", ItemColor[EItemType.Item2], new GUILayoutOption[] {GUILayout.MaxWidth (200)});
      ItemColor[EItemType.Item3] = EditorGUILayout.ColorField ("Item3 Color", ItemColor[EItemType.Item3], new GUILayoutOption[] {GUILayout.MaxWidth (200)});
      ItemColor[EItemType.Item4] = EditorGUILayout.ColorField ("Item4 Color", ItemColor[EItemType.Item4], new GUILayoutOption[] {GUILayout.MaxWidth (200)});
      ItemColor[EItemType.Item5] = EditorGUILayout.ColorField ("Item5 Color", ItemColor[EItemType.Item5], new GUILayoutOption[] {GUILayout.MaxWidth (200)});
      ItemColor[EItemType.Item6] = EditorGUILayout.ColorField ("Item6 Color", ItemColor[EItemType.Item6], new GUILayoutOption[] {GUILayout.MaxWidth (200)});
      GUILayout.EndVertical ();
      GUILayout.EndHorizontal ();

      GUILayout.Space (30);
      GUILayout.Label ("Image Settings(Display Only):", EditorStyles.boldLabel);
      GUILayout.Space (10);
      GUILayout.BeginHorizontal ();
      GUILayout.Space (20);
      GUILayout.BeginVertical ();
      GridImgName[EGridType.FROZEN] = EditorGUILayout.TextField ("Grid Frozen", GridImgName[EGridType.FROZEN], new GUILayoutOption[] { GUILayout.Width (300) });
      GUILayout.Space (20);
      // TODO:其他項目有需要顯示再補
      ItemImgName[EItemType.Obstacle] = EditorGUILayout.TextField ("Item obstacle", ItemImgName[EItemType.Obstacle], new GUILayoutOption[] { GUILayout.Width (300) });
      ItemImgName[EItemType.Double_obstacle] = EditorGUILayout.TextField ("Item Double-obstacle", ItemImgName[EItemType.Double_obstacle], new GUILayoutOption[] { GUILayout.Width (300) });
      GUILayout.Space (20);
      CollectionImgName[EMatch3GameSubTarget.Collection1] = EditorGUILayout.TextField ("Collection1", CollectionImgName[EMatch3GameSubTarget.Collection1], new GUILayoutOption[] { GUILayout.Width (300) });
      CollectionImgName[EMatch3GameSubTarget.Collection2] = EditorGUILayout.TextField ("Collection2", CollectionImgName[EMatch3GameSubTarget.Collection2], new GUILayoutOption[] { GUILayout.Width (300) });
      CollectionImgName[EMatch3GameSubTarget.Collection3] = EditorGUILayout.TextField ("Collection3", CollectionImgName[EMatch3GameSubTarget.Collection3], new GUILayoutOption[] { GUILayout.Width (300) });
      GUILayout.EndVertical ();
      GUILayout.EndHorizontal ();

      GUILayout.EndVertical ();
      GUILayout.EndHorizontal ();
    }

    void DoLevelTest ()
    {
      // PlayerPrefs.SetInt ()
    }

    public static void ParserLevelConfig (int currFileId)
    {
      if (QueryTable.ContainsKey (currFileId))
        currGameConfig = QueryTable[currFileId];
      else
        currGameConfig = new CMatch3GameConfig (currFileId, in ItemScore);
    }

    public static void LoadDataFromLocal ()
    {
      string file_directory = Application.dataPath + "/LibModules/Match3Editor/Match3Levels/";
      string[] file_list = Directory.GetFiles (file_directory);
      
      foreach (string file in file_list) {
        if (file.Substring (file.Length - 4, 4) == ".txt") {
          StreamReader sw = new StreamReader (file);
          string line;
          List<string> strLines = new List<string>();
          while ((line = sw.ReadLine ()) != null)
            strLines.Add (line);

          // 解析出檔名 & 檔案內容
          int begin = file.IndexOf (file_directory);
          int file_id;
          bool isNumeric = int.TryParse (file.Substring (begin + file_directory.Length).Replace (".txt", string.Empty), out file_id);
          if (!isNumeric)
            continue;

          QueryTable[file_id] = GetProcessGameDataFromString (file_id, ref strLines);
          sw.Close ();
        }
      }
    }

    void SaveLevel () {
      foreach (EGridType type in Enum.GetValues (typeof (EGridType))) {
        if (type == EGridType.NONE)
          continue;
        currGameConfig.GridImages[type] = GridImgName[type];
      }

      foreach (EItemType type in Enum.GetValues (typeof (EItemType))) {
        currGameConfig.ItemImages[type] = ItemImgName[type];
        currGameConfig.ItemScore[type] = ItemScore[type];
      }

      foreach (EMatch3GameSubTarget type in Enum.GetValues (typeof (EMatch3GameSubTarget))) {
        currGameConfig.CollectionImages[type] = CollectionImgName[type];
      }

      QueryTable[ExportFileId] = currGameConfig;

      SaveLevelFile ();

      // 輸出:LuaQueryTable
      DataQuery.Match3QueryTable.ExportLuaTable (ref QueryTable, FullExportPath);
    }

    public void SaveLevelFile ()
    {
      string strSave;
      foreach (var it in QueryTable) {
        strSave = "";
        CMatch3GameConfig game_data = it.Value;
        
        // 遊戲目標
        strSave += "MODE:" + (int)game_data.GameMode;
        strSave += "\n";
        strSave += "CONDITIONS:";
        for (int i = 0; i < game_data.Conditions.Count; ++i) {
          if (i != 0)
            strSave += ";";
          strSave += (int)game_data.Conditions[i].type + "/" + game_data.Conditions[i].value;
        }

        // Layout尺寸
        strSave += "\n";
        strSave += "LAYOUTSIZE:" + game_data.MaxCols + "/" + game_data.MaxRows;

        // 限制
        strSave += "\n";
        strSave += "LIMIT:" + (int)game_data.LimitType + "/" + game_data.LimitVal;

        // 色珠種類數量
        strSave += "\n";
        strSave += "COLOR_LIMIT:" + game_data.ColorTypeLimit;

        // 星數所需分數
        strSave += "\n";
        strSave += "STARS:";
        for (int i = 0; i < CMatch3MakerInfo.STARS_COUNT; ++i) {
          if (i != 0)
            strSave += "/";
          strSave += (int)game_data.StarRequiredScore[i];
        }

        // Layout
        strSave += "\n";
        for (int row = 0; row < game_data.MaxRows; ++row) {
          for (int col = 0; col < game_data.MaxCols; ++col) {
            strSave += ((int)game_data.GridLayout[row, col].Grid).ToString () + ((int)game_data.GridLayout[row, col].Item).ToString () + ((int)game_data.GridLayout[row, col].Collection).ToString ();
            if (col < (game_data.MaxCols - 1))
              strSave += " ";
          }
          if (row < (game_data.MaxRows - 1))
            strSave += "\n";
        }

        // 輸出:Editor方便讀取的.txt文件
        // TODO:搬運到適當位置&使用更合適的文件格式儲存
        string filePath = System.IO.Path.Combine (Application.dataPath + "/LibModules/Match3Editor/" + CMatch3MakerInfo.LEVEL_CONFIG_FOLDER, it.Key.ToString () + ".txt");
        StreamWriter sw = new StreamWriter (filePath, false, Encoding.UTF8);
        sw.Write (strSave);
        sw.Close ();
      }
      AssetDatabase.Refresh ();
    }

    static CMatch3GameConfig GetProcessGameDataFromString (in int Id, ref List<string> strLines)
    {
      CMatch3GameConfig game_data = new CMatch3GameConfig (Id, in ItemScore);
      int nLayoutRow = 0;
      foreach (string strLine in strLines) {
        // 遊戲目標
        if (strLine.StartsWith ("MODE:")) {
          string strMode = strLine.Replace ("MODE:", string.Empty);
          game_data.GameMode = (EMatch3GameTarget)int.Parse (strMode);
        }
        // 目標條件 (目前只有 蒐集 使用)
        else if (strLine.StartsWith ("CONDITIONS:")) {
          string strCondition = strLine.Replace ("CONDITIONS:", string.Empty);
          string[] strConditions = strCondition.Split (';');
          for (int i = 0; i < strConditions.Length && i < game_data.Conditions.Count; ++i) {
            string[] condition = strConditions[i].Split ('/');
            game_data.Conditions[i].type = (EMatch3GameSubTarget)int.Parse (condition[0]);
            game_data.Conditions[i].value = int.Parse (condition[1]);
          }
        }
        // Layout尺寸
        else if (strLine.StartsWith ("LAYOUTSIZE:")) {
          string strLayoutSize = strLine.Replace ("LAYOUTSIZE:", string.Empty);
          string[] strSizes = strLayoutSize.Split ('/');
          game_data.MaxCols = int.Parse (strSizes[0]);
          game_data.MaxRows = int.Parse (strSizes[1]);
        }
        // 限制
        else if (strLine.StartsWith ("LIMIT:")) {
          string strLimit = strLine.Replace ("LIMIT:", string.Empty);
          string[] strLimits = strLimit.Split ('/');
          game_data.LimitType = (ELimitType)int.Parse (strLimits[0]);
          game_data.LimitVal = int.Parse (strLimits[1]);
        }
        // 色珠種類數量
        else if (strLine.StartsWith ("COLOR_LIMIT:")) {
          string strColorLimit = strLine.Replace ("COLOR_LIMIT:", string.Empty);
          game_data.ColorTypeLimit = int.Parse (strColorLimit);
        }
        // 星數所需分數(1~3)
        else if (strLine.StartsWith ("STARS:")) {
          string strStar = strLine.Replace ("STARS:", string.Empty);
          string[] strStars = strStar.Split ('/');
          for (int i = 0; i < CMatch3MakerInfo.STARS_COUNT; i++)
            game_data.StarRequiredScore[i] = int.Parse (strStars[i]);
        }
        // Layout
        else {
          string[] strLayouts = strLine.Split (' ');
          for (short col = 0; col < strLayouts.Length; ++col) {
            game_data.GridLayout[nLayoutRow, col].Grid = (EGridType)int.Parse (strLayouts[col][0].ToString ());
            game_data.GridLayout[nLayoutRow, col].Item = (EItemType)int.Parse (strLayouts[col][1].ToString ());
            game_data.GridLayout[nLayoutRow, col].Collection = (EMatch3GameSubTarget)int.Parse (strLayouts[col][2].ToString ());
          }
          nLayoutRow++;
        }
      }

      return game_data;
    }
}

}
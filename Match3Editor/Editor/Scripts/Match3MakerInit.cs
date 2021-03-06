using System.Collections.Generic;
using UnityEngine;
using System;


namespace SLG.Match3
{

public struct Match3Grid
{
  public EGridType Grid;
  public EItemType Item;
  public EMatch3GameSubTarget Collection;
}

public class Match3Condition
{
  public EMatch3GameSubTarget type;
  public int value;
}

public class CMatch3GameConfig
{
    public int Id;
    public EMatch3GameTarget GameMode;
    public List<Match3Condition> Conditions;
    public int MaxRows;
    public int MaxCols;
    public ELimitType LimitType;
    public int LimitVal;
    public int ColorTypeLimit;
    public int[] StarRequiredScore;
    public Dictionary<EItemType, int> ItemScore;
    public Dictionary<EGridType, string> GridImages;
    public Dictionary<EItemType, string> ItemImages;
    public Dictionary<EMatch3GameSubTarget, string> CollectionImages;
    public Match3Grid[,] GridLayout;

    public CMatch3GameConfig (int id, in Dictionary<EItemType, int> itemScore)
    {
      Id = id;

      Conditions = new List<Match3Condition> ();
      for (short i = 0; i < CMatch3MakerInfo.CONDITION_MAX_NUM; ++i)
        Conditions.Add (new Match3Condition ());

      StarRequiredScore = new int[CMatch3MakerInfo.STARS_COUNT];

      ItemScore = itemScore;

      GridImages = new Dictionary<EGridType, string> ();

      ItemImages = new Dictionary<EItemType, string> ();

      CollectionImages = new Dictionary<EMatch3GameSubTarget, string> ();

      Match3Grid initGrid = new Match3Grid ();
      initGrid.Grid = EGridType.NORMAL;
      GridLayout = new Match3Grid[CMatch3MakerInfo.ROWS_SIZE_MAX, CMatch3MakerInfo.COLUMNS_SIZE_MAX];
      for (int i = 0; i < CMatch3MakerInfo.ROWS_SIZE_MAX; i++) {
        for (int j = 0; j < CMatch3MakerInfo.COLUMNS_SIZE_MAX; j++) {
          GridLayout[i, j] = initGrid;
        }
      }
    }
}

public class CMatch3MakerInfo
{
  public static string LEVEL_CONFIG_FOLDER = "Match3Levels/";
  public static string SOURCE_IMAGE_FOLDER = "sourceImg/";
  public static int ROWS_SIZE_MIN = 3;
  public static int COLUMNS_SIZE_MIN = 3;
  public static int ROWS_SIZE_MAX = 9;
  public static int COLUMNS_SIZE_MAX = 9;
  public static int COLOR_TYPES_LIMIT_MIN = 3;
  public static int COLOR_TYPES_LIMIT_MAX = 6;
  public static int CONDITION_MAX_NUM = 3;
  public static int STARS_COUNT = 3;
  public static int Item_TYPE_NUM = 6;
  public static Color GridNoneColor = new Color (0.7f, 0.7f, 0.7f);
}

public enum ELimitType
{
  NONE,
  STEPUSAGE,
  TIME
}

/* 
 * 1. Grid/Obstacle????????????????????????10????????????????????????????????? (?????????Config????????????????????????(??????)????????????????????????)
 * 2. ????????????Editor??????????????????????????????
 */
public enum EGridType
{
  NONE = 1,         // ?????????
  NORMAL,           // ????????????
  FROZEN,           // ????????????
}

public enum EItemType
{
  RANDOM,           // ?????? (Item1~6)
  Item1,
  Item2,
  Item3,
  Item4,
  Item5,
  Item6,
  Obstacle,         // ????????????
  Double_obstacle,  // ????????????
  MissionHorizon,   // ????????????
  MissionVertical,  // ????????????
  Dragonfly,        // ?????????
  Ray,              // ?????????
  Bomb,             // ?????????
}
public enum EMatch3GameTarget
{
  SCORE,
  COLLECT
}

public enum EMatch3GameSubTarget
{
  NONE,
  Collection1,
  Collection2,
  Collection3,
}

}
using System.Collections.Generic;
using System.Text;

namespace SLG.DataQuery
{
  [System.Serializable]
  public class Match3QueryRow : IQueryData
  {
    public int m_Id;
    string m_Mode;
    List<string> m_Conditions;
    string m_LayoutSize;
    string m_Limit;
    int m_ColorTypeLimit;
    string m_ScoreForStars;
    List<string> m_ItemScore;

    // 改為讀取固定格式
    // List<string> m_GridImages;
    // List<string> m_ItemImages;
    // List<string> m_CollectionImages;
    List<string> m_Layout;

    public override int ID { get { return m_Id; } }

    public override string OutLuaRow (ref int level)
    {
      StringBuilder content = new StringBuilder ();
      content.Append (GetOneField ("Id"           ,level, GetValueString (m_Id)));
      content.Append (GetOneField ("Mode"         ,level, m_Mode));
      AppendStringArray (level, ref content, "Conditions" , ref m_Conditions);
      content.Append (GetOneField ("LayoutSize"   ,level, m_LayoutSize));
      content.Append (GetOneField ("Limit"        ,level, m_Limit));
      content.Append (GetOneField ("ColorLimit"   ,level, GetValueString (m_ColorTypeLimit)));
      content.Append (GetOneField ("ScoreForStars",level, m_ScoreForStars));
      AppendStringArray (level, ref content, "ItemScore"  , ref m_ItemScore);
      // 改為讀取固定格式
      // AppendStringArray (level, ref content, "GridImages" , ref m_GridImages);
      // AppendStringArray (level, ref content, "ItemImages" , ref m_ItemImages);
      // AppendStringArray (level, ref content, "CollectionImages" , ref m_CollectionImages);
      AppendStringArray (level, ref content, "Layout"     , ref m_Layout);
      return content.ToString ();
    }

    public void HandleSpecialData (Match3.CMatch3GameConfig query, ref int level)
    {
      m_Id = query.Id;

      m_Mode = ((int)query.GameMode).ToString ();

      m_Conditions = new List<string>();
      foreach (Match3.Match3Condition condition in query.Conditions) {
        if (condition.value == 0) continue;
        string str = "{ ";
        str += $"type = {((int)condition.type)}, value = {condition.value}";
        str += " }";
        m_Conditions.Add (str);
      }

      m_LayoutSize += "{ ";
      m_LayoutSize += $"maxRows = {query.MaxRows}, maxCols = {query.MaxCols}";
      m_LayoutSize += " }";

      m_Limit += "{ ";
      m_Limit += $"type = {(int)query.LimitType}, value = {query.LimitVal}";
      m_Limit += " }";

      m_ColorTypeLimit = query.ColorTypeLimit;

      m_ScoreForStars = "{ ";
      for (int i = 0; i < query.StarRequiredScore.Length; ++i) {
        if (i != 0)
          m_ScoreForStars += ", ";
        m_ScoreForStars += query.StarRequiredScore[i].ToString ();
      }
      m_ScoreForStars += " }";

      m_ItemScore = new List<string>();
      foreach (var it in query.ItemScore) {
        if (it.Key == Match3.EItemType.RANDOM)
          continue;
        string str = $"[{(int)it.Key}] = {it.Value}";
        m_ItemScore.Add (str);
      }

      // 改為讀取固定格式
      // m_GridImages = new List<string>();
      // foreach (var it in query.GridImages) {
      //   if (it.Key == Match3.EGridType.NONE || it.Key == Match3.EGridType.NORMAL)
      //     continue;
      //   string str = $"[{(int)it.Key}] = \"{it.Value}\"";
      //   m_GridImages.Add (str);
      // }

      // m_ItemImages = new List<string> ();
      // foreach (var it in query.ItemImages) {
      //   if (it.Key != Match3.EItemType.Obstacle && it.Key != Match3.EItemType.Double_obstacle)
      //     continue;
      //   string str = $"[{(int)it.Key}] = \"{it.Value}\"";
      //   m_ItemImages.Add (str);
      // }
      
      // m_CollectionImages = new List<string> ();
      // foreach (var it in query.CollectionImages) {
      //   if (it.Key == Match3.EMatch3GameSubTarget.NONE)
      //     continue;
      //   string str = $"[{(int)it.Key}] = \"{it.Value}\"";
      //   m_CollectionImages.Add (str);
      // }

      m_Layout = new List<string>();
      for (int i = 0; i < query.MaxRows; ++i) {
        string str = "{ ";
        for (int j = 0; j < query.MaxCols; ++j) {
          if (j != 0)
            str += ", ";
          str += ((int)query.GridLayout[i, j].Grid).ToString () + ((int)query.GridLayout[i, j].Item).ToString () + ((int)query.GridLayout[i, j].Collection).ToString ();
        }
        str += " }";
        m_Layout.Add (str);
      }
    }
  }

  public sealed class Match3QueryTable
  {
    public static void ExportLuaTable (ref Dictionary<int, Match3.CMatch3GameConfig> queryTable, in string assetPath)
    {
      int level = 1;
      StringBuilder content = new StringBuilder ();
      Match3QueryRow queryRow = null;
      foreach (KeyValuePair<int, Match3.CMatch3GameConfig> query in queryTable) {
        content.Append (IQueryData.GetLuaTableIndentation (level));
        content.AppendFormat ("[{0}]", query.Key);
        content.AppendLine (" = {");
        level++;
        queryRow = new Match3QueryRow ();
        queryRow.HandleSpecialData (query.Value, ref level);
        content.Append (queryRow.OutLuaRow (ref level));
        level--;
        content.Append (IQueryData.GetLuaTableIndentation (level));
        content.AppendLine ("},");
      }

      string query_data = content.ToString ();
      LuaQueryTableExporter.ExportLuaQueryTable (GetVersion (), GetLuaName (), assetPath, "", "", ref query_data);
    }

    public static int GetVersion () { return 1; }

    public static string GetTableName ()
    {
      return "三消表";
    }

    public static string GetLuaName ()
    {
      return "Match3Query";
    }
  }

}
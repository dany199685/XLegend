using System.Collections.Generic;
using System.IO;
using UnityEngine;
using UnityEditor;

public class ImageCuttingTool : EditorWindow
{
  string ExportImagePath = "/RawResources/UI/Texture_Dynamic/icon_event/icon_event_puzzle01/pack_event_puzzle_a/";
  string SourceImagePath = "/RawResources/UI/Texture_Dynamic/icon_event/icon_event_puzzle01/pack_event_puzzle_a/";
  int Row = 1;
  int Col = 1;
  bool IsSelectAll = false;
  string[] ImageList;
  Dictionary<string, bool> SelectedList;
  Vector2 ScrollViewVector = Vector2.zero;
  public const string FILE_NAME_PNG = ".png";

  [MenuItem ("傳奇工具包/切圖工具")]
  static public void Init ()
  {
    ImageCuttingTool window = GetWindow<ImageCuttingTool>();
    window.ShowUtility ();
  }

  public void OnGUI ()
  {
    GUILayout.BeginVertical ();
    GUILayout.Space (10);

    GUILayout.BeginHorizontal ();
    GUILayout.Label ("來源路徑:");
    string ols_source_path = SourceImagePath;
    SourceImagePath = EditorGUILayout.TextField (ols_source_path);
    if (SourceImagePath != ols_source_path) {
      IsSelectAll = false;
      SelectedList.Clear ();
    }
    GUILayout.Label ("輸出路徑:");
    ExportImagePath = EditorGUILayout.TextField (ExportImagePath);
    GUILayout.EndHorizontal ();

    GUILayout.BeginHorizontal ();
    GUILayout.Label ("Row:");
    Row = EditorGUILayout.IntField (Row);
    GUILayout.Label ("Col:");
    Col = EditorGUILayout.IntField (Col);

    bool bClickAll = false;
    if (GUILayout.Button ("All")) {
      bClickAll = true;
      IsSelectAll = IsSelectAll ? false : true;
    }
    if (GUILayout.Button ("Export")) {
      Export ();
    }
    GUILayout.EndHorizontal ();
    GUILayout.Box ("", GUILayout.ExpandWidth (true), GUILayout.Height (1)); // 分隔線

    ScrollViewVector = GUILayout.BeginScrollView (ScrollViewVector, false, false);
    if (Directory.Exists (Application.dataPath + SourceImagePath)) {

      if (SelectedList == null)
        SelectedList = new Dictionary<string, bool>();

      ImageList = Directory.GetFiles (Application.dataPath + SourceImagePath);
      foreach (string file in ImageList) {
        string file_name = GetImageName (file);
        if (string.IsNullOrEmpty (file_name))
          continue;
        
        bool isSelected = false;
        if (bClickAll) {
          SelectedList[file_name] = IsSelectAll;
          isSelected = IsSelectAll;
        }
        else {
          if (SelectedList.ContainsKey(file_name))
            isSelected = SelectedList[file_name];
        }

        isSelected = GUILayout.Toggle (isSelected, file_name);
        SelectedList[file_name] = isSelected;
      }
    }
    GUILayout.EndScrollView ();
    GUILayout.EndVertical ();
  }

  string GetImageName (string file)
  {
    string file_name = "";
    if (file.EndsWith (FILE_NAME_PNG)) {
      file_name = file.Trim ((Application.dataPath + SourceImagePath).ToCharArray ());
      file_name = file_name.Trim ('.');
      file_name = file_name.Trim ('\\');
      file_name = file_name.Trim (FILE_NAME_PNG.ToCharArray ());
    }
    return file_name;
  }

  // 從Assets直接讀取的Sprite無法直接讀取(因為Unity為了節省性能，所以預設為不可讀)，故需要以副本的方式讀取(或者可以改ImportSettings-Read/Write Enable)
  Texture2D GetTextureDuplicate (Texture2D source)
  {
    RenderTexture renderTex = RenderTexture.GetTemporary (
      source.width,
      source.height,
      0,
      RenderTextureFormat.Default,
      RenderTextureReadWrite.Linear
    );

    Graphics.Blit (source, renderTex);
    RenderTexture previous = RenderTexture.active;
    RenderTexture.active = renderTex;
    Texture2D readableText = new Texture2D (source.width, source.height);
    readableText.ReadPixels (new Rect (0, 0, renderTex.width, renderTex.height), 0, 0);
    readableText.Apply ();
    RenderTexture.active = previous;
    RenderTexture.ReleaseTemporary (renderTex);
    return readableText;
  }

  public void Export ()
  {
    foreach (var it in SelectedList) {
      if (!it.Value)
        continue;
      
      // 切圖規則：若該欄寬/列高無法被指定欄數/列數整除時，則取整數部分即可，並靠上靠左(像素從左上角開始計算)
      // Ex：列高50/欄寬60、裁切列數6/欄數7，每張的列高為8/欄寬8
      // 第一排欄寬 1~8, 9~16, 17~24, ... 40~48
      // 第一欄列高 1~8, 9~16, 17~24, ... 48~56

      Texture2D texture = GetTextureDuplicate (AssetDatabase.LoadAssetAtPath<Sprite> ("Assets" + SourceImagePath + it.Key + FILE_NAME_PNG).texture);
      if (texture) {
        int width = texture.width / Col;
        int height = texture.height / Row;
        int beginX, beginY;
        for (int r = 0; r < Row; ++r) {
          for (int c = 0; c < Col; ++c) {
            // texture像素起始點為左下角，終點為右上角
            beginX = width * c;
            beginY = texture.height - height * (r + 1);
            Texture2D subImage = new Texture2D (width, height);
            for (int x = 0; x < width; ++x) {
              for (int y = 0; y < height; ++y) {
                subImage.SetPixel (x, y, texture.GetPixel (beginX + x, beginY + y));
              }
            }
            subImage.Apply ();
            byte[] bytes = subImage.EncodeToPNG ();
            // 命名規則：原圖名 + _sub_ + (r + Col*c)
            string export_path = Application.dataPath + ExportImagePath + it.Key + "_sub_" + (c + Col * r).ToString () + FILE_NAME_PNG;
            File.WriteAllBytes (export_path, bytes);
          }
        }
      }
    }
  }
}
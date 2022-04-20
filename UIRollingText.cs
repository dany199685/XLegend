using UnityEngine.UI;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/*
 * 使用說明：
 * -> Pivot應設置在物件左邊(x=0)，座標與物件移動的算法是以pivot置於左邊的前提做計算
 * -> ContentSizeFitter.enabled預設要關掉，才能正確抓取文字初始長度
 * -> 目前只適用於"ui_"和"wnd_"開頭的物件，並且需在上方掛有CanvasGroup方能正確啟動
 * -> RefObject為選用，若不提供則預設使用文字自己的pivot做參考點；若提供則以該物件的pivot作參考點
 * -> 跑馬燈移動方向流程(以往左滑動為例)為：(BEGIN -> T1 -> T2 -> BEGIN) loop...
 *    T1 -------- BEGIN -------- T2
*/

public class UIRollingText : MonoBehaviour
{
    public GameObject RefObject     = null;
    public float RollingRange       = 0.0f;
    public float PaddingLeft        = 0.0f;
    public float PaddingRight       = 0.0f;
    [Range (-1000.0f, 1000.0f)]    
    public float MoveSpeed          = 0.0f; // (MoveSpeed < 0) ? 向左移動 : 向右移動
    public float DelayPlayTime      = 0.0f;

    private bool m_bPlay            = false;
    private CanvasGroup m_cvgParentUI;
    private Text m_kText;
    private RectTransform m_kRectTransform;
    private float m_nInitWidth;             // 文字起始長度 (未開啟ContentSizeFitter時的長度)   備註：開啟ContentSizeFitter不影響文字原本的高度、對齊方式
    private float m_nInitPos;               // 文字初始位置
    private float m_nRollingBeginPos;       // 文字跑馬燈重製位置
    private float m_nRollingT1Pos;          // 文字跑馬燈目標位置1 (先)
    private float m_nRollingT2Pos;          // 文字跑馬燈目標位置2 (後)
    private bool  m_nMoveToT1;              // true:T1 / false:T2

    Coroutine m_DelayPlayCoroutine;

    public float rollingRange
    {
        get { return RollingRange; }
        set {
            RollingRange = value;
            CheckAndPlay ();
        }
    }
    public string text
    {
        get { return m_kText.text; }
        set { 
            m_kText.text = value; 
            CheckAndPlay ();
        }
    }

    void Start ()
    {
        if (m_cvgParentUI)
            CheckAndPlay ();
    }

    void Awake ()
    {
        m_kText = gameObject.GetComponent<Text>();
        m_kRectTransform = GetComponent<RectTransform>();
        m_nInitPos = transform.localPosition.x;
        m_nInitWidth = GetComponent<RectTransform>().rect.width;

        Transform checkObj = transform;
        string token = "";
        while (checkObj.parent) {
            checkObj = checkObj.parent;
            token = (checkObj.name.IndexOf ("_") != -1) ? checkObj.name.Substring (0, checkObj.name.IndexOf ("_")).ToLower () : checkObj.name;
            if (token == "ui" || token == "wnd") {
                m_cvgParentUI = checkObj.gameObject.GetComponent<CanvasGroup>();
                break;
            }
        }
        if (token != "ui" && token != "wnd")
            Debug.LogError (transform.name + "'s parentUI's name is " + checkObj.name + " ,but it should be a string beginning with \"ui\" or \"wnd\".");

        // 1. ContentSizeFitter預設需要是關閉的，以便把一開始企劃設定的文字長度存起來，以便之後不撥放跑馬燈時要進行文字對齊時可使用
        // 2. 存好初始長度後，在開啟此元件計算當下文字長度，判定是否需要撥放跑馬燈流程 或使用預設文字框的對齊顯示
        GetComponent<ContentSizeFitter>().enabled = true;
    }

    void Update ()
    {
        if (!m_bPlay || m_cvgParentUI.alpha == 0)
            return;
        
        float newX = transform.localPosition.x + Time.deltaTime * MoveSpeed;
        if (MoveSpeed < 0) {
            // 向左移動
            if (m_nMoveToT1) {
                if (newX > m_nRollingT1Pos)
                    transform.localPosition = new Vector3 (newX, transform.localPosition.y);
                else {
                    transform.localPosition = new Vector3 (m_nRollingT2Pos, transform.localPosition.y);
                    m_nMoveToT1 = false;
                }
            }
            else {
                if (newX > m_nRollingBeginPos)
                    transform.localPosition = new Vector3 (newX, transform.localPosition.y);
                else {
                    transform.localPosition = new Vector3 (m_nRollingBeginPos, transform.localPosition.y);
                    if (m_DelayPlayCoroutine != null)
                        StopCoroutine (m_DelayPlayCoroutine);

                    m_DelayPlayCoroutine = StartCoroutine (DelayReplay ());
                }
            }
        }
        else {
            // 向右移動
            if (m_nMoveToT1) {
                if (newX < m_nRollingT1Pos)
                    transform.localPosition = new Vector3 (newX, transform.localPosition.y);
                else {
                    transform.localPosition = new Vector3 (m_nRollingT2Pos, transform.localPosition.y);
                    m_nMoveToT1 = false;
                }
            }
            else {
                if (newX < m_nRollingBeginPos)
                    transform.localPosition = new Vector3 (newX, transform.localPosition.y);
                else {
                    transform.localPosition = new Vector3 (m_nRollingBeginPos, transform.localPosition.y);
                    if (m_DelayPlayCoroutine != null)
                        StopCoroutine (m_DelayPlayCoroutine);

                    m_DelayPlayCoroutine = StartCoroutine (DelayReplay ());
                }
            }
        }
    }

    private IEnumerator UpdateContent (bool _bResetPos = true, bool _replay = false)
    {
        GetComponent<ContentSizeFitter>().enabled = true;
        
        yield return new WaitForEndOfFrame ();

        if (m_kRectTransform.rect.width > RollingRange) {
            if (!_replay) {
                if (MoveSpeed < 0) {
                    // T1 ------- BEGIN ------- T2
                    if (RefObject) {
                        float localX = TargetConvertToLocalX (RefObject.transform.position).x;
                        m_nRollingBeginPos = localX + PaddingLeft;
                        m_nRollingT1Pos = localX - m_kRectTransform.rect.width - PaddingRight;
                        m_nRollingT2Pos = localX + RefObject.GetComponent<RectTransform>().rect.width + PaddingLeft;
                    }
                    else {
                        m_nRollingBeginPos = m_nInitPos + PaddingLeft;
                        m_nRollingT1Pos = m_nInitPos - m_kRectTransform.rect.width - PaddingRight;
                        m_nRollingT2Pos = m_nInitPos + m_kRectTransform.rect.width + PaddingLeft;
                    }
                }
                else {
                    // T2 ------- BEGIN ------- T1
                    if (RefObject) {
                        float localX = TargetConvertToLocalX (RefObject.transform.position).x;
                        m_nRollingBeginPos = localX + PaddingLeft;
                        m_nRollingT1Pos = localX + RefObject.GetComponent<RectTransform>().rect.width + PaddingLeft;
                        m_nRollingT2Pos = localX - m_kRectTransform.rect.width - PaddingRight;
                    }
                    else {
                        m_nRollingBeginPos = m_nInitPos + PaddingLeft;
                        m_nRollingT1Pos = m_nInitPos + m_kRectTransform.rect.width + PaddingLeft;
                        m_nRollingT2Pos = m_nInitPos - m_kRectTransform.rect.width - PaddingRight;
                    }
                }
            }

            if (m_DelayPlayCoroutine != null)
                StopCoroutine (m_DelayPlayCoroutine);
            m_DelayPlayCoroutine = StartCoroutine (DelayReplay (_bResetPos));
        }
        else {
            GetComponent<ContentSizeFitter>().enabled = false;
            m_kRectTransform.SetSizeWithCurrentAnchors (RectTransform.Axis.Horizontal, m_nInitWidth);   // Reset
            Stop ();
        }
    }

    // 跑馬燈回到起始設定好的位置
    private void ResetRollingPos ()
    {
        transform.localPosition = new Vector3 (m_nRollingBeginPos, transform.localPosition.y);
    }

    public void CheckAndPlay (bool _bResetPos = true)
    {
        StartCoroutine (UpdateContent (_bResetPos));
    }

    public void Replay ()
    {
        if (!m_bPlay)
            return;
        
        if (m_DelayPlayCoroutine != null)
            StopCoroutine (m_DelayPlayCoroutine);

        m_DelayPlayCoroutine = StartCoroutine (DelayReplay ());
    }

    public void Stop ()
    {
        if (m_DelayPlayCoroutine != null) {
            StopCoroutine (m_DelayPlayCoroutine);
            m_DelayPlayCoroutine = null;
        }
        
        // 若不使用文字跑馬燈，則將文字回到"自己"原本位置
        m_nRollingBeginPos = m_nInitPos;
        ResetRollingPos ();
        m_bPlay = false;
    }

    IEnumerator DelayReplay (bool _bResetPos = true)
    {
        if (_bResetPos)
            ResetRollingPos ();

        m_nMoveToT1 = true;
        if (DelayPlayTime > 0) {
            m_bPlay = false;
            yield return new WaitForSeconds (DelayPlayTime);
        }    
        
        m_bPlay = CheckIsShowing ();
    }

    private Vector3 TargetConvertToLocalX (Vector3 _worldPos)
    {
        return transform.localPosition + transform.InverseTransformPoint (_worldPos);
    }

    private bool CheckIsShowing ()
    {
        Transform checkTrans = transform;
        do {
            if (!checkTrans.gameObject.activeSelf)
                return false;
                
            if (checkTrans.gameObject.GetComponent<CanvasGroup>() && checkTrans.gameObject.GetComponent<CanvasGroup>().alpha == 0)
                return false;

            checkTrans = checkTrans.parent;
        } while (checkTrans);
        
        return true;
    }
}

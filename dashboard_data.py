# -*- coding: utf-8 -*-
"""
Naomi Launcher 朝のダッシュボード用のDB照会（読み取り専用・軽量）。
naomi_ai.db から「昨日更新の画像数」「神戸大学資料の件数/最新日」だけ取得。
取得できなければ IMG=-1 / KOBE=-1 を返す（naomi.ps1 側で「確認できませんでした」と表示）。
"""
import os
import sqlite3
import datetime

def main():
    db = os.path.join(os.environ.get("LOCALAPPDATA", ""), "NaomiAI", "naomi_ai.db")
    if not db or not os.path.exists(db):
        print("IMG=-1")
        print("KOBE=-1|")
        return
    try:
        con = sqlite3.connect("file:{}?mode=ro".format(db), uri=True)
        cur = con.cursor()
    except Exception:
        print("IMG=-1"); print("KOBE=-1|"); return

    yest = (datetime.date.today() - datetime.timedelta(days=1)).strftime("%Y-%m-%d")
    img_ext = (".jpg", ".jpeg", ".png", ".gif", ".heic", ".heif",
               ".webp", ".tif", ".tiff", ".bmp")

    n_img = -1
    try:
        qs = ",".join("?" * len(img_ext))
        n_img = cur.execute(
            "SELECT COUNT(*) FROM files WHERE status='active' "
            "AND lower(extension) IN ({}) AND substr(modified_time,1,10)=?"
            .format(qs), (*img_ext, yest)).fetchone()[0]
    except Exception:
        n_img = -1

    n_kobe, last = -1, ""
    try:
        row = cur.execute(
            "SELECT COUNT(*), MAX(substr(modified_time,1,10)) FROM files "
            "WHERE status='active' AND (file_name LIKE '%神戸大学%' "
            "OR full_path LIKE '%神戸大学%')").fetchone()
        n_kobe = row[0] if row else -1
        last = row[1] if row and row[1] else ""
    except Exception:
        n_kobe, last = -1, ""

    con.close()
    print("IMG={}".format(n_img))
    print("KOBE={}|{}".format(n_kobe, last))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print("IMG=-1"); print("KOBE=-1|")

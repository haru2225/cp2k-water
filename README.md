# cp2k-water: 粘土エッジのリボン + 水(+ Mg置換 + Na⁺)の原子電荷をCP2Kで計算する

`haru2225/cp2k_v2`(乾いたリボンの電荷、DZVP最適化)の続き。リボンのエッジの間に水を置いた系で、水によるリボン原子の電荷の変化(分極・電荷移動)を、
CP2K(PBE、GTH、DZVP-MOLOPT-SR-GTH、400 Ry)のHirshfeld電荷で調べる。SOAP → χ → QEq モデルの、水の電場への応答の教師データが目的。

## 系(12個、`structures_wet/`、`runs_wet/`)
土台は3つのリボン: `rib_y_o00_si`、`rib_y_o00_al`(y法線のエッジ、`si`/`al`はプロトンの配分)、`rib_x_o00_si`(x法線のエッジ)。
| 名前 | 内容 |
|---|---|
| `wet_<リボン>_w1`, `_w2` | 水のみ(中性、水12〜23分子)。水による分極の評価用。6 ps、12 psの古典MDスナップショット |
| `wet_<リボン>_wNa1`, `_wNa2` | 内部のAlを1つMgに置換(層電荷 −1、元のSi8Al3.5Mg0.5モデルと同じ密度)+ Na⁺ を1つ水中に |
- 原子順: リボン → Na⁺(wNaのみ)→ 水(O H H)。全方向周期セル + 真空。
- 水は、リボンを固定した古典MD(ClayFF電荷 + SPC、NVT 300 K、12 ps、zはリボンの層の厚さ±1.5 Åに閉じ込め)で配置した。古典力場は水の位置にだけ使い、電荷はCP2Kで出す。
- Mgサイトは再緩和しない(Hirshfeldは近似)。水の構造は古典MD由来で、DFTで緩和していない(1点計算のみ)。

## 使い方(スパコン)
**前提**: 乾いたリボン3つ(`rib_y_o00_si`、`rib_y_o00_al`、`rib_x_o00_si`)が `cp2k_v2` で DZVP で緩和済みであること。その結果を取り込む:
```bash
git clone https://github.com/haru2225/cp2k-water.git && cd cp2k-water
bash fetch_ribbons.sh ../cp2k_v2      # ribbons_relaxed/<リボン>/{relaxed.xyz,sp.out} にコピー
qsub run_cp2k.pbs                      # 12系を、ジョブ配列(-J 1-12)で並列に1点計算
```
- 各サブジョブは、`ribbons_relaxed/` のDZVP緩和リボンの座標を各系の先頭の原子に差し込み(元素ラベル、例えばMg、はそのまま)、DZVP/400 Ryで1点計算 → `runs_wet/<名前>/charges.dat`。
- `ribbons_relaxed/` が無いと、メッセージを出してスキップする。`qsub -v ALLOW_UNRELAXED=1 run_cp2k.pbs` なら、作ったままの(SZV緩和の)リボンで計算する(**非推奨: v1のSZV構造は結合が長い**)。
- 差し込みは近似: 水はSZV緩和のリボンの周りで配置したので、DZVPのリボンでは水との接触が±0.1 Å程度ずれる。より厳密には、`ribbons_relaxed/` を置いてから手元で `python3 build_wet.py && python3 make_cp2k.py`(要 numpy と LAMMPSのpythonモジュール)で水を置き直し、push してから計算する。
- 再投入すれば、完了済み(`charges.dat`あり)はスキップし、続きから進む。SCFが収束しない場合は、頑健な設定(対角化 + Broyden + smearing)で自動リトライ。
- `#PBS` の既定: `-q sc16`、`select=1:ncpus=16:mpiprocs=16`、`walltime=24:00:00`、`-J 1-12`(仮置き)。`-J` が使えなければ `RUNS` とNAMEで構造ごとに `qsub`(`qsub -v NAME=<系> run_cp2k.pbs` は配列と重なるので、`-J 1-1` を付けるなど)。
- 環境は自動(センターのサンプル `cp2k_20251.sh` の `module load` 等を再生、CP2K本体と `BASIS_MOLOPT` を探す)。計算ノードにpythonは不要。

## 解析
```bash
python3 analyze_wet.py     # numpyのみ。runs_wet/*/sp.out と ribbons_relaxed/*/sp.out(乾いた参照)を比べる
```
リボン原子ごとに dq = q_wet − q_dry、元素別の平均・rms・最大、リボン全体の総電荷の変化(水への電荷移動)、水のO・Hの平均電荷、Naの電荷を出す。
水のみ(`w`)が分極のきれいな試験。Mg/Na(`wNa`)では、置換の影響と水の影響が混ざる。

## 暫定の結果(ローカルで1系のみ、SZV緩和のリボン上なので参考値)
`wet_rib_y_o00_si_wNa1`(123原子)のHirshfeld電荷を、乾いた `rib_y_o00_si` と比べた:
- Mgサイト +0.361(乾いたAl +0.431)、Na⁺ +0.311(ClayFFスケール約×3.8で +1.2)。
- リボンの総電荷 +0.00 → **−0.56**(層電荷 −1 のうち約半分がリボン側に残る)。水の平均は O −0.253、H +0.139(1分子あたりの正味 +0.025: 水への電荷移動は小さい)。
- Mg位置を除くリボン原子の dq: Si 平均 −0.007(最大 0.020)、Al −0.005(0.019)、O −0.002(0.049)、H −0.015(0.068)。エッジの効果(0.01〜0.09)と同程度の大きさ。ただし置換と水の影響が混ざっている。
1系・水10分子・SZV緩和の土台なので、傾向の確認程度。

## 確認の範囲
- 構造は作成時に確認(水分子は壊れていない: O–H 1.000 Å、H–H 1.633 Å。水とリボンの最近接距離は約1.6〜1.8 Å)。
- 129原子の湿った系の1点計算を、ローカルのCP2K 2026.2で実行(Na・Mgの基底関数とポテンシャルを含む入力が通ることを確認。**OTのSCFは299反復でやっと収束**(元の上限300の直前)したので、上限を600に引き上げた。収束しない場合は頑健設定へ自動リトライ)。
- 差し込み(座標の置き換え)、配列番号ごとの系の選択、リボン未取得時の停止は、偽のCP2Kで確認。**センターの実機では未実行**。`#PBS -J` が受理されるかも未確認。
- Hirshfeld電荷はClayFFの約1/3.8のスケール(バルクでSi +0.55、Al +0.42、O −0.27)。

## スクリプト
`run_cp2k.pbs`(並列ジョブ)、`fetch_ribbons.sh`、`make_cp2k.py`(入力の再生成)、`hirshfeld_to_charges.py`、`analyze_wet.py`、`build_wet.py`(水の配置。ClayCode、MITの単位格子から作ったリボンが土台: `ClayCode.LICENSE.txt`)。

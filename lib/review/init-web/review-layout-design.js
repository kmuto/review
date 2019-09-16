/*
# Copyright (c) 2019 Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
*/

// パラメータオブジェクト
var p = new Object;

// 初期実行
function init() {
  document.getElementById("details").style.display = "none";
  p.cls = "review-jsbook";
  p.scale = 1;
  update_paper_info("a5");

  reset_all();
}

// パラメータ初期化
function init_val() {
  p.textwidth = p.o_textwidth;
  p.textheight = p.o_textheight;
  p.head_space = p.o_head_space;
  p.topmargin = p.o_topmargin;
  p.headheight = p.o_headheight;
  p.headsep = p.o_headsep;
  p.footskip = p.o_footskip;
  p.footheight = p.headheight; // もう存在しないものだけど高さは必要
  p.oddsidemargin = p.o_oddsidemargin;
  p.evensidemargin = p.o_evensidemargin;
  p.gutter = p.o_gutter;

  p.fontsize = p.o_fontsize;
  p.baselineskip = p.o_baselineskip;

  p.line_length = null;
  p.number_of_lines = null;

  p.edge = p.paperwidth - p.textwidth - p.gutter;
  p.bottom_space = p.paperheight - p.textheight - p.head_space;

  p.ebookyaml = true;

  update_fontsize();
  write_values();
}

// クラス変更
function change_cls() {
  var v = document.getElementById("cls").value;
  if (v == "review-jsbook" || v == "review-jlreq") {
    p.cls = v;
    change_paper();
    init_val();
    base_draw();
  }
  return true;
}

// 初期化
function reset_all() {
  init_val();
  base_draw();
  return true;
}

// 詳細表示切り替え
function show_details() {
  if (document.getElementById("details").style.display == "none") {
    document.getElementById("details").style.display = "block";
    document.getElementById("showdetails").value = "詳細設定を隠す";
    
  } else {
    document.getElementById("details").style.display = "none";
    document.getElementById("showdetails").value = "詳細設定を表示";
  }
  return true;
}

// 同人誌基本設定
function set_doujin() {
  if (document.getElementById("details").style.display == "none") {
    show_details();
  }
  document.getElementById("ebook").checked = true;
  document.getElementById("serial_pagination").checked = true;
  document.getElementById("hiddenfolio").checked = true;
  
  return true;
}

// 文字サイズ変更
function change_fontsize() {
  var v = Number(document.getElementById("fontsize").value);
  if (v == NaN || v < 0.1 || v >= 100) {
    write_values();
    return true;
  }
  if (v > p.baselineskip) {
    var baselineskip = dp2(v * ((p.cls == "review-jlreq") ? 1.7 : 1.6));
    p.baselineskip = baselineskip;
  }

  if (p.cls == "review-jsbook") {
    var v2 = round_fontsize_jsbook(v);
    if (v != v2) {
      // alert(v + " は、jsbook で許容するpt値 " + v2 + " に丸められます");
      v = v2;
    }
  }

  p.fontsize = v;
  update_fontsize();
  write_values();
  base_draw();
  return true;
}

// jsbookのQ数丸め
function round_fontsize_jsbook(v) {
  if (v < 8.5) {
    return 8;
  } else if (v < 9.5) {
    return 9;
  } else if (v < 10.5) {
    return 10;
  } else if (v < 11.5) {
    return 11;
  } else if (v < 12.5) {
    return 12;
  } else if (v < 15.5) {
    return 14;
  } else if (v < 18.5) {
    return 17;
  } else if (v < 20.5) {
    return 20;
  } else if (v < 23.5) {
    return 21;
  } else if (v < 27.5) {
    return 25;
  } else if (v < 33) {
    return 30;
  } else if (v < 39.5) {
    return 36;
  } else {
    return 43;
  }
}

// 行送りの変更
function change_baselineskip() {
  var v = Number(document.getElementById("baselineskip").value);
  if (v == NaN || v < p.fontsize || v >= 100) {
    write_values();
    return true;
  }
  p.baselineskip = v;
  update_fontsize();
  write_values();
  base_draw();
  return true;
}

// 文字数の変更
function change_line_length() {
  var v = Number(document.getElementById("line_length").value);
  if (v == NaN || v < 1 || v >= 400) {
    write_values();
    return true;
  }
  p.line_length = Math.floor(v);
  update_wl();
  // 小口を変える
  update_sidemargin();
  write_values();
  base_draw();
  return true;
}

// 行数の変更
function change_number_of_lines() {
  var v = Number(document.getElementById("number_of_lines").value);
  if (v == NaN || v < 1 || v >= 400) {
    write_values();
    return true;
  }

  p.number_of_lines = Math.floor(v);
  update_wl();
  // 地を変える
  write_values();
  base_draw();
  return true;
}

// ノドの変更
function change_gutter() {
  var v = Number(document.getElementById("gutter").value);
  if (v == NaN) {
    write_values();
    return true;
  }

  v = mmtopt(v);
  var edge = p.paperwidth - v - p.textwidth;
  if (v < 0 || v > mmtopt(p.paperwidth) || edge < 0) {
    write_values(); // はみだし
    return true;
  }

  p.gutter = v;
  p.edge = edge;
  update_sidemargin();
  write_values();
  base_draw();
  return true;
}

// 天変更
function change_head_space() {
  var v = Number(document.getElementById("head_space").value);
  if (v == NaN) {
    write_values();
    return true;
  }

  v = mmtopt(v);
  var bottom_space = p.paperheight - v - p.textheight;
  if (v < 0 || v > mmtopt(p.paperheight) || bottom_space < 0) {
    write_values();
    return true;
  }

  p.head_space = v;
  p.bottom_space = bottom_space;
  update_head();
  write_values();
  base_draw();
  return true;
}

// ヘッダ下/本文上アキ変更
function change_headsep() {
  var v = Number(document.getElementById("headsep").value);
  if (v == NaN) {
    write_values();
    return true;
  }

  v = mmtopt(v);
  if (v < -1 * mmtopt(p.paperheight) || v > p.head_space) {
    write_values();
    return true;
  }

  p.headsep = v;
  update_head();
  base_draw();
  return true;
}

// 本文下/フッタ下変更
function change_footskip() {
  var v = Number(document.getElementById("footskip").value);
  if (v == NaN) {
    write_values();
    return true;
  }

  v = mmtopt(v);
  if (v < 0 || v > p.edge) {
    write_values();
    return true;
  }

  p.footskip = v;
  base_draw();
  return true;
}

// 紙変更
function change_paper() {
  var paper = document.getElementById("papersize").value;
  update_paper_info(paper);
  p.textwidth = p.o_textwidth;
  p.textheight = p.o_textheight;
  p.topmargin = p.o_topmargin;
  p.head_space = p.o_head_space;
  p.gutter = p.o_gutter;

  update_fontsize();
  p.edge = p.paperwidth - p.textwidth - p.gutter;
  update_sidemargin();
  p.bottom_space = p.paperheight - p.head_space - p.textheight;
  write_values();
  change_tombopaper();
  base_draw();
}

// トンボ紙変更
function change_tombopaper() {
  var f = document.getElementById("tombopaper");
  var papersize = document.getElementById("papersize").value;
  if (f.value != "auto") {
    if (papersize == "b5" && f.value == "b5") {
      f.value = "auto";
    } else if (papersize == "a4" && (f.value == "b5" || f.value == "a4")) {
      f.value = "auto";
    }
  }
  return true;
}

// フォームへの値書き込み
function write_values() {
  document.getElementById("fontsize").value = p.fontsize;
  document.getElementById("baselineskip").value = p.baselineskip;
  document.getElementById("line_length").value = p.line_length;
  document.getElementById("number_of_lines").value = p.number_of_lines;
  document.getElementById("gutter").value = pttomm(p.gutter);
  document.getElementById("edge").value = pttomm(p.edge);
  document.getElementById("head_space").value = pttomm(p.head_space);
  document.getElementById("bottom_space").value = pttomm(p.bottom_space);
  document.getElementById("headsep").value = pttomm(p.headsep);
  document.getElementById("footskip").value = pttomm(p.footskip);
  update_qh();
  update_hanmen();
}

// 紙情報の初期情報
function update_paper_info(paper) {
  switch(p.cls + "-" + paper) {
    case "review-jsbook-a5":
      p.o_fontsize = 10;
      p.o_baselineskip = 16;
      p.papersize = "a5";
      p.paperwidth = mmtopt(148);
      p.paperheight = mmtopt(210);
      p.o_textwidth = 314.39209;
      p.o_textheight = 460.86066;
      p.o_headsep = 14.31091;
      p.o_headheight = 20.0;
      p.o_topmargin = -16.10184;
      p.o_oddsidemargin = -18.91565;
      p.o_evensidemargin = -18.91565;
      p.o_footskip = 0;
      break;

    case "review-jlreq-a5":
      p.o_fontsize = 10;
      p.o_baselineskip = 17;
      p.papersize = "a5";
      p.paperwidth = mmtopt(148);
      p.paperheight = mmtopt(210);
      p.o_textwidth = 310.0;
      p.o_textheight = 435.0;
      p.o_headsep = 18.79999;
      p.o_headheight = 10.0;
      p.o_topmargin = -21.01604;
      p.o_oddsidemargin = -16.7196;
      p.o_evensidemargin = -16.7196;
      p.o_footskip = 30;
      break;

    case "review-jsbook-b5":
      p.o_fontsize = 10;
      p.o_baselineskip = 16;
      p.papersize = "b5";
      p.paperwidth = mmtopt(182);
      p.paperheight = mmtopt(257);
      p.o_textwidth = 369.87305;
      p.o_textheight = 572.86066;
      p.o_headsep = 14.31091;
      p.o_headheight = 20.0;
      p.o_topmargin = -5.23787;
      p.o_oddsidemargin = -16.78009;
      p.o_evensidemargin = 20.20721;
      p.o_footskip = 0;
      break;

    case "review-jlreq-b5":
      p.o_fontsize = 10;
      p.o_baselineskip = 17;
      p.papersize = "b5";
      p.paperwidth = mmtopt(182);
      p.paperheight = mmtopt(257);
      p.o_textwidth = 380.0;
      p.o_textheight = 537.0;
      p.o_headsep = 18.79999;
      p.o_headheight = 10.0;
      p.o_topmargin = -5.15207;
      p.o_oddsidemargin = -3.34991;
      p.o_evensidemargin = -3.34991;
      p.o_footskip = 30;
      break;

    case "review-jsbook-a4":
      p.o_fontsize = 10;
      p.o_baselineskip = 16;
      p.papersize = "a4";
      p.paperwidth = mmtopt(210);
      p.paperheight = mmtopt(297);
      p.o_textwidth = 369.87305;
      p.o_textheight = 572.86066;
      p.o_headsep = 14.31091;
      p.o_headheight = 20.0;
      p.o_topmargin = -5.23787;
      p.o_oddsidemargin = -18.55695;
      p.o_evensidemargin = 101.6518;
      p.o_footskip = 0;
      break;

    case "review-jlreq-a4":
      p.o_fontsize = 10;
      p.o_baselineskip = 17;
      p.papersize = "a4";
      p.paperwidth = mmtopt(210);
      p.paperheight = mmtopt(297);
      p.o_textwidth = 440.0;
      p.o_textheight = 622.0;
      p.o_headsep = 18.79999;
      p.o_headheight = 10.0;
      p.o_topmargin = 9.25345;
      p.o_oddsidemargin = 6.48395;
      p.o_evensidemargin = 6.48395;
      p.o_footskip = 30;
      break;
  }

  p.o_head_space = inchpt() + p.o_topmargin + p.o_headheight + p.o_headsep;
  p.o_gutter = inchpt() + p.o_oddsidemargin;
}

// 文字サイズに伴う行・列更新
function update_fontsize() {
  p.jfontsize = p.fontsize;
  if (p.cls == "review-jsbook") p.jfontsize = p.fontsize * 0.9246895759999999; // http://akahana-1.hatenablog.jp/entry/2017/12/06/234615

  p.line_length = Math.floor(nearlyRound(p.textwidth / p.jfontsize)); // .99→繰り上げにする
  p.number_of_lines = Math.floor(nearlyRound((p.textheight + p.headsep) / p.baselineskip));
}

// 小口、地の追従更新
function update_wl() {
  p.textwidth = p.jfontsize * p.line_length;
  p.textheight = p.baselineskip * p.number_of_lines;
  p.edge = p.paperwidth - p.textwidth - p.gutter;
  p.bottom_space = p.paperheight - p.textheight - p.head_space;
  return true;
}

// 文字サイズのQ/H表示
function update_qh() {
  document.getElementById("fontsize_q").innerText = dp2(pttoq(p.fontsize)) + "Q, " + dp2(pttoq(p.baselineskip)) + "H";
}

// 版面表示
function update_hanmen() {
  document.getElementById("hanmen").innerText = dp2(pttomm(p.textwidth)) + "mm×" + dp2(pttomm(p.textheight)) + "mm";
}

// oddside,evensideを変える
function update_sidemargin() {
  p.oddsidemargin = p.gutter - inchpt();
  p.evensidemargin = p.paperwidth - 2 * inchpt() - p.oddsidemargin - p.textwidth;
}

// topmarginを変える
function update_head() {
  p.topmargin = p.head_space - inchpt() - p.headheight - p.headsep;
}

// 描画
function base_draw() {
  canvas = document.getElementById("mainCanvas");
  stage = new createjs.Stage(canvas);
  stage.scaleX = p.scale;
  stage.scaleY = p.scale;

  canvas.width = p.paperwidth * 2 + 10;
  canvas.height = p.paperheight + 10;

  p.paper_left = new createjs.Shape();
  p.paper_left.graphics.beginStroke("black").beginFill("#fffff0").drawRect(0, 0, p.paperwidth, p.paperheight);
  stage.addChild(p.paper_left);
  p.paper_right = new createjs.Shape();
  p.paper_right.graphics.beginStroke("black").beginFill("#fffff0").drawRect(p.paperwidth, 0, p.paperwidth, p.paperheight);
  stage.addChild(p.paper_right);

  p.paper_left_text = new createjs.Text("左ページ(偶数)", "sans serif", "black");
  p.paper_left_text.x = 10;
  p.paper_left_text.y = 10;
  p.paper_left_text.textAlign = "left";
  p.paper_left_text.textBaseline = "top";
  stage.addChild(p.paper_left_text);
  p.paper_right_text = new createjs.Text("右ページ(奇数)", "sans serif", "black");
  p.paper_right_text.x = p.paperwidth * 2 - 10;
  p.paper_right_text.y = 10;
  p.paper_right_text.textAlign = "right";
  p.paper_right_text.textBaseline = "top";
  stage.addChild(p.paper_right_text);

  // ヘッダ領域
  p.head_left = new createjs.Container();
  p.head_left.x = inchpt() + p.evensidemargin;
  p.head_left.y = inchpt() + p.topmargin;
  stage.addChild(p.head_left);

  p.head_left_box = new createjs.Shape();
  p.head_left_box.alpha = 0.8;
  p.head_left_box.graphics.beginStroke("black").beginFill("#c0c0c0").drawRect(0, 0, p.textwidth, p.headheight);
  p.head_left.addChild(p.head_left_box);
  p.head_left_text = new createjs.Text("ヘッダ領域", "sans serif", "black");
  p.head_left_text.x = p.textwidth / 2;
  p.head_left_text.y = p.headheight / 2;
  p.head_left_text.textAlign = "center";
  p.head_left_text.textBaseline = "middle";
  p.head_left.addChild(p.head_left_text);

  p.head_right = new createjs.Container();
  p.head_right.x = p.paperwidth + inchpt() + p.oddsidemargin;
  p.head_right.y = inchpt() + p.topmargin;
  stage.addChild(p.head_right);

  p.head_right_box = new createjs.Shape();
  p.head_right_box.alpha = 0.8;
  p.head_right_box.graphics.beginStroke("black").beginFill("#c0c0c0").drawRect(0, 0, p.textwidth, p.headheight);
  p.head_right.addChild(p.head_right_box);
  p.head_right_text = new createjs.Text("ヘッダ領域", "sans serif", "black");
  p.head_right_text.x = p.textwidth / 2;
  p.head_right_text.y = p.headheight / 2;
  p.head_right_text.textAlign = "center";
  p.head_right_text.textBaseline = "middle";
  p.head_right.addChild(p.head_right_text);

  // 本文
  var border_col = "black";
  var border_width = 1;
  if ((p.textwidth + p.gutter) > p.paperwidth || (p.textheight + p.head_space) > p.paperheight) {
    border_col = "red";
    border_width = 2;
  }

  p.body_left = new createjs.Container();
  p.body_left.x = inchpt() + p.evensidemargin;
  p.body_left.y = inchpt() + p.topmargin + p.headheight + p.headsep;
  stage.addChild(p.body_left);

  p.body_left_box = new createjs.Shape();
  p.body_left_box.alpha = 0.8;
  p.body_left_box.graphics.beginStroke(border_col).setStrokeStyle(border_width).beginFill("#e0ffe0").drawRect(0, 0, p.textwidth, p.textheight);
  p.body_left.addChild(p.body_left_box);
  makelines(p.body_left);

  p.body_right = new createjs.Container();
  p.body_right.x = p.paperwidth + inchpt() + p.oddsidemargin;
  p.body_right.y = inchpt() + p.topmargin + p.headheight + p.headsep;
  stage.addChild(p.body_right);

  p.body_right_box = new createjs.Shape();
  p.body_right_box.alpha = 0.8;
  p.body_right_box.graphics.beginStroke(border_col).setStrokeStyle(border_width).beginFill("#e0ffe0").drawRect(0, 0, p.textwidth, p.textheight);
  p.body_right.addChild(p.body_right_box);
  makelines(p.body_right);

  // フッタ
  p.foot_left = new createjs.Container();
  p.foot_left.x = inchpt() + p.evensidemargin;
  p.foot_left.y = inchpt() + p.topmargin + p.headheight + p.headsep + p.textheight + p.footskip - p.footheight;
  stage.addChild(p.foot_left);

  p.foot_left_box = new createjs.Shape();
  p.foot_left_box.alpha = 0.5;
  p.foot_left_box.graphics.beginStroke("black").beginFill("#c0c0c0").drawRect(0, 0, p.textwidth, p.footheight);
  p.foot_left.addChild(p.foot_left_box);
  p.foot_left_text = new createjs.Text("フッタ領域", "sans serif", "black");
  p.foot_left_text.x = p.textwidth / 2;
  p.foot_left_text.y = p.footheight / 2;
  p.foot_left_text.textAlign = "center";
  p.foot_left_text.textBaseline = "middle";
  p.foot_left.addChild(p.foot_left_text);

  p.foot_right = new createjs.Container();
  p.foot_right.x = p.paperwidth + inchpt() + p.oddsidemargin;
  p.foot_right.y = inchpt() + p.topmargin + p.headheight + p.headsep + p.textheight + p.footskip - p.footheight;
  stage.addChild(p.foot_right);

  p.foot_right_box = new createjs.Shape();
  p.foot_right_box.alpha = 0.5;
  p.foot_right_box.graphics.beginStroke("black").beginFill("#c0c0c0").drawRect(0, 0, p.textwidth, p.footheight);
  p.foot_right.addChild(p.foot_right_box);
  p.foot_right_text = new createjs.Text("フッタ領域", "sans serif", "black");
  p.foot_right_text.x = p.textwidth / 2;
  p.foot_right_text.y = p.footheight / 2;
  p.foot_right_text.textAlign = "center";
  p.foot_right_text.textBaseline = "middle";
  p.foot_right.addChild(p.foot_right_text);

  stage.update();
}

// 行文字配置
function makelines(container) {
  for (var y = 0; y < p.number_of_lines; y++) {
    for (var x = 0; x < p.line_length; x++) {
      var ch = new createjs.Shape();
      ch.alpha = 0.2;
      var fcolor = "#ffffff";
      if ((x + 1) % 10 == 0) fcolor = "#000000";
      ch.graphics.beginStroke("#0000ff").beginFill(fcolor).drawRect(x * p.jfontsize, y * p.baselineskip, p.jfontsize - 1, p.jfontsize - 1);
      container.addChild(ch);
    }
  }
  var s = new createjs.Text("本文領域：" + p.line_length + "文字×" + p.number_of_lines + "行", "sans serif", "black");
  s.x = p.textwidth / 2;
  s.y = p.textheight / 2;
  s.textAlign = "center";
  s.textBaseline = "middle";
  container.addChild(s);
}

// texdocumentclass出力
function update_result() {
  var ra = ["media=print"];
  ra.push("paper=" + document.getElementById("papersize").value);
  ra.push("fontsize=" + p.fontsize + "pt");
  ra.push("baselineskip=" + p.baselineskip + "pt");
  ra.push("line_length=" + p.line_length + "zw");
  ra.push("number_of_lines=" + p.number_of_lines);
  if (p.head_space != p.o_head_space) ra.push("head_space=" + dp2(pttomm(p.head_space)) + "mm");
  if (p.gutter != p.o_gutter) ra.push("gutter=" + dp2(pttomm(p.gutter)) + "mm");
  if (p.headsep != p.o_headsep) ra.push("headheight=" + dp2(pttomm(p.headheight)) + "mm");
  if (p.headsep != p.o_headsep) ra.push("headsep=" + dp2(pttomm(p.headsep)) + "mm");
  if (p.footskip != p.o_footskip) ra.push("footskip=" + dp2(pttomm(p.footskip)) + "mm");
  if (document.getElementById("openany").checked) ra.push("openany");
  if (document.getElementById("fleqno").checked) ra.push("fleqno");
  if (document.getElementById("startpage").value != "1") ra.push("startpage=" + document.getElementById("startpage").value);
  if (document.getElementById("serial_pagination").checked) ra.push("serial_pagination=true");
  if (document.getElementById("hiddenfolio").checked) ra.push("hiddenfolio=nikko-pc");
  if (document.getElementById("tombopaper").value != "auto") ra.push("tombopaper=" + document.getElementById("tombopaper").value);
  if (document.getElementById("bleed_margin").value != "3") ra.push("bleed_margin=" + document.getElementById("bleed_margin").value + "mm");
  var result = ra.join(",");
  document.getElementById("result_print").value = result;
  if (document.getElementById("ebook").checked) {
    document.getElementById("result_ebook").value = result.replace("media=print", "media=ebook");
  } else {
    document.getElementById("result_ebook").value = "";
  }
  document.reviewform.submit();
}

// インチ→pt
function inchpt() {
  return 72.2712035135135;
}

// mm→pt
function mmtopt(mm) {
  return mm * 2.8453229729729728;
}

// Q→pt
function qtopt(q) {
  return q * 0.25 * 2.8453229729729728;
}

// pt→mm
function pttomm(pt) {
  return pt * 0.3514598096921122;
}

// pt→Q
function pttoq(pt) {
  return pt * 0.3514598096921122 * 4;
}

// 99→1、.98→0にする
function nearlyRound(n) {
  var r = (((n + 0.01) * 10) >> 0) / 10;
  return (r > n) ? r : n;
}

// 小数点2桁化
function dp2(v) {
  return Math.round(v * 100) / 100;
}

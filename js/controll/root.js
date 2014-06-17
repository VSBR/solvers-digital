// コマンドパターンを踏襲して設計
var AppSolvers = function () {

    "use strict";

    console.log("root.js");

    // when using Zepto + simply deferred
//    Deferred.installInto(Zepto);

    var viewModel = {};

    // ui関連の画面共通のメソッドを収納するobject
    var ui = {};

    // シーン固有のメソッドを収納するobject
    var scene = {};

    //ゲームデータ
    var gameData = {};

    this.getViewModel = function () {
        return viewModel;
    };
    this.setViewModel = function (obj) {
        viewModel = obj;
    };

    this.getUi = function () {
        return ui;
    };

    this.getScene = function () {
        return scene;
    };

    this.getGameData = function() {
        return gameData;
    };

    this.setGameData = function(obj){
        gameData = obj;
    }

    this.gameDataInit = function() {
        gameData["gameData"].init();
    }

    // ui.xxx.init関数を全て実行
    this.runUiInitFunction = function () {
        _.each(ui, function (val, key) {
            try {
                val.init();
            } catch (exception) {
//                console.log("--- ↓↓↓ init関数を定義していますか? ↓↓↓ ---");
//                console.log("ui." + key);
//                console.log("--- ↑↑↑ init関数を定義していますか? ↑↑↑ ---");
                console.log(exception);
            }
        });
    };

    // ページ固有のinit関数を実行
    this.runSceneInitFunction = function (scene_name) {
        try {
            scene[scene_name].init();
        } catch (exception) {
//            console.log("--- ↓↓↓ init関数を定義していますか? ↓↓↓ ---");
//            console.log("website." + view);
//            console.log("--- ↑↑↑ init関数を定義していますか? ↑↑↑ ---");
            console.log(exception);
        }
    };
}

var appSolvers = new AppSolvers();
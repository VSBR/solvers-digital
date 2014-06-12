// コマンドパターンを踏襲して設計
var AppNeoPoodle = function (view) {

    "use strict";

    // when using Zepto + simply deferred
    Deferred.installInto(Zepto);

    var viewModel = {};
    // ui関連の画面共通のメソッドを収納するobject
    var ui = {};
    // ページ固有のメソッドを収納するobject
    var webSite = {};

    this.getViewModel = function () {
        return viewModel;
    }
    this.setViewModel = function (obj) {
        viewModel = obj;
    }

    this.getUi = function () {
        return ui;
    };

    this.getWebSite = function () {
        return webSite;
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
    this.runWebSiteInitFunction = function (view) {
        try {
            webSite[view].init();
        } catch (exception) {
//            console.log("--- ↓↓↓ init関数を定義していますか? ↓↓↓ ---");
//            console.log("website." + view);
//            console.log("--- ↑↑↑ init関数を定義していますか? ↑↑↑ ---");
            console.log(exception);
        }
    };

}

// VIEW はarticle_idで、base.htmlより取得
var appNeoPoodle = new AppNeoPoodle(VIEW);
$(function () {

        "use strict";

        appSolvers.runUiInitFunction();
        appSolvers.runWebSiteInitFunction(VIEW);
        ko.applyBindings(appSolvers.getViewModel());
    }
);
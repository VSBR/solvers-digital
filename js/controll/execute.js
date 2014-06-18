$(function () {
        "use strict";
        console.log("execute.js");
        appSolvers.runUiInitFunction();
        appSolvers.gameDataInit();
        appSolvers.runSceneInitFunction("main");
        ko.applyBindings(appSolvers.getViewModel());
    }
);
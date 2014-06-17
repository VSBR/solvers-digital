$(function () {

        "use strict";
        console.log("execute.js");
        appSolvers.runUiInitFunction();
        appSolvers.gameDataInit();
        appSolvers.runSceneInitFunction("title");
        ko.applyBindings(appSolvers.getViewModel());
    }
);
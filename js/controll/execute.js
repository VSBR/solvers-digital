$(function () {

        "use strict";
        console.log("execute.js");
        appSolvers.runUiInitFunction();
        appSolvers.runSceneInitFunction("main");
        ko.applyBindings(appSolvers.getViewModel());
    }
);
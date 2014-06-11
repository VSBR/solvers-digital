$(function () {

        "use strict";

        appSolvers.runUiInitFunction();
        appSolvers.runWebSiteInitFunction(VIEW);
        ko.applyBindings(appSolvers.getViewModel());
    }
);
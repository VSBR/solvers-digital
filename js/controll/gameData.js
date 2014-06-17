appSolvers.getGameData().gameData = {
    init: function () {
        console.log("gameData : init");

        "use strict";

        var GameDataModel = function () {
            this.data = ko.observable();
        };
        
        GameDataModel.prototype.DataInit = function () {
            console.log("DataInit");
        }

        var gameDataModel= new GameDataModel();
        appSolvers.getGameData().gameData = gameDataModel;
    }
};
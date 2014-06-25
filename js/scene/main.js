appSolvers.getScene().main = {
    init: function () {
        console.log("main : init");

        "use strict";

        var Model = function () {
            this.data = ko.observable();
        };
/*
        Model.prototype.solversTest = function () {
            console.log("solversTest");
        }
*/

        var MainViewModel = function (model) {
            var self = this;

            /* * * CONSTANT * * */
            /* game scene */
            //main
            var START = 0;
            //mission
            var MISSION_START = 0;
            var MISSION_MAIN = 1;
            var MISSION_RESULT = 2;
            //affairs
            var AFFAIRS_MAIN = 3;
            var AFFAIRS_BUILD = 4;
            var AFFAIRS_CREATE_HERO = 5;
            var AFFAIRS_UP_HERO = 6;
            var AFFAIRS_WEAPON = 7;
            //game result
            var GAME_CLEAR = 8;
            var GAME_RESULT = 9;
            /* * * * * * * * * * */

            //game controll
            self.scene = ko.observable();

            //ui elements
            self.uiDisplayBlock = $("");

            //game data init

            //ui init



            //scene method
            self.mainScene = _.bind(function (data) {
                console.log("[scene] start");


            });


            self.model = model;
            // Modelの変化を監視
            self.model.data.subscribe(function (data) {
            });


            //sceneの遷移
            self.scene
                .subscribe( function (data) {
                    var _scene = self.scene();
                    console.log("scene : " + _scene);
                    switch(_scene) {
                        case "START":
                            self.mainScene();
                        break;
                    }
                });
        };

        appSolvers.getViewModel().main = {};

        var model= new Model();
        var mainViewModel = new MainViewModel(model);
        appSolvers.getScene().main = mainViewModel;

        //init


        console.log("main start");
        appSolvers.getScene().main.scene("START");

    }
};
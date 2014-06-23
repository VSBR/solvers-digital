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
            var AFFAIRS_HERO_MAKE = 5;
            var AFFAIRS_HERO_UP = 6;
            var AFFAIRS_WEAPON = 7;
            //game result
            var GAME_CLEAR = 8;
            var GAME_RESULT = 9;
            /* * * * * * * * * * */
            //game controll
            self.scene = ko.observable();

            self.model = model;
            // Modelの変化を監視
            self.model.data.subscribe(function (data) {
            });

            //sceneの状態を監視
            self.scene
                .subscribe(_.bind(function () {
                    var _scene = this.scene();
                    switch(_scene) {
                        case START:
                            console.log("scene : " + _scene);
                        break;
                    }
                }));
        };

        appSolvers.getViewModel().main = {};

        var model= new Model();
        var mainViewModel = new MainViewModel(model);
        appSolvers.getScene().main = mainViewModel;

        console.log("main start");
//        this.scene(this.START);

    }
};
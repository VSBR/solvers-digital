appSolvers.getScene().main = {
    init: function () {
        console.log("main : init");

        "use strict";

        var Model = function (model_type) {
            this.data = ko.observable();
        };
        
        Model.prototype.solversTest = function () {
            console.log("solversTest");
        }

        var MainViewModel = function (model) {
            var self = this;

/*
            self.main = function () {
            }
*/

            self.model = model;
            // Modelの変化を監視
            self.model.data.subscribe(function (data) {
            });
        };

        appSolvers.getViewModel().main = {};

        var model= new Model();
        var mainViewModel = new MainViewModel(model);
        appSolvers.getViewModel().main = mainViewModel;

    }
};
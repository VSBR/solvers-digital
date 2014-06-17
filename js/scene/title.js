appSolvers.getScene().title = {
    init: function () {
        console.log("title : init");

        "use strict";

        var Model = function (model_type) {
            this.data = ko.observable();
        };
        
        Model.prototype.solversTest = function () {
            console.log("solversTest");
        }

        var TitleViewModel = function (model) {
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

        appSolvers.getViewModel().title = {};

        var model= new Model();
        var titleViewModel = new TitleViewModel(model);
        appSolvers.getViewModel().title = titleViewModel;

    }
};
appSolvers.getScene().title = {
    init: function () {
        console.log("title : init");

        "use strict";
/*
        var Model = function (model_type) {
            this.data = ko.observable();
        };
        
        Model.prototype.solversTest = function () {
            console.log("solversTest");
        }
*/
//        var TitleViewModel = function (model) {
        var TitleViewModel = function () {
            var self = this;

            self.is_saveData = ko.observable(false);

            self.initDisplay = function () {
                console.log("title : init display");
                appSolvers.getViewModel().uiDisplayChange("title");
            }


/*
            self.model = model;
            // Modelの変化を監視
            self.model.data.subscribe(function (data) {
            });
*/
        };

//        var model= new Model();
//        var titleViewModel = new TitleViewModel(model);
        var titleViewModel = new TitleViewModel();
        appSolvers.getViewModel().title = titleViewModel;

        appSolvers.getViewModel().title.initDisplay();

    }
};
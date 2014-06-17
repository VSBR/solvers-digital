appSolvers.getUi().display = {
    init: function () {

        "use strict";

        var viewModel = appSolvers.getViewModel();
        viewModel.uiDisplay = ko.observable(0);

        viewModel.uiDisplayChange = function (scene) {
            console.log("uiDisplayChange : " + scene);
            var load_html = scene + ".html";
            console.log(load_html);
            console.log($('#displayFrame'));
            $('#displayFrame').src = load_html;
//            $('#displayFrame').load(load_html);
        };

    }
}
System.register(["angular2/core", "angular2/http", "angular2/router", "./chars.service", "./details.component"], function(exports_1, context_1) {
    "use strict";
    var __moduleName = context_1 && context_1.id;
    var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
        var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
        if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
        else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
        return c > 3 && r && Object.defineProperty(target, key, r), r;
    };
    var __metadata = (this && this.__metadata) || function (k, v) {
        if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
    };
    var core_1, http_1, router_1, chars_service_1, details_component_1;
    var CharListComponent;
    return {
        setters:[
            function (core_1_1) {
                core_1 = core_1_1;
            },
            function (http_1_1) {
                http_1 = http_1_1;
            },
            function (router_1_1) {
                router_1 = router_1_1;
            },
            function (chars_service_1_1) {
                chars_service_1 = chars_service_1_1;
            },
            function (details_component_1_1) {
                details_component_1 = details_component_1_1;
            }],
        execute: function() {
            CharListComponent = (function () {
                function CharListComponent(_charsService, _router, _routeParams) {
                    this._charsService = _charsService;
                    this._router = _router;
                    this._routeParams = _routeParams;
                }
                CharListComponent.prototype.ngOnInit = function () {
                    var _this = this;
                    this._charsService.getList(this._routeParams.get("account"))
                        .subscribe(function (list) {
                        _this.activeChars = list[0];
                        _this.deletedChars = list[1];
                    }, function (error) { return _this.errorMsg = error; });
                };
                CharListComponent.prototype.gotoHeroDetails = function (character) {
                    console.log("character: ", character);
                    this._router.navigate(["CharDetails", { account: this._routeParams.get("account"), char: character.bicFileName }]);
                };
                CharListComponent = __decorate([
                    core_1.Component({
                        selector: "charlist",
                        templateUrl: "app/chars/list.component.html",
                        directives: [details_component_1.CharDetailsComponent],
                        providers: [http_1.HTTP_PROVIDERS, chars_service_1.CharsService]
                    }), 
                    __metadata('design:paramtypes', [chars_service_1.CharsService, router_1.Router, router_1.RouteParams])
                ], CharListComponent);
                return CharListComponent;
            }());
            exports_1("CharListComponent", CharListComponent);
        }
    }
});
//# sourceMappingURL=list.component.js.map
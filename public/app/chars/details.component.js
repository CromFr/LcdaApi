System.register(["angular2/core", "angular2/http", "angular2/router", "./chars.service"], function(exports_1, context_1) {
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
    var core_1, http_1, router_1, chars_service_1;
    var CharDetailsComponent;
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
            }],
        execute: function() {
            CharDetailsComponent = (function () {
                function CharDetailsComponent(_charsService, _routeParams) {
                    this._charsService = _charsService;
                    this._routeParams = _routeParams;
                }
                CharDetailsComponent.prototype.ngOnInit = function () {
                    var _this = this;
                    this._charsService.getChar(this._routeParams.get("account"), this._routeParams.get("char"))
                        .subscribe(function (c) { _this.character = c; console.log(c); }, function (error) { return _this.errorMsg = error; });
                };
                CharDetailsComponent = __decorate([
                    core_1.Component({
                        selector: "chardetails",
                        templateUrl: "app/chars/details.component.html",
                        directives: [],
                        providers: [http_1.HTTP_PROVIDERS, chars_service_1.CharsService]
                    }), 
                    __metadata('design:paramtypes', [chars_service_1.CharsService, router_1.RouteParams])
                ], CharDetailsComponent);
                return CharDetailsComponent;
            }());
            exports_1("CharDetailsComponent", CharDetailsComponent);
        }
    }
});
//# sourceMappingURL=details.component.js.map